import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import 'package:rapid/core/logging/log_service.dart';
import 'injection.config.dart';
import '../network/http_server.dart';
import '../network/broadcast_announcer.dart';
import '../mdns/device_discovery.dart';
import '../storage/shared_prefs_service.dart';

final getIt = GetIt.instance;
final log = LogService.instance;
final _log = Logger('DI');

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

  LogService.instance;
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

    _log.fine('[DI] Device: $deviceName ($deviceId)');

    // HTTP server
    final server = getIt<HttpServerService>();
    await server.start(
      deviceId: deviceId,
      deviceName: deviceName,
      port: serverPort,
      useHttps: useHttps,
      avatar: avatar,
    );
    _log.fine('[DI] ✓ Server: ${server.port}');

    // Broadcast announcer (быстро)
    final announcer = getIt<BroadcastAnnouncer>();
    await announcer.start(
      deviceId: deviceId,
      deviceName: deviceName,
      serverPort: server.port!,
      protocol: useHttps ? 'https' : 'http',
    );
    _log.fine('[DI] ✓ Announcer started');

    // Discovery (быстро)
    final discovery = getIt<DeviceDiscovery>();
    await discovery.start();
    _log.fine('[DI] ✓ Discovery started');

    _log.fine('[DI] ✅ All services started');
  } catch (e, stackTrace) {
    _log.severe('[DI] ERROR', e, stackTrace);
    rethrow;
  }
}
