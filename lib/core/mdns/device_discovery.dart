import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import '../network/broadcast_discovery.dart';
import '../network/broadcast_announcer.dart';
import '../network/api_client.dart';
import '../storage/shared_prefs_service.dart';
import '../../features/lan/domain/entities/device.dart';

final _log = Logger('Device Discovery');

@lazySingleton
class DeviceDiscovery {
  final BroadcastDiscovery _broadcastDiscovery;
  final BroadcastAnnouncer _broadcastAnnouncer;
  final ApiClient _apiClient;
  final SharedPrefsService _prefs;

  StreamSubscription? _addedSubscription;
  StreamSubscription? _removedSubscription;

  final List<Device> _devices = [];
  final Map<String, Timer> _pingTimers = {};
  final Map<String, int> _failedPingCounts = {};
  final Map<String, bool> _pingInProgress = {};

  final _devicesController = StreamController<List<Device>>.broadcast();
  Stream<List<Device>> get devicesStream => _devicesController.stream;

  List<Device> get devices => List.unmodifiable(_devices);

  static const _pingInterval = Duration(seconds: 3); // Ping каждые 3 секунды
  static const _maxFailedPings = 3; // 9 секунд до disconnect

  DeviceDiscovery(
    this._broadcastDiscovery,
    this._broadcastAnnouncer,
    this._apiClient,
    this._prefs,
  );

  Future<void> start() async {
    _log.info('[Discovery] Starting...');

    final deviceId = _prefs.getDeviceId();
    final deviceName = _prefs.getDeviceName();
    final useHttps = _prefs.getUseHttps();
    final serverPort = _prefs.getServerPort();
    final avatar = _prefs.getDeviceAvatar();

    _log.fine('[Discovery] Device: $deviceName ($deviceId)');

    // Запускаем announcer
    await _broadcastAnnouncer.start(
      deviceId: deviceId,
      deviceName: deviceName,
      serverPort: serverPort,
      protocol: useHttps ? 'https' : 'http',
      avatar: avatar,
    );
    _log.fine('[Discovery] ✓ Announcer started');

    // Запускаем discovery
    await _broadcastDiscovery.start();
    _log.fine('[Discovery] ✓ Discovery started');

    // Подписываемся на новые устройства
    _addedSubscription = _broadcastDiscovery.devicesStream.listen(
      _onDeviceDiscovered,
    );

    // Подписываемся на удалённые устройства
    _removedSubscription = _broadcastDiscovery.deviceRemovedStream.listen(
      _onDeviceRemoved,
    );

    _log.info('[Discovery] ✅ All services started');
  }

  void _onDeviceDiscovered(DiscoveredDevice discoveredDevice) {
    final existingIndex = _devices.indexWhere(
      (d) => d.id == discoveredDevice.id,
    );

    if (existingIndex == -1) {
      final device = Device(
        id: discoveredDevice.id,
        name: discoveredDevice.name,
        host: discoveredDevice.host,
        port: discoveredDevice.port,
        protocol: discoveredDevice.protocol,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      _devices.add(device);
      _devicesController.add(List.from(_devices));

      _log.info(
        '[Discovery] ✅ New: ${device.name} (${device.host}:${device.port})',
      );

      // Запускаем HTTP polling
      _startPolling(device);
    }
  }

  void _onDeviceRemoved(String deviceId) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index >= 0) {
      final device = _devices[index];
      _removeDevice(deviceId);
      _log.info('[Discovery] 👋 Removed: ${device.name}');
    }
  }

  void _startPolling(Device device) {
    _failedPingCounts[device.id] = 0;
    _pingTimers[device.id]?.cancel();
    _pingInProgress[device.id] = false;

    _pingTimers[device.id] = Timer.periodic(_pingInterval, (_) async {
      if (_pingInProgress[device.id] == true) return;

      _pingInProgress[device.id] = true;
      try {
        await _pingDevice(device);
      } finally {
        _pingInProgress[device.id] = false;
      }
    });

    _log.fine('[Discovery] Started polling ${device.name}');
  }

  Future<void> _pingDevice(Device device) async {
    try {
      final deviceInfo = await _apiClient.getDeviceInfo(device.baseUrl);
      if (deviceInfo == null) {
        _handlePingFailure(device.id, device.name);
        return;
      }

      _failedPingCounts[device.id] = 0;

      final index = _devices.indexWhere((d) => d.id == device.id);
      if (index < 0) return;

      final current = _devices[index];
      final updated = current.copyWith(
        name: deviceInfo.alias,
        port: deviceInfo.port,
        protocol: deviceInfo.protocol,
        avatar: deviceInfo.avatar,
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      final hasChanges =
          current.name != updated.name ||
          current.port != updated.port ||
          current.protocol != updated.protocol ||
          current.avatar != updated.avatar ||
          current.isOnline != updated.isOnline;

      if (hasChanges) {
        _devices[index] = updated;
        _devicesController.add(List.from(_devices));
      }
    } catch (e) {
      _handlePingFailure(device.id, device.name);
    }
  }

  void _handlePingFailure(String deviceId, String deviceName) {
    _failedPingCounts[deviceId] = (_failedPingCounts[deviceId] ?? 0) + 1;
    final failedCount = _failedPingCounts[deviceId]!;

    if (failedCount >= _maxFailedPings) {
      _log.warning(
        '[Discovery] ⚠️ $deviceName timeout after $failedCount failed pings',
      );
      _removeDevice(deviceId);
    }
  }

  void _removeDevice(String deviceId) {
    _pingTimers[deviceId]?.cancel();
    _pingTimers.remove(deviceId);
    _failedPingCounts.remove(deviceId);
    _pingInProgress.remove(deviceId);

    _devices.removeWhere((d) => d.id == deviceId);
    _devicesController.add(List.from(_devices));
  }

  Future<void> stop() async {
    for (final timer in _pingTimers.values) {
      timer.cancel();
    }
    _pingTimers.clear();
    _failedPingCounts.clear();

    await _addedSubscription?.cancel();
    await _removedSubscription?.cancel();
    await _broadcastDiscovery.stop();
    await _broadcastAnnouncer.stop();

    _devices.clear();
    _log.info('[Discovery] Stopped');
  }

  void dispose() {
    stop();
    _devicesController.close();
  }

  Future<void> addManualDevice({
    required String host,
    required int port,
    String? protocolOverride,
  }) async {
    final useHttps = _prefs.getUseHttps();
    final protocol = protocolOverride ?? (useHttps ? 'https' : 'http');

    final baseUrl = '$protocol://$host:$port';
    print('[Discovery] Manual add: $baseUrl');

    try {
      final info = await _apiClient.getDeviceInfo(baseUrl);
      if (info == null) {
        print('[Discovery] Manual add failed: /info is null');
        return;
      }

      // Уже есть такой device?
      final existingIndex = _devices.indexWhere(
        (d) => d.host == host && d.port == port,
      );
      if (existingIndex != -1) {
        print(
          '[Discovery] Manual device already exists: ${_devices[existingIndex].name}',
        );
        return;
      }

      final device = Device(
        id: info.fingerprint,
        name: info.alias,
        host: host,
        port: info.port,
        protocol: info.protocol,
        isOnline: true,
        lastSeen: DateTime.now(),
        avatar: info.avatar,
      );

      _devices.add(device);
      _devicesController.add(List.from(_devices));

      print('Manual device added: ${device.name} ($baseUrl)');

      _startPolling(device);
    } catch (e) {
      print('Manual add error: $e');
    }
  }
}
