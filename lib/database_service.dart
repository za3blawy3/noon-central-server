import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as path;

class DatabaseService {
  Database? _db;

  Future<void> init() async {
    final dbPath = path.join(Directory.current.path, 'server_data.db');
    _db = sqlite3.open(dbPath);

    print('📂 قاعدة البيانات: $dbPath');

    _createTables();
  }

  void _createTables() {
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS devices (
        deviceId TEXT PRIMARY KEY,
        deviceName TEXT NOT NULL,
        deviceModel TEXT NOT NULL,
        manufacturer TEXT NOT NULL,
        osVersion TEXT NOT NULL,
        appVersion TEXT NOT NULL,
        platform TEXT NOT NULL,
        firstSeen TEXT NOT NULL,
        lastSeen TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        customMessage TEXT,
        totalSessions INTEGER NOT NULL DEFAULT 1
      )
    ''');

    _db!.execute('''
      CREATE TABLE IF NOT EXISTS app_control (
        id INTEGER PRIMARY KEY,
        isAppEnabled INTEGER NOT NULL DEFAULT 1,
        globalMessage TEXT,
        lastUpdate TEXT NOT NULL
      )
    ''');

    // إضافة الإعدادات الافتراضية
    final existing = _db!.select('SELECT * FROM app_control WHERE id = 1');
    if (existing.isEmpty) {
      _db!.execute('''
        INSERT INTO app_control (id, isAppEnabled, globalMessage, lastUpdate)
        VALUES (1, 1, NULL, '${DateTime.now().toIso8601String()}')
      ''');
    }

    print('✅ قاعدة البيانات جاهزة');
  }

  Future<Map<String, dynamic>> registerOrUpdateDevice({
    required String deviceId,
    required String deviceName,
    required String deviceModel,
    required String manufacturer,
    required String osVersion,
    required String appVersion,
    required String platform,
  }) async {
    final now = DateTime.now().toIso8601String();

    final existing = _db!.select(
      'SELECT * FROM devices WHERE deviceId = ?',
      [deviceId],
    );

    if (existing.isEmpty) {
      // جهاز جديد
      _db!.execute('''
        INSERT INTO devices (
          deviceId, deviceName, deviceModel, manufacturer,
          osVersion, appVersion, platform, firstSeen,
          lastSeen, isActive, totalSessions
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1)
      ''', [
        deviceId,
        deviceName,
        deviceModel,
        manufacturer,
        osVersion,
        appVersion,
        platform,
        now,
        now
      ]);
    } else {
      // تحديث جهاز موجود
      final oldSessions = existing.first['totalSessions'] as int;
      _db!.execute('''
        UPDATE devices
        SET lastSeen = ?, totalSessions = ?, appVersion = ?
        WHERE deviceId = ?
      ''', [now, oldSessions + 1, appVersion, deviceId]);
    }

    final device = _db!.select(
      'SELECT * FROM devices WHERE deviceId = ?',
      [deviceId],
    ).first;

    return _rowToMap(device);
  }

  Future<Map<String, dynamic>> checkDeviceStatus(String deviceId) async {
    // التحقق من الإعدادات العامة
    final control = _db!.select('SELECT * FROM app_control WHERE id = 1').first;
    final isAppEnabled = control['isAppEnabled'] == 1;
    final globalMessage = control['globalMessage'] as String?;

    if (!isAppEnabled) {
      return {
        'allowed': false,
        'message': globalMessage ?? 'التطبيق معطل حالياً',
      };
    }

    // التحقق من حالة الجهاز
    final device = _db!.select(
      'SELECT * FROM devices WHERE deviceId = ?',
      [deviceId],
    );

    if (device.isEmpty) {
      return {'allowed': true, 'message': 'مرحباً بك!'};
    }

    final deviceData = device.first;
    final isActive = deviceData['isActive'] == 1;
    final customMessage = deviceData['customMessage'] as String?;

    if (!isActive) {
      return {
        'allowed': false,
        'message': customMessage ?? 'جهازك معطل من لوحة التحكم',
      };
    }

    if (customMessage != null && customMessage.isNotEmpty) {
      return {
        'allowed': true,
        'message': customMessage,
        'hasCustomMessage': true,
      };
    }

    return {'allowed': true, 'message': null};
  }

  Future<void> updateDeviceHeartbeat(String deviceId) async {
    _db!.execute('''
      UPDATE devices
      SET lastSeen = ?
      WHERE deviceId = ?
    ''', [DateTime.now().toIso8601String(), deviceId]);
  }

  Future<List<Map<String, dynamic>>> getAllDevices() async {
    final devices = _db!.select('SELECT * FROM devices ORDER BY lastSeen DESC');
    return devices.map(_rowToMap).toList();
  }

  Future<Map<String, dynamic>> getStatistics() async {
    final totalDevices = _db!
        .select('SELECT COUNT(*) as count FROM devices')
        .first['count'] as int;
    final activeDevices = _db!
        .select('SELECT COUNT(*) as count FROM devices WHERE isActive = 1')
        .first['count'] as int;
    final disabledDevices = totalDevices - activeDevices;
    final totalSessions = _db!
            .select('SELECT SUM(totalSessions) as sum FROM devices')
            .first['sum'] as int? ??
        0;

    return {
      'totalDevices': totalDevices,
      'activeDevices': activeDevices,
      'disabledDevices': disabledDevices,
      'totalSessions': totalSessions,
    };
  }

  Future<void> disableDevice(String deviceId, String? message) async {
    _db!.execute('''
      UPDATE devices
      SET isActive = 0, customMessage = ?
      WHERE deviceId = ?
    ''', [message, deviceId]);
  }

  Future<void> enableDevice(String deviceId) async {
    _db!.execute('''
      UPDATE devices
      SET isActive = 1, customMessage = NULL
      WHERE deviceId = ?
    ''', [deviceId]);
  }

  Future<void> updateDeviceMessage(String deviceId, String? message) async {
    _db!.execute('''
      UPDATE devices
      SET customMessage = ?
      WHERE deviceId = ?
    ''', [message, deviceId]);
  }

  Future<void> deleteDevice(String deviceId) async {
    _db!.execute('DELETE FROM devices WHERE deviceId = ?', [deviceId]);
  }

  Future<void> disableApp(String? message) async {
    _db!.execute('''
      UPDATE app_control
      SET isAppEnabled = 0, globalMessage = ?, lastUpdate = ?
      WHERE id = 1
    ''', [message, DateTime.now().toIso8601String()]);
  }

  Future<void> enableApp() async {
    _db!.execute('''
      UPDATE app_control
      SET isAppEnabled = 1, globalMessage = NULL, lastUpdate = ?
      WHERE id = 1
    ''', [DateTime.now().toIso8601String()]);
  }

  Map<String, dynamic> _rowToMap(Row row) {
    return {
      'deviceId': row['deviceId'],
      'deviceName': row['deviceName'],
      'deviceModel': row['deviceModel'],
      'manufacturer': row['manufacturer'],
      'osVersion': row['osVersion'],
      'appVersion': row['appVersion'],
      'platform': row['platform'],
      'firstSeen': row['firstSeen'],
      'lastSeen': row['lastSeen'],
      'isActive': row['isActive'] == 1,
      'customMessage': row['customMessage'],
      'totalSessions': row['totalSessions'],
    };
  }

  Future<void> close() async {
    _db?.dispose();
  }
}
