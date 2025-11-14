import 'dart:async';
import 'package:injectable/injectable.dart';
import '../../features/lan/domain/entities/device.dart';
import '../constants/app_constants.dart';
import 'mdns_service.dart';

@lazySingleton
class DeviceDiscovery {
  final MDnsService _mdnsService;

  // Мапа обнаруженных устройств: deviceId -> Device
  final Map<String, Device> _devices = {};

  // Стрим обновлений списка устройств
  final _devicesController = StreamController<List<Device>>.broadcast();
  Stream<List<Device>> get devicesStream => _devicesController.stream;

  List<Device> get devices => _devices.values.toList();

  Timer? _cleanupTimer;
  StreamSubscription? _discoverySubscription;

  DeviceDiscovery(this._mdnsService);

  /// Запуск discovery
  Future<void> start() async {
    await _mdnsService.start();

    // Подписываемся на обнаруженные устройства
    _discoverySubscription = _mdnsService.discoveredDevices.listen((
      discovered,
    ) {
      _onDeviceDiscovered(discovered);
    });

    // Запускаем таймер для очистки устаревших устройств
    _startCleanupTimer();

    print('[Discovery] Started');
  }

  /// Остановка discovery
  Future<void> stop() async {
    await _mdnsService.stop();
    await _discoverySubscription?.cancel();
    _cleanupTimer?.cancel();

    _devices.clear();
    _devicesController.add([]);

    print('[Discovery] Stopped');
  }

  /// Обработка обнаруженного устройства
  void _onDeviceDiscovered(DiscoveredDevice discovered) {
    final now = DateTime.now();

    // Проверяем, есть ли устройство уже в списке
    if (_devices.containsKey(discovered.id)) {
      // Обновляем lastSeen
      final existing = _devices[discovered.id]!;
      _devices[discovered.id] = existing.copyWith(
        lastSeen: now,
        isOnline: true,
      );
    } else {
      // Добавляем новое устройство
      _devices[discovered.id] = Device(
        id: discovered.id,
        name: discovered.name,
        host: discovered.host,
        port: discovered.port,
        avatar: discovered.avatar,
        lastSeen: now,
        isOnline: true,
        protocol: discovered.protocol,
      );

      print('[Discovery] New device: ${discovered.name}');
    }

    // Отправляем обновленный список
    _devicesController.add(devices);
  }

  /// Таймер для очистки устаревших устройств
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      bool hasChanges = false;

      // Помечаем устройства как offline, если не видели их давно
      _devices.forEach((id, device) {
        final timeSinceLastSeen = now.difference(device.lastSeen);

        if (timeSinceLastSeen > AppConstants.deviceTimeout) {
          if (device.isOnline) {
            _devices[id] = device.copyWith(isOnline: false);
            hasChanges = true;
            print('[Discovery] Device offline: ${device.name}');
          }
        }
      });

      // Удаляем устройства, которые offline больше 5 минут
      _devices.removeWhere((id, device) {
        final timeSinceLastSeen = now.difference(device.lastSeen);
        if (!device.isOnline &&
            timeSinceLastSeen > const Duration(minutes: 5)) {
          print('[Discovery] Removing device: ${device.name}');
          return true;
        }
        return false;
      });

      if (hasChanges || _devices.isEmpty) {
        _devicesController.add(devices);
      }
    });
  }

  /// Вручную добавить устройство (например, по IP)
  void addManualDevice({
    required String host,
    required int port,
    String? name,
    String protocol = 'https',
  }) {
    final id = '$host:$port';

    _devices[id] = Device(
      id: id,
      name: name ?? host,
      host: host,
      port: port,
      lastSeen: DateTime.now(),
      isOnline: true,
      protocol: protocol,
    );

    _devicesController.add(devices);
    print('[Discovery] Manual device added: $host:$port');
  }

  /// Удалить устройство
  void removeDevice(String deviceId) {
    if (_devices.remove(deviceId) != null) {
      _devicesController.add(devices);
      print('[Discovery] Device removed: $deviceId');
    }
  }

  void dispose() {
    stop();
    _devicesController.close();
  }
}
