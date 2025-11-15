import 'dart:async';
import 'package:injectable/injectable.dart';
import '../network/broadcast_discovery.dart';
import '../../features/lan/domain/entities/device.dart';

@lazySingleton
class DeviceDiscovery {
  final BroadcastDiscovery _broadcastDiscovery;

  StreamSubscription? _addedSubscription;
  StreamSubscription? _removedSubscription; // НОВОЕ
  final List<Device> _devices = [];

  final _devicesController = StreamController<List<Device>>.broadcast();
  Stream<List<Device>> get devicesStream => _devicesController.stream;

  List<Device> get devices => List.unmodifiable(_devices);

  DeviceDiscovery(this._broadcastDiscovery);

  Future<void> start() async {
    print('[Discovery] Starting...');

    await _broadcastDiscovery.start();

    // Подписка на новые устройства
    _addedSubscription = _broadcastDiscovery.devicesStream.listen((
      discoveredDevice,
    ) {
      _onDeviceDiscovered(discoveredDevice);
    });

    // НОВОЕ: Подписка на удалённые устройства
    _removedSubscription = _broadcastDiscovery.deviceRemovedStream.listen((
      deviceId,
    ) {
      _onDeviceRemoved(deviceId);
    });

    print('[Discovery] Started');
  }

  void _onDeviceDiscovered(DiscoveredDevice discoveredDevice) {
    final existingIndex = _devices.indexWhere(
      (d) => d.id == discoveredDevice.id,
    );

    final device = Device(
      id: discoveredDevice.id,
      name: discoveredDevice.name,
      host: discoveredDevice.host,
      port: discoveredDevice.port,
      protocol: discoveredDevice.protocol,
      isOnline: true,
      lastSeen: DateTime.now(),
    );

    if (existingIndex >= 0) {
      _devices[existingIndex] = device;
    } else {
      _devices.add(device);
    }

    _devicesController.add(_devices);
  }

  // НОВОЕ: Обработка удаления устройства
  void _onDeviceRemoved(String deviceId) {
    _devices.removeWhere((d) => d.id == deviceId);
  }

  Future<void> stop() async {
    await _addedSubscription?.cancel();
    await _removedSubscription?.cancel(); // НОВОЕ
    await _broadcastDiscovery.stop();

    _devices.clear();
    print('[Discovery] Stopped');
  }

  void dispose() {
    stop();
    _devicesController.close();
  }
}
