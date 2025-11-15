import 'dart:async';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:injectable/injectable.dart';
import '../storage/shared_prefs_service.dart';
import '../platform/multicast_lock.dart';

@lazySingleton
class MDnsService {
  MDnsClient? _client;
  bool _isRunning = false;
  Timer? _queryTimer;

  final _discoveredDevicesController =
      StreamController<DiscoveredDevice>.broadcast();
  Stream<DiscoveredDevice> get discoveredDevices =>
      _discoveredDevicesController.stream;

  final SharedPrefsService _prefs;
  final Map<String, DiscoveredDevice> _devicesCache = {};

  bool get isRunning => _isRunning;

  MDnsService(this._prefs);

  Future<void> start() async {
    if (_isRunning) return;

    print('[mDNS] ========================================');
    print('[mDNS] Starting discovery');

    _startInBackground();
  }

  void _startInBackground() async {
    try {
      // Acquire multicast lock (может быть медленным на Android)
      await MulticastLock.acquire();

      // Создаём ОДИН клиент
      _client = MDnsClient();
      await _client!.start();

      _isRunning = true;
      print('[mDNS] ✓ Client started');

      // Первый query через 500ms (даём время на инициализацию)
      Future.delayed(const Duration(milliseconds: 500), _performQuery);

      // Периодические queries каждые 5 секунд (не 1!)
      _queryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_isRunning) _performQuery();
      });

      print('[mDNS] ✓ Discovery running (query every 5 sec)');
    } catch (e) {
      print('[mDNS] ✗ Failed to start: $e');
    }
  }

  Future<void> _performQuery() async {
    try {
      _client!
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('_rapid._tcp.local'),
          )
          .timeout(const Duration(seconds: 2))
          .listen(
            (ptr) {
              print('[mDNS] ← PTR: ${ptr.domainName}');
              _resolveService(ptr.domainName);
            },
            onError: (e) {
              if (e is! TimeoutException) {
                print('[mDNS] Query error: $e');
              }
            },
          );
    } catch (e) {
      print('[mDNS] Query exception: $e');
    }
  }

  Future<void> _resolveService(String serviceName) async {
    try {
      String? host;
      int? port;
      String? ipAddress;
      final Map<String, String> txtData = {};

      await for (final SrvResourceRecord srv
          in _client!
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(serviceName),
              )
              .timeout(const Duration(seconds: 2))) {
        host = srv.target;
        port = srv.port;
        print('[mDNS]   SRV: $host:$port');
        break;
      }

      if (host == null || port == null) {
        print('[mDNS]   ✗ No SRV');
        return;
      }

      await for (final IPAddressResourceRecord ip
          in _client!
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(host),
              )
              .timeout(const Duration(seconds: 2))) {
        ipAddress = ip.address.address;
        print('[mDNS]   A: $ipAddress');
        break;
      }

      if (ipAddress == null) {
        print('[mDNS]   ✗ No A record');
        return;
      }

      await for (final TxtResourceRecord txt
          in _client!
              .lookup<TxtResourceRecord>(ResourceRecordQuery.text(serviceName))
              .timeout(const Duration(seconds: 2))) {
        final entries = txt.text.trim().split('\n');
        for (final entry in entries) {
          final parts = entry.split('=');
          if (parts.length >= 2) {
            txtData[parts[0].trim()] = parts.sublist(1).join('=').trim();
          }
        }
        print('[mDNS]   TXT: $txtData');
        break;
      }

      final deviceId = txtData['id'] ?? serviceName;
      final myDeviceId = _prefs.getDeviceId();

      print('[mDNS]   Device ID: $deviceId');
      print('[mDNS]   My ID: $myDeviceId');

      if (deviceId == myDeviceId) {
        print('[mDNS]   → Ignoring (own device)');
        return;
      }

      if (deviceId == myDeviceId) {
        return; // Своё устройство игнорируем
      }

      final device = DiscoveredDevice(
        name: txtData['name'] ?? serviceName,
        id: deviceId,
        host: ipAddress,
        port: port,
        protocol: txtData['protocol'] ?? 'https',
        avatar: txtData['avatar'],
        metadata: txtData,
      );

      final wasKnown = _devicesCache.containsKey(deviceId);

      _devicesCache[deviceId] = device;
      _discoveredDevicesController.add(device);

      if (wasKnown) {
        print(
          '[mDNS] ✓ Device updated: ${device.name} at ${device.host}:${device.port}',
        );
      } else {
        print(
          '[mDNS] ✅ NEW DEVICE: ${device.name} at ${device.host}:${device.port}',
        );
      }
    } on TimeoutException {
      print('[mDNS]   Timeout resolving $serviceName');
    } catch (e) {
      print('[mDNS]   Error: $e');
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      _queryTimer?.cancel();
      await MulticastLock.release();

      _isRunning = false;
      _queryTimer = null;
      _devicesCache.clear();

      print('[mDNS] Stopped');
    } catch (e) {
      print('[mDNS] Stop error: $e');
    }
  }

  void dispose() {
    stop();
    _discoveredDevicesController.close();
  }
}

class DiscoveredDevice {
  final String id;
  final String name;
  final String host;
  final int port;
  final String protocol;
  final String? avatar;
  final Map<String, String> metadata;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.protocol = 'https',
    this.avatar,
    this.metadata = const {},
  });

  String get baseUrl => '$protocol://$host:$port';
}
