import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import 'package:network_info_plus/network_info_plus.dart';

final _log = Logger('Broadcast Announcer');

@lazySingleton
class BroadcastAnnouncer {
  RawDatagramSocket? _socket;
  bool _isRunning = false;
  Timer? _announceTimer;

  // LocalSend compatible settings
  static const String _multicastAddress = '224.0.0.167'; // LocalSend multicast
  static const int _port = 53317; // LocalSend port

  String? _deviceId;
  String? _deviceName;
  int? _serverPort;
  String? _protocol;
  String? _localIp;

  bool get isRunning => _isRunning;

  Future<void> start({
    required String deviceId,
    required String deviceName,
    required int serverPort,
    String protocol = 'https',
    String? avatar, // Игнорируем, не отправляем в announce
  }) async {
    if (_isRunning) return;

    _deviceId = deviceId;
    _deviceName = deviceName;
    _serverPort = serverPort;
    _protocol = protocol;

    try {
      _log.info('Starting announcer for: $deviceName');

      _localIp = await _getLocalIp();
      if (_localIp == null) {
        throw Exception('Cannot get local IP');
      }

      _log.info('Local IP: $_localIp');

      // Создаём UDP socket
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // Random port для отправки
        reuseAddress: true,
      );

      _socket!.broadcastEnabled = true;
      _socket!.multicastHops = 255;

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
          // Some interfaces might fail, that's ok
          _log.fine('Failed to join multicast on ${interface.name}: $e');
        }
      }

      // Первый announce СРАЗУ
      _sendAnnouncement();

      // Burst режим: каждые 500ms первые 5 секунд
      int burstCount = 0;
      Timer? burstTimer;

      burstTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _sendAnnouncement();
        burstCount++;

        if (burstCount >= 10) {
          // 10 * 500ms = 5 секунд
          burstTimer?.cancel();
          _log.info('Switching to normal mode (every 5 sec)');

          // Нормальный режим: каждые 5 секунд (LocalSend использует 5 сек)
          _announceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
            _sendAnnouncement();
          });
        }
      });

      _isRunning = true;
      _log.info('✅ Announcer started');
    } catch (e, stackTrace) {
      _log.severe('Failed to start', e, stackTrace);
      await stop();
      rethrow;
    }
  }

  void _sendAnnouncement() {
    if (_socket == null) return;

    try {
      // LocalSend compatible JSON format
      final message = jsonEncode({
        'alias': _deviceName, // LocalSend uses "alias" not "name"
        'version': '2.0',
        'deviceModel': _getDeviceModel(),
        'deviceType': _getDeviceType(),
        'fingerprint': _deviceId, // LocalSend uses "fingerprint" not "id"
        'port': _serverPort,
        'protocol': _protocol,
        'download': true,
        'announce': true, // Important: marks this as announcement packet
      });

      final data = utf8.encode(message);
      final destination = InternetAddress(_multicastAddress);

      final sent = _socket!.send(data, destination, _port);

      if (sent > 0) {
        _log.fine('Sent announcement ($sent bytes)');
      } else {
        _log.warning('Failed to send announcement');
      }
    } catch (e) {
      _log.severe('Send error', e);
    }
  }

  String _getDeviceModel() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'MacBook';
    if (Platform.isLinux) return 'Linux';
    return 'Desktop';
  }

  String _getDeviceType() {
    if (Platform.isAndroid || Platform.isIOS) return 'mobile';
    return 'desktop';
  }

  Future<String?> _getLocalIp() async {
    try {
      // Try network_info_plus first
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP != null && wifiIP.isNotEmpty && !wifiIP.contains('::')) {
        return wifiIP;
      }

      // Fallback: NetworkInterface
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();

        // Ищем WiFi/Ethernet интерфейс
        if (name.startsWith('wlan') ||
            name.startsWith('wlp') ||
            name.startsWith('en0') ||
            name.startsWith('eth') ||
            name.contains('wi-fi')) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback &&
                (addr.address.startsWith('192.168.') ||
                    addr.address.startsWith('10.') ||
                    addr.address.startsWith('172.'))) {
              return addr.address;
            }
          }
        }
      }

      return null;
    } catch (e) {
      _log.severe('Failed to get local IP', e);
      return null;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      _log.info('Stopping announcer...');

      // Send goodbye packet (announce: false)
      _sendGoodbye();

      await Future.delayed(const Duration(milliseconds: 100));

      _announceTimer?.cancel();
      _socket?.close();

      _isRunning = false;
      _socket = null;
      _announceTimer = null;

      _log.info('Announcer stopped');
    } catch (e) {
      _log.severe('Stop error', e);
    }
  }

  void _sendGoodbye() {
    if (_socket == null) return;

    try {
      final message = jsonEncode({
        'alias': _deviceName,
        'version': '2.0',
        'deviceModel': _getDeviceModel(),
        'deviceType': _getDeviceType(),
        'fingerprint': _deviceId,
        'port': _serverPort,
        'protocol': _protocol,
        'download': true,
        'announce': false, // ← Mark as goodbye
      });

      final data = utf8.encode(message);
      final destination = InternetAddress(_multicastAddress);

      _socket!.send(data, destination, _port);
      _log.info('Sent goodbye packet');
    } catch (e) {
      _log.severe('Goodbye error', e);
    }
  }

  void dispose() {
    stop();
  }
}
