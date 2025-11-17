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

  // LocalSend compatible settings
  static const String _multicastAddress = '224.0.0.167';
  static const int _port = 53317;
  static const _deviceTimeout = Duration(seconds: 15); // LocalSend uses 15 sec

  final SharedPrefsService _prefs;
  final Map<String, DiscoveredDevice> _devices = {};
  final Map<String, DateTime> _lastSeen = {};

  final _devicesController = StreamController<DiscoveredDevice>.broadcast();
  Stream<DiscoveredDevice> get devicesStream => _devicesController.stream;

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
        _port,
        reuseAddress: true,
        reusePort: true,
      );

      _socket!.broadcastEnabled = true;

      // Join multicast group на всех интерфейсах
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        try {
          _socket!.joinMulticast(InternetAddress(_multicastAddress), interface);
          _log.fine('Joined multicast on ${interface.name}');
        } catch (e) {
          _log.fine('Failed to join on ${interface.name}: $e');
        }
      }

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleBroadcast(datagram);
          }
        }
      });

      // Cleanup каждые 2 секунды
      _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _cleanupStaleDevices();
      });

      _isRunning = true;
      _log.info('✅ Listening on $_multicastAddress:$_port');
    } catch (e, stackTrace) {
      _log.severe('Failed to start', e, stackTrace);
      await stop();
      rethrow;
    }
  }

  void _handleBroadcast(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final json = jsonDecode(message) as Map<String, dynamic>;

      // Check if this is LocalSend/Rapid packet
      if (!json.containsKey('fingerprint') || !json.containsKey('alias')) {
        return; // Not a valid packet
      }

      final deviceId = json['fingerprint'] as String;
      final myDeviceId = _prefs.getDeviceId();

      // Skip own device
      if (deviceId == myDeviceId) return;

      // Handle goodbye packet
      if (json['announce'] == false) {
        _handleGoodbye(deviceId);
        return;
      }

      // Validate announcement
      if (json['announce'] != true) return;

      // Extract device info
      final device = DiscoveredDevice(
        id: deviceId,
        name: json['alias'] as String,
        host: datagram.address.address, // Use sender's IP
        port: json['port'] as int,
        protocol: json['protocol'] as String? ?? 'https',
        deviceModel: json['deviceModel'] as String?,
        deviceType: json['deviceType'] as String?,
      );

      final wasNew = !_devices.containsKey(deviceId);

      _devices[deviceId] = device;
      _lastSeen[deviceId] = DateTime.now();

      if (wasNew) {
        _devicesController.add(device);
        _log.info('✅ NEW: ${device.name} at ${device.host}:${device.port}');
      } else {
        _log.fine('Updated: ${device.name}');
      }
    } catch (e) {
      // Ignore invalid packets
      _log.fine('Invalid packet: $e');
    }
  }

  void _handleGoodbye(String deviceId) {
    final device = _devices[deviceId];
    if (device != null) {
      _devices.remove(deviceId);
      _lastSeen.remove(deviceId);
      _deviceRemovedController.add(deviceId);
      _log.info('👋 Goodbye: ${device.name}');
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
      _deviceRemovedController.add(deviceId);
      _log.info('⏱️ Timeout: ${device?.name ?? deviceId}');
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      _log.info('Stopping discovery...');

      _cleanupTimer?.cancel();
      _socket?.close();

      _devices.clear();
      _lastSeen.clear();
      _isRunning = false;

      _log.info('Discovery stopped');
    } catch (e) {
      _log.severe('Stop error', e);
    }
  }

  void dispose() {
    stop();
    _devicesController.close();
    _deviceRemovedController.close();
  }
}

class DiscoveredDevice {
  final String id;
  final String name;
  final String host;
  final int port;
  final String protocol;
  final String? deviceModel;
  final String? deviceType;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.protocol = 'https',
    this.deviceModel,
    this.deviceType,
  });

  String get baseUrl => '$protocol://$host:$port';

  @override
  String toString() => '$name ($host:$port)';
}
