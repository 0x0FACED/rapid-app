import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
  final Map<String, Timer> _pingTimers = {}; // НОВОЕ: таймеры для ping
  final Map<String, int> _failedPingCounts = {}; // НОВОЕ: счётчик failed pings

  final _devicesController = StreamController<List<Device>>.broadcast();
  Stream<List<Device>> get devicesStream => _devicesController.stream;

  List<Device> get devices => List.unmodifiable(_devices);
  final Map<String, bool> _pingInProgress = {};

  static const _pingInterval = Duration(
    milliseconds: 1000,
  ); // Ping каждые 0.5 сек
  static const _maxFailedPings = 6; // 3 секунды (6 * 0.5s) до disconnect

  DeviceDiscovery(
    this._broadcastDiscovery,
    this._broadcastAnnouncer,
    this._apiClient,
    this._prefs,
  );

  Future<void> start() async {
    _log.info('[Discovery] Starting...');

    // Запускаем announcer
    await _broadcastAnnouncer.start(
      deviceId: _prefs.getDeviceId(),
      deviceName: _prefs.getDeviceName(),
      serverPort: _prefs.getServerPort(),
      protocol: _prefs.getUseHttps() ? 'https' : 'http',
      avatar: _prefs.getDeviceAvatar(),
    );

    await _broadcastDiscovery.start();

    // Подписка на новые устройства (только первичное обнаружение)
    _addedSubscription = _broadcastDiscovery.devicesStream.listen((
      discoveredDevice,
    ) {
      _onDeviceDiscovered(discoveredDevice);
    });

    // Подписка на удалённые устройства НЕ НУЖНА - убираем сами через ping timeout

    _log.info('[Discovery] Started');
  }

  Uint8List? _decodeAvatar(String? base64Avatar) {
    if (base64Avatar == null || base64Avatar.isEmpty) return null;
    try {
      return base64Decode(base64Avatar);
    } catch (_) {
      return null;
    }
  }

  void _onDeviceDiscovered(DiscoveredDevice discoveredDevice) {
    final bytes = _decodeAvatar(discoveredDevice.avatar);

    final existingIndex = _devices.indexWhere(
      (d) => d.id == discoveredDevice.id,
    );

    // Если устройство новое - добавляем и запускаем ping
    if (existingIndex == -1) {
      final device = Device(
        id: discoveredDevice.id,
        name: discoveredDevice.name,
        host: discoveredDevice.host,
        port: discoveredDevice.port,
        protocol: discoveredDevice.protocol,
        isOnline: true,
        lastSeen: DateTime.now(),
        avatar: discoveredDevice.avatar,
        avatarBytes: bytes,
      );

      _devices.add(device);
      _devicesController.add(List.from(_devices));

      _log.info(
        '[Discovery] ✅ New device: ${device.name} (${device.host}:${device.port})',
      );

      // НОВОЕ: Запускаем HTTP polling для этого устройства
      _startPolling(device);
    }
  }

  void _startPolling(Device device) {
    _failedPingCounts[device.id] = 0;
    _pingTimers[device.id]?.cancel();

    _pingInProgress[device.id] = false;

    _pingTimers[device.id] = Timer.periodic(_pingInterval, (_) async {
      if (_pingInProgress[device.id] == true) {
        // Предыдущий ping ещё не завершился — не плодим параллельные запросы
        return;
      }

      _pingInProgress[device.id] = true;
      try {
        await _pingDevice(device);
      } finally {
        _pingInProgress[device.id] = false;
      }
    });

    _log.info('[Discovery] Started polling ${device.name}');
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

  // НОВОЕ: Ping устройства через HTTP
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
        // если у тебя есть copyWith
        name: deviceInfo.alias,
        port: deviceInfo.port,
        protocol: deviceInfo.protocol,
        avatar: deviceInfo.avatar,
        avatarBytes: _decodeAvatar(deviceInfo.avatar),
        isOnline: true,
      );

      // Проверяем, что что-то реально изменилось, кроме lastSeen
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
    } else {
      _log.severe(
        '[Discovery] Ping failed for $deviceName: $failedCount/$_maxFailedPings',
      );
    }
  }

  // НОВОЕ: Удаление устройства
  void _removeDevice(String deviceId) {
    // Останавливаем polling
    _pingTimers[deviceId]?.cancel();
    _pingTimers.remove(deviceId);
    _failedPingCounts.remove(deviceId);
    _pingInProgress.remove(deviceId);

    // Удаляем из списка
    final device = _devices.firstWhere((d) => d.id == deviceId);
    _devices.removeWhere((d) => d.id == deviceId);
    _devicesController.add(List.from(_devices));

    _log.info('[Discovery] ✅ Device removed: ${device.name}');
  }

  Future<void> stop() async {
    // Останавливаем все таймеры
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
}
