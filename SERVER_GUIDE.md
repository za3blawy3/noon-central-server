# 🚀 دليل تشغيل السيرفر المركزي

## 📋 نظرة عامة

السيرفر المركزي يسمح لك بمراقبة والتحكم في جميع الأجهزة التي تستخدم تطبيق Noon Price Tracker من أي مكان.

---

## ⚡ التشغيل السريع

### 1️⃣ تثبيت Dependencies

```powershell
cd central_server
dart pub get
```

### 2️⃣ تشغيل السيرفر

```powershell
dart run bin/server.dart
```

ستظهر رسالة مثل:
```
🚀 Central Server - Noon Price Tracker Admin Dashboard
════════════════════════════════════════════════════════════
✅ قاعدة البيانات جاهزة
🚀 السيرفر يعمل على http://0.0.0.0:3000

📱 للوصول للوحة التحكم من أي جهاز:
════════════════════════════════════════════════════════════
🌐 http://192.168.1.100:3000/admin  (مثال)
💻 من نفس الجهاز: http://localhost:3000/admin

🔑 كلمة المرور: Hh42214221
```

### 3️⃣ فتح لوحة التحكم

- من نفس الكمبيوتر: افتح المتصفح → `http://localhost:3000/admin`
- من جوالك: `http://عنوان-IP-للكمبيوتر:3000/admin`
- كلمة المرور: `Hh42214221`

---

## 🔧 إعدادات متقدمة

### تغيير المنفذ (Port)

عدل ملف `lib/server.dart`:
```dart
await shelf_io.serve(handler, '0.0.0.0', 8080); // بدلاً من 3000
```

### تغيير كلمة المرور

عدل ملف `lib/server.dart`:
```dart
static const String ADMIN_PASSWORD = 'كلمة_المرور_الجديدة';
```

---

## 🌐 الوصول من الإنترنت (اختياري)

إذا كنت تريد الوصول للوحة التحكم من خارج شبكة المنزل:

### خيار 1: Port Forwarding (إعادة توجيه المنفذ)

1. ادخل إعدادات الراوتر (عادة `192.168.1.1`)
2. ابحث عن "Port Forwarding" أو "Virtual Server"
3. أضف قاعدة جديدة:
   - External Port: `3000`
   - Internal Port: `3000`
   - Internal IP: عنوان IP للكمبيوتر
   - Protocol: TCP

4. احصل على IP العام من: https://www.whatismyip.com
5. اكتب في المتصفح: `http://IP-العام:3000/admin`

⚠️ **تحذير أمني**: هذا يعرض السيرفر للإنترنت! استخدم كلمة مرور قوية.

### خيار 2: Ngrok (أسهل)

1. حمل Ngrok: https://ngrok.com/download
2. شغل السيرفر
3. شغل Ngrok:
```powershell
ngrok http 3000
```
4. استخدم الرابط الذي يظهر (مثل: `https://abc123.ngrok.io/admin`)

---

## 🔄 التشغيل التلقائي

### Windows - Task Scheduler

1. افتح "Task Scheduler"
2. Create Basic Task
3. Trigger: "When the computer starts"
4. Action: "Start a program"
   - Program: `C:\Program Files\Dart\dart-sdk\bin\dart.exe`
   - Arguments: `run bin/server.dart`
   - Start in: `C:\Users\DELL\Documents\noon-price-tracker\central_server`

### Windows - NSSM (خدمة Windows)

```powershell
# تحميل NSSM من: https://nssm.cc/download
nssm install NoonTrackerServer "C:\Program Files\Dart\dart-sdk\bin\dart.exe"
nssm set NoonTrackerServer AppDirectory "C:\Users\DELL\Documents\noon-price-tracker\central_server"
nssm set NoonTrackerServer AppParameters "run bin/server.dart"
nssm start NoonTrackerServer
```

---

## 📱 ربط التطبيق بالسيرفر

الآن يجب تعديل التطبيق ليتصل بالسيرفر المركزي بدلاً من السيرفر المدمج.

### 1️⃣ حذف السيرفر المدمج

احذف/عطل هذه الملفات:
- `lib/services/admin_api_server.dart` (السيرفر المدمج القديم)

### 2️⃣ إضافة إعدادات السيرفر

أنشئ ملف `lib/config/server_config.dart`:

```dart
class ServerConfig {
  // عنوان السيرفر المركزي
  static const String SERVER_URL = 'http://192.168.1.100:3000'; // غير هذا لعنوان IP للكمبيوتر
  
  static const String REGISTER_ENDPOINT = '$SERVER_URL/api/device/register';
  static const String CHECK_ENDPOINT = '$SERVER_URL/api/device/check';
  static const String HEARTBEAT_ENDPOINT = '$SERVER_URL/api/device/heartbeat';
}
```

