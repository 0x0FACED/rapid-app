import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import '../storage/shared_prefs_service.dart';

final _log = Logger('Broadcast Discovery');

@lazySingleton
class BroadcastDiscovery {
  RawDatagramSocket? _socket;
  bool _isRunning = false;
  Timer? _cleanupTimer;

  static const int _broadcastPort = 53318;
  static const _deviceTimeout = Duration(seconds: 4); // 4 секунды таймаут

  final SharedPrefsService _prefs;
  final Map<String, DiscoveredDevice> _devices = {};
  final Map<String, DateTime> _lastSeen = {};

  final _devicesController = StreamController<DiscoveredDevice>.broadcast();
  Stream<DiscoveredDevice> get devicesStream => _devicesController.stream;

  // НОВОЕ: стрим для удалённых устройств
  final _deviceRemovedController = StreamController<String>.broadcast();
  Stream<String> get deviceRemovedStream => _deviceRemovedController.stream;

  List<DiscoveredDevice> get devices => _devices.values.toList();

  BroadcastDiscovery(this._prefs);

  Future<void> start() async {
    if (_isRunning) return;

    try {
      _log.info('Starting broadcast listener...');

      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _broadcastPort,
        reuseAddress: true,
        reusePort: true,
      );

      _socket!.broadcastEnabled = true;

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleBroadcast(datagram);
          }
        }
      });

      // Очистка каждую секунду (было 2)
      _cleanupTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _cleanupStaleDevices();
      });

      _isRunning = true;
      _log.info('Listening on port $_broadcastPort');
    } catch (e) {
      _log.severe('Failed to start', e);
    }
  }

  void _handleBroadcast(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final json = jsonDecode(message) as Map<String, dynamic>;

      if (json['type'] != 'rapid_announce') return;

      final deviceId = json['id'] as String;
      final myDeviceId = _prefs.getDeviceId();

      if (deviceId == myDeviceId) return;

      final device = DiscoveredDevice(
        id: deviceId,
        name: json['name'] as String,
        host: json['host'] as String,
        port: json['port'] as int,
        //avatar: json['avatar'] as String?,
        protocol: json['protocol'] as String? ?? 'https',
      );

      final wasNew = !_devices.containsKey(deviceId);

      _devices[deviceId] = device;
      _lastSeen[deviceId] = DateTime.now();

      if (wasNew) {
        _devicesController.add(device);
        _log.info('NEW: ${device.name} at ${device.host}:${device.port}');
      }
    } catch (e) {
      // Ignore invalid packets
    }
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    final stale = <String>[];

    _lastSeen.forEach((deviceId, lastSeen) {
      if (now.difference(lastSeen) > _deviceTimeout) {
        stale.add(deviceId);
      }
    });

    for (final deviceId in stale) {
      final device = _devices[deviceId];
      _devices.remove(deviceId);
      _lastSeen.remove(deviceId);

      // НОВОЕ: Отправляем событие удаления
      _deviceRemovedController.add(deviceId);

      _log.info('Timeout: ${device?.name ?? deviceId}');
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    _cleanupTimer?.cancel();
    _socket?.close();

    _devices.clear();
    _lastSeen.clear();
    _isRunning = false;

    _log.info('Stopped');
  }

  void dispose() {
    stop();
    _devicesController.close();
    _deviceRemovedController.close(); // НОВОЕ
  }
}

class DiscoveredDevice {
  final String id;
  final String name;
  final String host;
  final int port;
  final String protocol;
  final String? avatar;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.protocol = 'https',
    this.avatar,
  });

  String get baseUrl => '$protocol://$host:$port';
}
