# 🎛️ نظام المراقبة المركزي - Central Server

## 📖 نظرة عامة

نظام مراقبة مركزي آمن لتتبع جميع الأجهزة التي تستخدم تطبيق Noon Price Tracker والتحكم بها عن بعد.

### ⭐ الميزات الرئيسية

- ✅ **تتبع مباشر** للأجهزة بمجرد فتح التطبيق
- ✅ **لوحة تحكم ويب** متطورة ومتجاوبة مع الجوال
- ✅ **تحكم كامل**: تعطيل أجهزة، إرسال رسائل، حذف أجهزة
- ✅ **إحصائيات شاملة**: عدد الأجهزة، الجلسات، التاريخ
- ✅ **أمان عالي**: كلمة مرور، CORS، فصل كامل عن التطبيق
- ✅ **سهولة التوزيع**: وزع التطبيق دون قلق من الوصول للوحة التحكم

---

## 🏗️ البنية المعمارية

```
┌─────────────────┐
│   Computer      │
│  ┌───────────┐  │
│  │  Central  │  │ ← السيرفر المركزي (Dart Server)
│  │  Server   │  │ ← قاعدة بيانات SQLite
│  └─────┬─────┘  │ ← لوحة التحكم (HTML Dashboard)
└────────┼────────┘
         │
    ┌────┴────┐
    │ Wi-Fi   │
    └────┬────┘
         │
    ┌────┴────────────────────┐
    │                         │
┌───▼────┐              ┌────▼───┐
│ Phone1 │              │ Phone2 │
│  📱    │              │  📱    │
│  App   │              │  App   │
└────────┘              └────────┘
   ↓                        ↓
  ✅ يسجل الجهاز        ✅ يسجل الجهاز
  ❌ لا يرى Dashboard   ❌ لا يرى Dashboard
```

**الفرق الأساسي**:
- ❌ **قبل**: السيرفر مدمج في التطبيق → أي شخص يرى لوحة التحكم
- ✅ **بعد**: السيرفر منفصل → فقط صاحب السيرفر يرى لوحة التحكم

---

## 📂 الملفات

```
central_server/
├── bin/
│   └── server.dart              # نقطة الدخول
├── lib/
│   ├── server.dart              # السيرفر الرئيسي + Dashboard HTML
│   └── database_service.dart    # خدمة قاعدة البيانات SQLite
├── pubspec.yaml                 # Dependencies
├── server_data.db               # قاعدة البيانات (تنشأ تلقائياً)
├── SERVER_GUIDE.md              # دليل شامل
└── APP_MIGRATION_GUIDE.md       # دليل تعديل التطبيق
```

---

## 🚀 البدء السريع

### 1. تثبيت Dependencies

```bash
cd central_server
dart pub get
```

### 2. تشغيل السيرفر

```bash
dart run bin/server.dart
```

### 3. فتح لوحة التحكم

افتح المتصفح → `http://localhost:3000/admin`

**كلمة المرور**: `Hh42214221`

---

## 🔧 API Endpoints

### للأجهزة (Public - بدون حماية)

#### تسجيل/تحديث جهاز
```
POST /api/device/register
Content-Type: application/json

{
  "deviceId": "abc123",
  "deviceName": "OnePlus 7T",
  "deviceModel": "HD1925",
  "manufacturer": "OnePlus",
  "osVersion": "Android 13",
  "appVersion": "1.0.0",
  "platform": "Android"
}

Response: 200 OK
{
  "deviceId": "abc123",
  "deviceName": "OnePlus 7T",
  ...
}
```

#### التحقق من حالة الجهاز
```
POST /api/device/check
Content-Type: application/json

{
  "deviceId": "abc123"
}

Response: 200 OK
{
  "allowed": true,
  "message": "مرحباً بك!",
  "hasCustomMessage": false
}
```

#### Heartbeat (تحديث آخر ظهور)
```
POST /api/device/heartbeat
Content-Type: application/json

{
  "deviceId": "abc123"
}

Response: 200 OK
{
  "success": true
}
```

---

### للوحة التحكم (Protected - بكلمة مرور)

