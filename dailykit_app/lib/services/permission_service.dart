import 'package:permission_handler/permission_handler.dart';
import 'database_helper.dart';

class PermissionStatusReport {
  final bool hasSms;
  final bool hasLocation;
  final bool hasContacts;
  final bool hasNotification;

  PermissionStatusReport({
    required this.hasSms,
    required this.hasLocation,
    required this.hasContacts,
    required this.hasNotification,
  });

  bool get isReadyForSos => hasSms && hasLocation;
  bool get allGranted => hasSms && hasLocation && hasContacts && hasNotification;
}

class PermissionService {
  static final PermissionService instance = PermissionService._internal();
  final DatabaseHelper _db = DatabaseHelper.instance;

  PermissionService._internal();

  Future<bool> hasConsented() async {
    final val = await _db.getSetting('has_consented_permissions');
    return val == 'true';
  }

  Future<void> saveConsent(bool consented) async {
    await _db.setSetting('has_consented_permissions', consented ? 'true' : 'false');
  }

  Future<PermissionStatusReport> checkAllPermissions() async {
    final sms = await Permission.sms.isGranted;
    final location = await Permission.location.isGranted;
    final contacts = await Permission.contacts.isGranted;
    final notification = await Permission.notification.isGranted;

    return PermissionStatusReport(
      hasSms: sms,
      hasLocation: location,
      hasContacts: contacts,
      hasNotification: notification,
    );
  }

  Future<PermissionStatusReport> requestRequiredPermissions() async {
    final statuses = await [
      Permission.sms,
      Permission.location,
      Permission.contacts,
      Permission.notification,
    ].request();

    return PermissionStatusReport(
      hasSms: statuses[Permission.sms]?.isGranted ?? false,
      hasLocation: statuses[Permission.location]?.isGranted ?? false,
      hasContacts: statuses[Permission.contacts]?.isGranted ?? false,
      hasNotification: statuses[Permission.notification]?.isGranted ?? false,
    );
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
  }
}

