import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:crypto/crypto.dart';
import 'database_service.dart';

class CentralServer {
  final DatabaseService _db = DatabaseService();
  HttpServer? _server;
  final int port;
  final String adminPassword;

  CentralServer({
    this.port = 3000,
    this.adminPassword = 'Hh42214221',
  });

  Future<void> start() async {
    await _db.init();

    final router = Router();

    // ========== Public Endpoints (للتطبيق) ==========

    // تسجيل/تحديث جهاز
    router.post('/api/device/register', _handleDeviceRegister);

    // التحقق من صلاحية الجهاز
    router.post('/api/device/check', _handleDeviceCheck);

    // تحديث آخر نشاط للجهاز
    router.post('/api/device/heartbeat', _handleDeviceHeartbeat);

    // ========== Admin Endpoints (للوحة التحكم) ==========

    // تسجيل دخول المدير
    router.post('/admin/login', _handleAdminLogin);

    // الحصول على جميع الأجهزة
    router.get('/admin/devices', _handleGetDevices);

    // الحصول على الإحصائيات
    router.get('/admin/stats', _handleGetStats);

    // تعطيل جهاز
    router.post('/admin/devices/<deviceId>/disable', _handleDisableDevice);

    // تفعيل جهاز
    router.post('/admin/devices/<deviceId>/enable', _handleEnableDevice);

    // تحديث رسالة جهاز
    router.post(
        '/admin/devices/<deviceId>/message', _handleUpdateDeviceMessage);

    // حذف جهاز
    router.delete('/admin/devices/<deviceId>', _handleDeleteDevice);

    // تعطيل التطبيق للجميع
    router.post('/admin/app/disable', _handleDisableApp);

    // تفعيل التطبيق للجميع
    router.post('/admin/app/enable', _handleEnableApp);

    // ========== Web Dashboard ==========
    router.get('/', _serveDashboard);
    router.get('/admin', _serveDashboard);

    // إعداد Middleware
    final handler = Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

    final localIP = await _getLocalIP();
    print('');
    print('╔════════════════════════════════════════════════════════════╗');
    print('║  🎛️  سيرفر المراقبة المركزي يعمل الآن!                  ║');
    print('╠════════════════════════════════════════════════════════════╣');
    print('║  📍 من الكمبيوتر:   http://localhost:$port              ║');
    print('║  📱 من الجوال:      http://$localIP:$port        ║');
    print('║  🔐 كلمة المرور:    $adminPassword                        ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('');
    print('✅ جاهز لاستقبال الأجهزة...');
    print('');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    await _db.close();
    print('⏹️  تم إيقاف السيرفر');
  }

  // ========== Device Endpoints Handlers ==========

  Future<Response> _handleDeviceRegister(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final device = await _db.registerOrUpdateDevice(
        deviceId: data['deviceId'] as String,
        deviceName: data['deviceName'] as String,
        deviceModel: data['deviceModel'] as String,
        manufacturer: data['manufacturer'] as String,
        osVersion: data['osVersion'] as String,
        appVersion: data['appVersion'] as String,
        platform: data['platform'] as String,
      );

      print('📱 جهاز جديد: ${device['deviceName']} (${device['deviceModel']})');

      return Response.ok(
        jsonEncode({'success': true, 'device': device}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('❌ خطأ في تسجيل الجهاز: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleDeviceCheck(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final deviceId = data['deviceId'] as String;

      final status = await _db.checkDeviceStatus(deviceId);

      return Response.ok(
        jsonEncode(status),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleDeviceHeartbeat(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final deviceId = data['deviceId'] as String;

      await _db.updateDeviceHeartbeat(deviceId);

      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  // ========== Admin Endpoints Handlers ==========

  Future<Response> _handleAdminLogin(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final password = data['password'] as String?;

      if (password == null || password.isEmpty) {
        return Response.forbidden(
          jsonEncode({'error': 'كلمة المرور مطلوبة'}),
        );
      }

      if (password == adminPassword) {
        // توليد token بسيط (في الإنتاج استخدم JWT)
        final token = _generateToken(password);
        return Response.ok(
          jsonEncode({'success': true, 'token': token}),
        );
      } else {
        print('⚠️  محاولة دخول فاشلة');
        return Response.forbidden(
          jsonEncode({'error': 'كلمة مرور خاطئة'}),
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleGetDevices(Request request) async {
    try {
      final devices = await _db.getAllDevices();
      return Response.ok(
        jsonEncode(devices),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleGetStats(Request request) async {
    try {
      final stats = await _db.getStatistics();
      return Response.ok(
        jsonEncode(stats),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleDisableDevice(
      Request request, String deviceId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final message = data['message'] as String?;

      await _db.disableDevice(deviceId, message);
      print('🚫 تم تعطيل الجهاز: $deviceId');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'تم تعطيل الجهاز'}),
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleEnableDevice(Request request, String deviceId) async {
    try {
      await _db.enableDevice(deviceId);
      print('✅ تم تفعيل الجهاز: $deviceId');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'تم تفعيل الجهاز'}),
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleUpdateDeviceMessage(
      Request request, String deviceId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final message = data['message'] as String?;

      await _db.updateDeviceMessage(deviceId, message);

      return Response.ok(
        jsonEncode({'success': true, 'message': 'تم تحديث الرسالة'}),
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleDeleteDevice(Request request, String deviceId) async {
    try {
      await _db.deleteDevice(deviceId);
      print('🗑️  تم حذف الجهاز: $deviceId');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'تم حذف الجهاز'}),
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleDisableApp(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final message = data['message'] as String?;

      await _db.disableApp(message);
      print('🚫 تم تعطيل التطبيق للجميع');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'تم تعطيل التطبيق للجميع'}),
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Future<Response> _handleEnableApp(Request request) async {
    try {
      await _db.enableApp();
      print('✅ تم تفعيل التطبيق للجميع');

      return Response.ok(
        jsonEncode({'success': true, 'message': 'تم تفعيل التطبيق للجميع'}),
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  Response _serveDashboard(Request request) {
    return Response.ok(
      _getDashboardHTML(),
      headers: {'Content-Type': 'text/html; charset=utf-8'},
    );
  }

  String _getDashboardHTML() {
    return '''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🎛️ لوحة التحكم المركزية</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        
        /* Login */
        .login-box {
            background: white;
            padding: 40px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            max-width: 400px;
            margin: 100px auto;
        }
        .login-box h1 { text-align: center; color: #667eea; margin-bottom: 30px; }
        input {
            width: 100%;
            padding: 12px;
            margin-bottom: 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
        }
        input:focus { border-color: #667eea; outline: none; }
        button {
            width: 100%;
            padding: 12px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            cursor: pointer;
        }
        button:hover { background: #5568d3; }
        
        /* Dashboard */
        .dashboard { display: none; }
        .header {
            background: white;
            padding: 20px;
            border-radius: 15px;
            margin-bottom: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .header h1 { color: #667eea; }
        .logout-btn {
            width: auto;
            padding: 10px 20px;
            background: #f44336;
        }
        
        /* Stats */
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
        }
        .stat-card h3 { color: #666; font-size: 14px; margin-bottom: 10px; }
        .stat-card .number { font-size: 32px; font-weight: bold; color: #667eea; }
        
        /* Devices */
        .devices-section {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .devices-section h2 { color: #667eea; margin-bottom: 20px; }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 12px;
            text-align: right;
            border-bottom: 1px solid #e0e0e0;
        }
        th {
            background: #f5f5f5;
            color: #667eea;
            font-weight: bold;
        }
        tr:hover { background: #f9f9f9; }
        .status-active { color: #4caf50; font-weight: bold; }
        .status-disabled { color: #f44336; font-weight: bold; }
        
        .action-btn {
            padding: 6px 12px;
            margin: 2px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 12px;
        }
        .btn-disable { background: #f44336; color: white; }
        .btn-enable { background: #4caf50; color: white; }
        .btn-message { background: #ff9800; color: white; }
        .btn-delete { background: #9c27b0; color: white; }
        
        .alert {
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .alert-success { background: #d4edda; color: #155724; }
        .alert-error { background: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <!-- Login -->
    <div class="login-box" id="loginScreen">
        <h1>🔐 لوحة التحكم</h1>
        <div id="loginError" class="alert alert-error" style="display:none;"></div>
        <input type="password" id="loginPassword" placeholder="كلمة المرور" />
        <button onclick="login()">دخول</button>
    </div>

    <!-- Dashboard -->
    <div class="dashboard" id="dashboard">
        <div class="container">
            <div class="header">
                <h1>🎛️ لوحة التحكم المركزية</h1>
                <button class="logout-btn" onclick="logout()">تسجيل الخروج</button>
            </div>

            <div id="alertBox"></div>

            <!-- Stats -->
            <div class="stats">
                <div class="stat-card">
                    <h3>📱 إجمالي الأجهزة</h3>
                    <div class="number" id="totalDevices">0</div>
                </div>
                <div class="stat-card">
                    <h3>✅ الأجهزة النشطة</h3>
                    <div class="number" id="activeDevices">0</div>
                </div>
                <div class="stat-card">
                    <h3>🚫 الأجهزة المعطلة</h3>
                    <div class="number" id="disabledDevices">0</div>
                </div>
                <div class="stat-card">
                    <h3>🔢 إجمالي الجلسات</h3>
                    <div class="number" id="totalSessions">0</div>
                </div>
            </div>

            <!-- Devices -->
            <div class="devices-section">
                <h2>📱 الأجهزة المسجلة</h2>
                <table>
                    <thead>
                        <tr>
                            <th>الجهاز</th>
                            <th>الموديل</th>
                            <th>الشركة</th>
                            <th>النظام</th>
                            <th>آخر ظهور</th>
                            <th>الجلسات</th>
                            <th>الحالة</th>
                            <th>الإجراءات</th>
                        </tr>
                    </thead>
                    <tbody id="devicesTable">
                        <tr><td colspan="8" style="text-align:center;">جاري التحميل...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        const API_PASSWORD = 'Hh42214221';
        let currentPassword = '';

        function showAlert(message, type = 'success') {
            const alertBox = document.getElementById('alertBox');
            alertBox.innerHTML = `<div class="alert alert-\${type}">\${message}</div>`;
            setTimeout(() => alertBox.innerHTML = '', 3000);
        }

        async function login() {
            const password = document.getElementById('loginPassword').value;
            try {
                const response = await fetch('/admin/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ password })
                });
                
                if (response.ok) {
                    currentPassword = password;
                    document.getElementById('loginScreen').style.display = 'none';
                    document.getElementById('dashboard').style.display = 'block';
                    loadDashboard();
                } else {
                    document.getElementById('loginError').style.display = 'block';
                    document.getElementById('loginError').textContent = 'كلمة مرور خاطئة!';
                }
            } catch (error) {
                alert('خطأ: ' + error.message);
            }
        }

        function logout() {
            currentPassword = '';
            document.getElementById('loginScreen').style.display = 'block';
            document.getElementById('dashboard').style.display = 'none';
            document.getElementById('loginPassword').value = '';
        }

        async function loadDashboard() {
            await loadStats();
            await loadDevices();
        }

        async function loadStats() {
            try {
                const response = await fetch(`/admin/stats?password=\${currentPassword}`);
                const stats = await response.json();
                document.getElementById('totalDevices').textContent = stats.totalDevices;
                document.getElementById('activeDevices').textContent = stats.activeDevices;
                document.getElementById('disabledDevices').textContent = stats.disabledDevices;
                document.getElementById('totalSessions').textContent = stats.totalSessions;
            } catch (error) {
                console.error('خطأ:', error);
            }
        }

        async function loadDevices() {
            try {
                const response = await fetch(`/admin/devices?password=\${currentPassword}`);
                const devices = await response.json();
                const tbody = document.getElementById('devicesTable');
                
                if (devices.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;">لا توجد أجهزة</td></tr>';
                    return;
                }

                tbody.innerHTML = devices.map(device => `
                    <tr>
                        <td>\${device.deviceName}</td>
                        <td>\${device.deviceModel}</td>
                        <td>\${device.manufacturer}</td>
                        <td>\${device.osVersion}</td>
                        <td>\${new Date(device.lastSeen).toLocaleString('ar')}</td>
                        <td>\${device.totalSessions}</td>
                        <td class="\${device.isActive ? 'status-active' : 'status-disabled'}">
                            \${device.isActive ? '✅ نشط' : '🚫 معطل'}
                        </td>
                        <td>
                            \${device.isActive ? 
                                `<button class="action-btn btn-disable" onclick="disableDevice('\${device.deviceId}')">تعطيل</button>` :
                                `<button class="action-btn btn-enable" onclick="enableDevice('\${device.deviceId}')">تفعيل</button>`
                            }
                            <button class="action-btn btn-message" onclick="sendMessage('\${device.deviceId}')">رسالة</button>
                            <button class="action-btn btn-delete" onclick="deleteDevice('\${device.deviceId}')">حذف</button>
                        </td>
                    </tr>
                `).join('');
            } catch (error) {
                console.error('خطأ:', error);
            }
        }

        async function disableDevice(deviceId) {
            const message = prompt('رسالة للمستخدم (اختياري):');
            try {
                const response = await fetch(`/admin/devices/\${deviceId}/disable`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ password: currentPassword, message })
                });
                if (response.ok) {
                    showAlert('تم تعطيل الجهاز');
                    loadDashboard();
                }
            } catch (error) {
                showAlert('خطأ: ' + error.message, 'error');
            }
        }

        async function enableDevice(deviceId) {
            try {
                const response = await fetch(`/admin/devices/\${deviceId}/enable`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ password: currentPassword })
                });
                if (response.ok) {
                    showAlert('تم تفعيل الجهاز');
                    loadDashboard();
                }
            } catch (error) {
                showAlert('خطأ: ' + error.message, 'error');
            }
        }

        async function sendMessage(deviceId) {
            const message = prompt('الرسالة:');
            if (!message) return;
            try {
                const response = await fetch(`/admin/devices/\${deviceId}/message`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ password: currentPassword, message })
                });
                if (response.ok) {
                    showAlert('تم إرسال الرسالة');
                }
            } catch (error) {
                showAlert('خطأ: ' + error.message, 'error');
            }
        }

        async function deleteDevice(deviceId) {
            if (!confirm('حذف الجهاز؟')) return;
            try {
                const response = await fetch(`/admin/devices/\${deviceId}?password=\${currentPassword}`, {
                    method: 'DELETE'
                });
                if (response.ok) {
                    showAlert('تم حذف الجهاز');
                    loadDashboard();
                }
            } catch (error) {
                showAlert('خطأ: ' + error.message, 'error');
            }
        }

        // Auto refresh
        setInterval(() => {
            if (currentPassword) {
                loadStats();
                loadDevices();
            }
        }, 10000);
    </script>
</body>
</html>
    ''';
  }

  // ========== Utilities ==========

  String _generateToken(String password) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final bytes = utf8.encode('$password-$timestamp');
    return sha256.convert(bytes).toString();
  }

  Future<String> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }
      return 'localhost';
    } catch (e) {
      return 'localhost';
    }
  }
}