#### تسجيل الدخول
```
POST /admin/login
Content-Type: application/json

{
  "password": "Hh42214221"
}

Response: 200 OK
{
  "success": true,
  "message": "تم تسجيل الدخول بنجاح"
}
```

#### الحصول على جميع الأجهزة
```
GET /admin/devices?password=Hh42214221

Response: 200 OK
[
  {
    "deviceId": "abc123",
    "deviceName": "OnePlus 7T",
    "isActive": true,
    "totalSessions": 5,
    ...
  }
]
```

#### الإحصائيات
```
GET /admin/stats?password=Hh42214221

Response: 200 OK
{
  "totalDevices": 3,
  "activeDevices": 2,
  "disabledDevices": 1,
  "totalSessions": 45
}
```

#### تعطيل جهاز
```
POST /admin/device/disable
Content-Type: application/json

{
  "password": "Hh42214221",
  "deviceId": "abc123",
  "message": "جهازك معطل لأسباب أمنية"
}
```

#### تفعيل جهاز
```
POST /admin/device/enable
Content-Type: application/json

{
  "password": "Hh42214221",
  "deviceId": "abc123"
}
```

#### إرسال رسالة مخصصة
```
POST /admin/device/message
Content-Type: application/json

{
  "password": "Hh42214221",
  "deviceId": "abc123",
  "message": "مرحباً! هذه رسالة اختبار"
}
```

#### حذف جهاز
```
DELETE /admin/device/:deviceId?password=Hh42214221
```

---

## 🔐 الأمان

### الحماية الحالية

1. **كلمة مرور للوحة التحكم**: `Hh42214221`
2. **CORS محدود**: يمنع الطلبات من مصادر غير موثوقة
3. **فصل كامل**: المستخدمون لا يعرفون حتى بوجود لوحة التحكم

### تحسينات مستقبلية (اختياري)

```dart
// في lib/server.dart

// 1. HTTPS
await shelf_io.serve(handler, '0.0.0.0', 3000,
  securityContext: SecurityContext()
    ..useCertificateChain('cert.pem')
    ..usePrivateKey('key.pem')
);

// 2. Rate Limiting
final loginAttempts = <String, int>{};

// 3. IP Whitelist
final allowedIPs = ['192.168.1.100', '10.0.0.5'];
if (!allowedIPs.contains(request.connectionInfo?.remoteAddress.address)) {
  return Response.forbidden('IP غير مسموح');
}

// 4. JWT Tokens بدلاً من كلمة المرور في كل طلب
```

---

## 🌐 الوصول من الإنترنت

### الخيار 1: Port Forwarding

1. ادخل إعدادات الراوتر (`192.168.1.1`)
2. Port Forwarding → أضف:
   - External: 3000
   - Internal: 3000
   - IP: عنوان IP للكمبيوتر
3. احصل على IP العام: https://whatismyip.com
4. افتح: `http://IP-العام:3000/admin`

⚠️ **تحذير**: يعرض السيرفر للإنترنت! استخدم HTTPS وكلمة مرور قوية.

### الخيار 2: Ngrok (أسهل)

```bash
# حمل Ngrok: https://ngrok.com/download
ngrok http 3000
```

استخدم الرابط الذي يظهر:
```
https://abc123.ngrok.io/admin
```

---

## 💾 قاعدة البيانات

### الهيكل

#### جدول `devices`
```sql
CREATE TABLE devices (
  deviceId TEXT PRIMARY KEY,
  deviceName TEXT,
  deviceModel TEXT,
  manufacturer TEXT,
  osVersion TEXT,
  appVersion TEXT,
  platform TEXT,
  firstSeen TEXT,
  lastSeen TEXT,
  isActive INTEGER,
  customMessage TEXT,
  totalSessions INTEGER
);
```

#### جدول `app_control`
```sql
CREATE TABLE app_control (
  id INTEGER PRIMARY KEY,
  isAppEnabled INTEGER,
  globalMessage TEXT,
  lastUpdate TEXT
);
```

### موقع الملف

```
central_server/server_data.db
```

### النسخ الاحتياطي

```powershell
# نسخ
copy server_data.db server_data_backup.db

# استرجاع
copy server_data_backup.db server_data.db
```

---

## 🔄 التشغيل التلقائي

### Windows Task Scheduler

1. Task Scheduler → Create Basic Task
2. Trigger: "When computer starts"
3. Action: Start a program
   - Program: `C:\...\dart.exe`
   - Arguments: `run bin/server.dart`
   - Start in: `C:\...\central_server`

### NSSM (Windows Service)

```powershell
nssm install NoonServer "C:\...\dart.exe"
nssm set NoonServer AppDirectory "C:\...\central_server"
nssm set NoonServer AppParameters "run bin/server.dart"
nssm start NoonServer
```

---

## 📱 ربط التطبيق

### في التطبيق

ملف `lib/config/server_config.dart`:
```dart
static const String SERVER_URL = 'http://10.167.208.95:3000';
```

### تدفق البيانات

```
App Start
  ↓
CentralDeviceTrackingService.registerOrUpdateDevice()
  ↓
POST http://SERVER_URL/api/device/register
  ↓
السيرفر يستقبل ويخزن في قاعدة البيانات
  ↓
لوحة التحكم تعرض الجهاز الجديد
```

---

## 🐛 حل المشاكل

### السيرفر لا يعمل

```powershell
# تحقق من المنفذ
netstat -ano | findstr :3000

# أغلق العملية
taskkill /PID <PID> /F
```

### لا يمكن الوصول من جهاز آخر

```powershell
# عطل Firewall مؤقتاً للتجربة
# أو أضف استثناء:
netsh advfirewall firewall add rule name="NoonServer" dir=in action=allow protocol=TCP localport=3000
```

### الجهاز لا يظهر في Dashboard

1. تحقق من `server_config.dart` → IP صحيح؟
2. تحقق من Console:
   ```
   ✅ تم تسجيل الجهاز بنجاح
   ```
3. تحقق من لوج السيرفر:
   ```
   [200] POST /api/device/register
   ```

---

## 📊 الإحصائيات والمراقبة

لوحة التحكم تعرض:

- 📱 **إجمالي الأجهزة**: عدد كل الأجهزة المسجلة
- ✅ **الأجهزة النشطة**: الأجهزة التي يمكنها استخدام التطبيق
- 🚫 **الأجهزة المعطلة**: الأجهزة المحظورة
- 🔢 **إجمالي الجلسات**: عدد مرات فتح التطبيق من كل الأجهزة
- 🕐 **آخر ظهور**: آخر مرة فتح فيها كل جهاز التطبيق
- 📅 **تاريخ التسجيل**: متى سجل الجهاز لأول مرة

---

## 🎁 ملحقات مفيدة

### 1. تصدير البيانات

```dart
// أضف في lib/server.dart
router.get('/admin/export', (Request request) async {
  final password = request.url.queryParameters['password'];
  if (password != ADMIN_PASSWORD) {
    return Response.forbidden('...');
  }
  
  final devices = await _db.getAllDevices();
  return Response.ok(
    json.encode(devices),
    headers: {
      'Content-Type': 'application/json',
      'Content-Disposition': 'attachment; filename=devices.json'
    }
  );
});
```

### 2. Webhook للإشعارات

```dart
// إرسال إشعار عند تسجيل جهاز جديد
await http.post(
  Uri.parse('https://hooks.slack.com/...'),
  body: json.encode({
    'text': '🆕 جهاز جديد: ${device['deviceName']}'
  })
);
```

---

## 📚 مراجع إضافية

- [دليل التشغيل الشامل](SERVER_GUIDE.md)
- [دليل تعديل التطبيق](APP_MIGRATION_GUIDE.md)
- [البدء السريع](../QUICK_START.md)

---

## ✅ الخلاصة

نظام مراقبة مركزي آمن وقوي يعطيك:

- ✅ تحكم كامل في الأجهزة
- ✅ أمان عالي (فصل كامل عن التطبيق)
- ✅ سهولة التوزيع
- ✅ إحصائيات شاملة
- ✅ لوحة تحكم احترافية

**جاهز للاستخدام! 🚀**

---

## 📧 الدعم

لأي استفسارات أو مشاكل، راجع:
- ملفات `.md` الأخرى
- أو ارجع لـ GitHub Copilot
