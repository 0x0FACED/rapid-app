import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'injection.config.dart';
import '../network/http_server.dart';
import '../mdns/service_announcer.dart';
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

/// Запуск основных сервисов
Future<void> _startServices() async {
  final prefs = getIt<SharedPrefsService>();

  final deviceId = prefs.getDeviceId();
  final deviceName = prefs.getDeviceName();
  final useHttps = prefs.getUseHttps();
  final serverPort = prefs.getServerPort();

  // Запускаем HTTP/HTTPS сервер
  final server = getIt<HttpServerService>();
  await server.start(
    deviceId: deviceId,
    deviceName: deviceName,
    port: serverPort,
    useHttps: useHttps,
  );

  // Запускаем mDNS announcer
  final announcer = getIt<ServiceAnnouncer>();
  await announcer.start(
    deviceId: deviceId,
    deviceName: deviceName,
    serverPort: server.port!,
  );

  // Запускаем device discovery
  final discovery = getIt<DeviceDiscovery>();
  await discovery.start();

  print('[App] All services started successfully');
}
