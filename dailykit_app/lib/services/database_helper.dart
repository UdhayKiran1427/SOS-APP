import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/contact_model.dart';
import '../models/alert_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dailykit_sos.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    // 1. Contacts table
    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        name TEXT NOT NULL,
        phone_e164 TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1,
        priority INTEGER NOT NULL DEFAULT 1,
        is_synced INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // 2. Alerts table
    await db.execute('''
      CREATE TABLE alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id INTEGER,
        latitude REAL,
        longitude REAL,
        accuracy REAL,
        location_source TEXT NOT NULL,
        message TEXT NOT NULL,
        triggered_at TEXT NOT NULL,
        sent_count INTEGER NOT NULL DEFAULT 0,
        failed_count INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. Alert Recipients table
    await db.execute('''
      CREATE TABLE alert_recipients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_alert_id INTEGER NOT NULL,
        contact_id INTEGER,
        phone TEXT NOT NULL,
        status TEXT NOT NULL,
        error TEXT,
        FOREIGN KEY (local_alert_id) REFERENCES alerts (id) ON DELETE CASCADE
      )
    ''');

    // 4. Key-Value Settings table
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Seed default settings
    await db.insert('app_settings', {'key': 'countdown_enabled', 'value': 'true'});
    await db.insert('app_settings', {'key': 'default_country_code', 'value': '+91'});
    await db.insert('app_settings', {'key': 'message_template', 'value': 'I need help. My location: {location} (sent {datetime})'});
    await db.insert('app_settings', {'key': 'has_consented_permissions', 'value': 'false'});
  }

  // ================= CONTACTS CRUD =================

  Future<List<ContactModel>> getContacts({bool onlyActive = false}) async {
    final db = await database;
    final String whereClause = onlyActive ? 'WHERE is_active = 1' : '';
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM contacts $whereClause ORDER BY priority ASC, id ASC
    ''');
    return maps.map((m) => ContactModel.fromMap(m)).toList();
  }

  Future<int> insertContact(ContactModel contact) async {
    final db = await database;
    return await db.insert(
      'contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateContact(ContactModel contact) async {
    final db = await database;
    return await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<int> deleteContact(int id) async {
    final db = await database;
    return await db.delete(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ContactModel>> getUnsyncedContacts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'contacts',
      where: 'is_synced = 0',
    );
    return maps.map((m) => ContactModel.fromMap(m)).toList();
  }

  Future<void> markContactSynced(int localId, int remoteId) async {
    final db = await database;
    await db.update(
      'contacts',
      {
        'remote_id': remoteId,
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ================= ALERTS CRUD =================

  Future<int> insertAlert(AlertModel alert) async {
    final db = await database;
    return await db.transaction((txn) async {
      final alertId = await txn.insert('alerts', alert.toMap());
      for (final rec in alert.recipients) {
        await txn.insert('alert_recipients', rec.toMap(alertId));
      }
      return alertId;
    });
  }

  Future<List<AlertModel>> getAlerts({int limit = 50}) async {
    final db = await database;
    final List<Map<String, dynamic>> alertMaps = await db.query(
      'alerts',
      orderBy: 'triggered_at DESC',
      limit: limit,
    );

    final List<AlertModel> result = [];
    for (final aMap in alertMaps) {
      final int alertId = aMap['id'] as int;
      final List<Map<String, dynamic>> recMaps = await db.query(
        'alert_recipients',
        where: 'local_alert_id = ?',
        whereArgs: [alertId],
      );
      final recipients = recMaps.map((r) => AlertRecipientModel.fromMap(r)).toList();
      result.add(AlertModel.fromMap(aMap, recipients: recipients));
    }
    return result;
  }

  Future<List<AlertModel>> getUnsyncedAlerts() async {
    final db = await database;
    final List<Map<String, dynamic>> alertMaps = await db.query(
      'alerts',
      where: 'is_synced = 0',
    );

    final List<AlertModel> result = [];
    for (final aMap in alertMaps) {
      final int alertId = aMap['id'] as int;
      final List<Map<String, dynamic>> recMaps = await db.query(
        'alert_recipients',
        where: 'local_alert_id = ?',
        whereArgs: [alertId],
      );
      final recipients = recMaps.map((r) => AlertRecipientModel.fromMap(r)).toList();
      result.add(AlertModel.fromMap(aMap, recipients: recipients));
    }
    return result;
  }

  Future<void> markAlertSynced(int localId, int remoteId) async {
    final db = await database;
    await db.update(
      'alerts',
      {
        'remote_id': remoteId,
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ================= SETTINGS CRUD =================

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ================= LOCAL STORAGE USER PROFILE =================

  Future<void> saveLocalUserProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    await setSetting('local_user_name', name);
    await setSetting('local_user_email', email);
    if (phone != null && phone.isNotEmpty) {
      await setSetting('local_user_phone', phone);
    }
    await setSetting('storage_mode', 'local');
  }

  Future<Map<String, String>?> getLocalUserProfile() async {
    final name = await getSetting('local_user_name');
    final email = await getSetting('local_user_email');
    final phone = await getSetting('local_user_phone');

    if (name != null && name.isNotEmpty) {
      return {
        'name': name,
        'email': email ?? '',
        'phone': phone ?? '',
      };
    }
    return null;
  }

  Future<void> clearLocalUserProfile() async {
    final db = await database;
    await db.delete('app_settings', where: 'key IN (?, ?, ?, ?)', whereArgs: [
      'local_user_name',
      'local_user_email',
      'local_user_phone',
      'storage_mode',
    ]);
  }
}