### 3️⃣ تعديل Device Tracking Service

عدل `lib/services/device_tracking_service.dart`:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/server_config.dart';

class DeviceTrackingService {
  // حذف الكود القديم المرتبط بـ SQLite المحلي
  // استبداله بطلبات HTTP للسيرفر المركزي
  
  Future<void> registerOrUpdateDevice() async {
    final deviceInfo = await _collectDeviceInfo();
    
    try {
      final response = await http.post(
        Uri.parse(ServerConfig.REGISTER_ENDPOINT),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(deviceInfo),
      );
      
      if (response.statusCode == 200) {
        print('✅ تم تسجيل الجهاز بنجاح');
      }
    } catch (e) {
      print('❌ خطأ في الاتصال بالسيرفر: $e');
    }
  }
  
  Future<Map<String, dynamic>> checkDeviceStatus(String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse(ServerConfig.CHECK_ENDPOINT),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'deviceId': deviceId}),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('❌ خطأ في التحقق من حالة الجهاز: $e');
    }
    
    return {'allowed': true, 'message': null};
  }
}
```

### 4️⃣ إضافة dependency للـ HTTP

في `pubspec.yaml` الرئيسي:
```yaml
dependencies:
  http: ^1.2.0
```

---

## 🛡️ الأمان

### ✅ الميزات الأمنية الحالية

- كلمة مرور للوحة التحكم
- CORS محدود للأمان
- فقط المشرف يمكنه رؤية لوحة التحكم
- المستخدمون لا يمكنهم الوصول للوحة التحكم

### 🔒 تحسينات مقترحة

1. **HTTPS**: استخدم شهادة SSL
2. **Rate Limiting**: منع هجمات Brute Force
3. **IP Whitelist**: السماح لأجهزة محددة فقط
4. **Logging**: تسجيل محاولات الدخول

---

## 📊 API Endpoints

### للأجهزة (Public)

```
POST /api/device/register
Body: {deviceId, deviceName, deviceModel, ...}

POST /api/device/check
Body: {deviceId}

POST /api/device/heartbeat
Body: {deviceId}
```

### للوحة التحكم (Protected)

```
POST /admin/login
Body: {password}

GET /admin/devices

GET /admin/stats

POST /admin/device/disable
Body: {deviceId, message?}

POST /admin/device/enable
Body: {deviceId}

POST /admin/device/message
Body: {deviceId, message}

DELETE /admin/device/:deviceId

POST /admin/app/disable
Body: {message?}

POST /admin/app/enable
```

---

## 🐛 حل المشاكل

### السيرفر لا يعمل

```powershell
# تحقق من المنفذ 3000 مشغول
netstat -ano | findstr :3000

# إيقاف العملية
taskkill /PID <رقم_العملية> /F
```

### لا يمكن الوصول من الجوال

1. تأكد أن الكمبيوتر والجوال على نفس الشبكة
2. عطل Windows Firewall مؤقتاً للتجربة
3. أو أضف استثناء للمنفذ 3000:

```powershell
netsh advfirewall firewall add rule name="Noon Tracker Server" dir=in action=allow protocol=TCP localport=3000
```

### قاعدة البيانات تالفة

احذف ملف `server_data.db` وسيتم إنشاؤه من جديد عند التشغيل.

---

## 📁 هيكل الملفات

```
central_server/
├── bin/
│   └── server.dart           # نقطة الدخول
├── lib/
│   ├── server.dart           # السيرفر الرئيسي
│   └── database_service.dart # خدمة قاعدة البيانات
├── pubspec.yaml
└── server_data.db            # قاعدة البيانات (تنشأ تلقائياً)
```

---

## ✅ الخطوات التالية

1. ✅ تشغيل السيرفر على الكمبيوتر
2. ⏳ تعديل التطبيق ليتصل بالسيرفر المركزي
3. ⏳ اختبار التسجيل والتحكم
4. ⏳ إنشاء نسخة منفصلة من التطبيق لتوزيعها (بدون صلاحيات Admin)
5. ⏳ إعداد التشغيل التلقائي

---

## 📞 دعم

إذا واجهت أي مشاكل، تحقق من:
1. السيرفر يعمل ويظهر IP صحيح
2. التطبيق معدل ليستخدم نفس عنوان IP
3. الجدار الناري لا يمنع الاتصال
4. الكمبيوتر والجوال على نفس الشبكة
