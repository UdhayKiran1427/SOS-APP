import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'api_service.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final ApiService _api = ApiService.instance;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncService._internal();

  /// Synchronizes local data with backend MySQL:
  /// 1. Uploads local pending/unsynced contacts.
  /// 2. Uploads local pending SOS alerts.
  /// 3. Fetches remote contacts and merges them locally.
  Future<bool> syncAll() async {
    if (_isSyncing) return false;
    final token = await _api.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[SyncService] No auth token found. Skipping cloud sync.');
      return false;
    }

    _isSyncing = true;
    try {
      debugPrint('[SyncService] Starting bidirectional sync...');

      // 1. Upload unsynced contacts
      final unsyncedContacts = await _db.getUnsyncedContacts();
      for (final contact in unsyncedContacts) {
        try {
          if (contact.remoteId == null) {
            final remoteId = await _api.createRemoteContact(contact);
            if (remoteId != null && contact.id != null) {
              await _db.markContactSynced(contact.id!, remoteId);
            }
          } else {
            final ok = await _api.updateRemoteContact(contact);
            if (ok && contact.id != null) {
              await _db.markContactSynced(contact.id!, contact.remoteId!);
            }
          }
        } catch (e) {
          debugPrint('[SyncService] Failed to sync contact "${contact.name}": $e');
        }
      }

      // 2. Upload unsynced queued alerts
      final unsyncedAlerts = await _db.getUnsyncedAlerts();
      for (final alert in unsyncedAlerts) {
        try {
          final remoteAlertId = await _api.uploadAlert(alert);
          if (remoteAlertId != null && alert.id != null) {
            await _db.markAlertSynced(alert.id!, remoteAlertId);
          }
        } catch (e) {
          debugPrint('[SyncService] Failed to sync alert id ${alert.id}: $e');
        }
      }

      // 3. Fetch remote contacts and merge locally
      try {
        final remoteContacts = await _api.fetchRemoteContacts();
        final localContacts = await _db.getContacts();
        final localPhones = {for (final c in localContacts) c.phoneE164: c};

        for (final remote in remoteContacts) {
          if (localPhones.containsKey(remote.phoneE164)) {
            final local = localPhones[remote.phoneE164]!;
            if (local.remoteId == null) {
              await _db.markContactSynced(local.id!, remote.remoteId!);
            }
          } else {
            // New contact from server
            await _db.insertContact(remote);
          }
        }
      } catch (e) {
        debugPrint('[SyncService] Failed to pull remote contacts: $e');
      }

      debugPrint('[SyncService] Sync finished successfully.');
      return true;
    } catch (e) {
      debugPrint('[SyncService] Sync encountered error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }
}

