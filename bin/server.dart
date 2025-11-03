import 'dart:io';
import 'package:noon_tracker_server/server.dart';

Future<void> main() async {
  print('════════════════════════════════════════════════════════════');
  print('🚀 Central Server - Noon Price Tracker Admin Dashboard');
  print('════════════════════════════════════════════════════════════\n');

  final server = CentralServer();
  await server.start();

  print('\n════════════════════════════════════════════════════════════');
  print('📱 للوصول للوحة التحكم من أي جهاز:');
  print('════════════════════════════════════════════════════════════');

  // عرض عناوين IP المتاحة
  final interfaces = await NetworkInterface.list();
  for (var interface in interfaces) {
    for (var addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
        print('🌐 http://${addr.address}:3000/admin');
      }
    }
  }

  print('💻 من نفس الجهاز: http://localhost:3000/admin');
  print('\n🔑 كلمة المرور: Hh42214221');
  print('\n⏹️  للإيقاف: اضغط Ctrl+C');
  print('════════════════════════════════════════════════════════════\n');
}
