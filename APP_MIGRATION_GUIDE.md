# 🔧 دليل تحويل التطبيق للسيرفر المركزي

## 📋 الخطوات المطلوبة

### 1️⃣ تعديل إعدادات السيرفر

افتح `lib/config/server_config.dart` وغير:

```dart
// للتطوير (من نفس الجهاز):
static const String SERVER_URL = 'http://localhost:3000';

// للإنتاج (من أجهزة أخرى):
static const String SERVER_URL = 'http://10.167.208.95:3000'; // استخدم IP الذي يظهر عند تشغيل السيرفر
```

### 2️⃣ تعديل app_auth_screen.dart

استبدل `DeviceTrackingService` بـ `CentralDeviceTrackingService`:

```dart
// قبل:
import '../services/device_tracking_service.dart';
final deviceService = DeviceTrackingService.instance;

// بعد:
import '../services/central_device_tracking_service.dart';
final deviceService = CentralDeviceTrackingService.instance;
```

### 3️⃣ تعديل main.dart

احذف تهيئة السيرفر المدمج القديم واستبدله بتسجيل الجهاز:

```dart
// احذف هذا الكود:
await DeviceTrackingService.instance.database;
final adminServer = AdminApiServer(port: 8080);
await adminServer.start();

// استبدله بـ:
import 'package:noon_price_tracker/services/central_device_tracking_service.dart';

// في initializeServices():
await CentralDeviceTrackingService.instance.registerOrUpdateDevice();
CentralDeviceTrackingService.instance.startHeartbeat();
```

### 4️⃣ تعطيل الملفات القديمة (اختياري)

يمكنك حذف أو تعطيل:
- `lib/services/admin_api_server.dart` (لن نحتاجه بعد الآن)
- `lib/services/device_tracking_service.dart` (يمكن الاحتفاظ به كنسخة احتياطية)

---

## ⚡ طريقة سريعة (تطبيق الإصلاحات)

سأطبق هذه التعديلات لك الآن تلقائياً:
