import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'injection.config.dart';
import '../network/http_server.dart';
import '../network/broadcast_announcer.dart';
import '../mdns/device_discovery.dart';
import '../storage/shared_prefs_service.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies() async {
  getIt.init();

  // Инициализируем SharedPreferences
  final prefs = getIt<SharedPrefsService>();
  await prefs.init();

  // После инициализации DI, запускаем сервер и mDNS
  await _startServices();
}

Future<void> _startServices() async {
  try {
    final prefs = getIt<SharedPrefsService>();

    final deviceId = prefs.getDeviceId();
    final deviceName = prefs.getDeviceName();
    final useHttps = prefs.getUseHttps();
    final serverPort = prefs.getServerPort();
    final avatar = prefs.getDeviceAvatar();

    print('[DI] Device: $deviceName ($deviceId)');

    // HTTP server
    final server = getIt<HttpServerService>();
    await server.start(
      deviceId: deviceId,
      deviceName: deviceName,
      port: serverPort,
      useHttps: useHttps,
    );
    print('[DI] ✓ Server: ${server.port}');

    // Broadcast announcer (быстро)
    final announcer = getIt<BroadcastAnnouncer>();
    await announcer.start(
      deviceId: deviceId,
      deviceName: deviceName,
      serverPort: server.port!,
      protocol: useHttps ? 'https' : 'http',
      avatar: avatar,
    );
    print('[DI] ✓ Announcer started');

    // Discovery (быстро)
    final discovery = getIt<DeviceDiscovery>();
    await discovery.start();
    print('[DI] ✓ Discovery started');

    print('[DI] ✅ All services started');
  } catch (e, stackTrace) {
    print('[DI] ERROR: $e');
    print(stackTrace);
    rethrow;
  }
}
