import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';

@lazySingleton
class BroadcastAnnouncer {
  RawDatagramSocket? _socket;
  bool _isRunning = false;
  Timer? _announceTimer;

  static const int _broadcastPort = 53318; // Порт для broadcast

  String? _deviceId;
  String? _deviceName;
  int? _serverPort;
  String? _protocol;
  String? _localIp;
  String? _avatarBase64;

  bool get isRunning => _isRunning;

  Future<void> start({
    required String deviceId,
    required String deviceName,
    required int serverPort,
    String protocol = 'https',
    String? avatar,
  }) async {
    if (_isRunning) return;

    _deviceId = deviceId;
    _deviceName = deviceName;
    _serverPort = serverPort;
    _protocol = protocol;

    if (avatar != null && avatar.isNotEmpty) {
      try {
        final file = File(avatar.replaceFirst('file://', ''));
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          _avatarBase64 = base64Encode(bytes);
          print(
            '[Broadcast] Avatar loaded: ${bytes.length} bytes → ${_avatarBase64!.length} base64 chars',
          );
        } else {
          print('[Broadcast] ⚠️ Avatar file not found: $avatar');
          _avatarBase64 = null;
        }
      } catch (e) {
        print('[Broadcast] Failed to load avatar: $e');
        _avatarBase64 = null;
      }
    } else {
      _avatarBase64 = null;
    }

    try {
      print('[Broadcast] Starting announcer...');

      _localIp = await _getLocalIp();
      if (_localIp == null) {
        throw Exception('Cannot get local IP');
      }

      print('[Broadcast] Local IP: $_localIp');

      // Создаём UDP socket
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;

      // ИСПРАВЛЕНО: Агрессивные announces первые 5 секунд
      int burstCount = 0;
      Timer? burstTimer;

      // Первый announce СРАЗУ
      _sendAnnouncement();

      // Burst режим: каждые 200ms первые 5 секунд (25 пакетов)
      burstTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _sendAnnouncement();
        burstCount++;

        if (burstCount >= 25) {
          // 25 * 200ms = 5 секунд
          burstTimer?.cancel();
          print('[Broadcast] Switching to normal mode (every 1 sec)');

          // Нормальный режим: каждую секунду
          _announceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            _sendAnnouncement();
          });
        }
      });

      _isRunning = true;
      print('[Broadcast] ✓ Announcer started');
    } catch (e) {
      print('[Broadcast] Failed to start: $e');
    }
  }

  void _sendAnnouncement() {
    if (_socket == null) return;

    try {
      final message = jsonEncode({
        'type': 'rapid_announce',
        'id': _deviceId,
        'name': _deviceName,
        'host': _localIp,
        'port': _serverPort,
        'protocol': _protocol,
        //'avatar': _avatarBase64,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final data = utf8.encode(message);
      final broadcast = InternetAddress('255.255.255.255');

      _socket!.send(data, broadcast, _broadcastPort);
      // print('[Broadcast] → Sent announcement');
    } catch (e) {
      print('[Broadcast] Send error: $e');
    }
  }

  Future<String?> _getLocalIp() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP != null && wifiIP.isNotEmpty && !wifiIP.contains('::')) {
        return wifiIP;
      }

      // Fallback через NetworkInterface
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback &&
              (addr.address.startsWith('192.168.') ||
                  addr.address.startsWith('10.') ||
                  addr.address.startsWith('172.'))) {
            return addr.address;
          }
        }
      }

      return null;
    } catch (e) {
      print('[Broadcast] Get IP error: $e');
      return null;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    _announceTimer?.cancel();
    _socket?.close();

    _isRunning = false;
    print('[Broadcast] Stopped');
  }

  void dispose() {
    stop();
  }
}
