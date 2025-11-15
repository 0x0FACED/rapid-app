import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';

@lazySingleton
class ServiceAnnouncer {
  RawDatagramSocket? _socket;
  bool _isAnnouncing = false;
  Timer? _announceTimer;

  String? _deviceId;
  String? _deviceName;
  int? _serverPort;
  String? _protocol;
  InternetAddress? _localAddress;

  static const String _mDnsAddress = '224.0.0.251';
  static const int _mDnsPort = 5353;

  bool get isAnnouncing => _isAnnouncing;

  Future<void> start({
    required String deviceId,
    required String deviceName,
    required int serverPort,
    String? avatar,
    String protocol = 'https',
  }) async {
    if (_isAnnouncing) return;

    _deviceId = deviceId;
    _deviceName = deviceName;
    _serverPort = serverPort;
    _protocol = protocol;

    try {
      print('[Announcer] ========================================');
      print('[Announcer] Starting for: $deviceName ($deviceId)');

      final ipAddress = await _getWifiIpAddress();
      if (ipAddress == null) {
        throw Exception('Cannot get WiFi IP');
      }

      _localAddress = InternetAddress(ipAddress);
      print('[Announcer] WiFi IP: $ipAddress');

      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _mDnsPort,
        reuseAddress: true,
      );

      print('[Announcer] Bound to port ${_socket!.port}');

      _socket!.broadcastEnabled = true;
      _socket!.multicastHops = 255;

      final wifiInterface = await _getWifiInterface();
      if (wifiInterface == null) {
        throw Exception('WiFi interface not found');
      }

      _socket!.joinMulticast(InternetAddress(_mDnsAddress), wifiInterface);
      print('[Announcer] ✓ Joined multicast on ${wifiInterface.name}');

      // Агрессивные announcements первые 10 секунд
      int count = 0;
      Timer? initialTimer;

      initialTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _sendAnnouncement();
        count++;

        if (count >= 20) {
          initialTimer?.cancel();
          print('[Announcer] Switching to normal mode (every 2 sec)');

          _announceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
            _sendAnnouncement();
          });
        }
      });

      _isAnnouncing = true;
      print('[Announcer] ✓ Started successfully');
      print('[Announcer] ========================================');
    } catch (e, stackTrace) {
      print('[Announcer] ✗✗✗ FAILED ✗✗✗');
      print('[Announcer] Error: $e');
      print(stackTrace);
    }
  }

  void _sendAnnouncement() {
    if (_socket == null || _localAddress == null) return;

    try {
      final packet = _buildMdnsResponsePacket();
      final destination = InternetAddress(_mDnsAddress);

      final sent = _socket!.send(packet, destination, _mDnsPort);

      if (sent > 0) {
        print('[Announcer] → Sent $sent bytes');
      } else {
        print('[Announcer] ✗ Send failed');
      }
    } catch (e) {
      print('[Announcer] ✗ Error: $e');
    }
  }

  Uint8List _buildMdnsResponsePacket() {
    final serviceName = '$_deviceName._rapid._tcp.local';
    final hostName = '$_deviceId.local';

    final serviceNameParts = _encodeDnsName(serviceName);
    final serviceTypeParts = _encodeDnsName('_rapid._tcp.local');
    final hostNameParts = _encodeDnsName(hostName);

    final txtData = 'id=$_deviceId\nname=$_deviceName\nprotocol=$_protocol';
    final txtBytes = _encodeTxtRecord(txtData);

    int size = 12;
    size += serviceTypeParts.length + 10 + serviceNameParts.length;
    size += serviceNameParts.length + 10 + 6 + hostNameParts.length;
    size += hostNameParts.length + 10 + 4;
    size += serviceNameParts.length + 10 + txtBytes.length;

    final buffer = ByteData(size);
    int offset = 0;

    buffer.setUint16(offset, 0);
    offset += 2;
    buffer.setUint16(offset, 0x8400);
    offset += 2;
    buffer.setUint16(offset, 0);
    offset += 2;
    buffer.setUint16(offset, 4);
    offset += 2;
    buffer.setUint16(offset, 0);
    offset += 2;
    buffer.setUint16(offset, 0);
    offset += 2;

    offset = _writeBytes(buffer, offset, serviceTypeParts);
    buffer.setUint16(offset, 12);
    offset += 2;
    buffer.setUint16(offset, 0x8001);
    offset += 2;
    buffer.setUint32(offset, 120);
    offset += 4;
    buffer.setUint16(offset, serviceNameParts.length);
    offset += 2;
    offset = _writeBytes(buffer, offset, serviceNameParts);

    offset = _writeBytes(buffer, offset, serviceNameParts);
    buffer.setUint16(offset, 33);
    offset += 2;
    buffer.setUint16(offset, 0x8001);
    offset += 2;
    buffer.setUint32(offset, 120);
    offset += 4;
    buffer.setUint16(offset, 6 + hostNameParts.length);
    offset += 2;
    buffer.setUint16(offset, 0);
    offset += 2;
    buffer.setUint16(offset, 0);
    offset += 2;
    buffer.setUint16(offset, _serverPort!);
    offset += 2;
    offset = _writeBytes(buffer, offset, hostNameParts);

    offset = _writeBytes(buffer, offset, hostNameParts);
    buffer.setUint16(offset, 1);
    offset += 2;
    buffer.setUint16(offset, 0x8001);
    offset += 2;
    buffer.setUint32(offset, 120);
    offset += 4;
    buffer.setUint16(offset, 4);
    offset += 2;
    final ipParts = _localAddress!.address.split('.');
    for (final part in ipParts) {
      buffer.setUint8(offset, int.parse(part));
      offset++;
    }

    offset = _writeBytes(buffer, offset, serviceNameParts);
    buffer.setUint16(offset, 16);
    offset += 2;
    buffer.setUint16(offset, 0x8001);
    offset += 2;
    buffer.setUint32(offset, 120);
    offset += 4;
    buffer.setUint16(offset, txtBytes.length);
    offset += 2;
    offset = _writeBytes(buffer, offset, txtBytes);

    return buffer.buffer.asUint8List();
  }

  Uint8List _encodeDnsName(String name) {
    final parts = name.split('.');
    final List<int> result = [];

    for (final part in parts) {
      if (part.isEmpty) continue;
      final bytes = part.codeUnits;
      result.add(bytes.length);
      result.addAll(bytes);
    }

    result.add(0);
    return Uint8List.fromList(result);
  }

  Uint8List _encodeTxtRecord(String text) {
    final lines = text.split('\n');
    final List<int> result = [];

    for (final line in lines) {
      if (line.isEmpty) continue;
      final bytes = line.codeUnits;
      result.add(bytes.length);
      result.addAll(bytes);
    }

    return Uint8List.fromList(result);
  }

  int _writeBytes(ByteData buffer, int offset, Uint8List bytes) {
    for (int i = 0; i < bytes.length; i++) {
      buffer.setUint8(offset + i, bytes[i]);
    }
    return offset + bytes.length;
  }

  Future<String?> _getWifiIpAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();

      if (wifiIP != null && wifiIP.isNotEmpty && !wifiIP.contains('::')) {
        return wifiIP;
      }

      final wifiInterface = await _getWifiInterface();
      if (wifiInterface != null && wifiInterface.addresses.isNotEmpty) {
        return wifiInterface.addresses.first.address;
      }

      return null;
    } catch (e) {
      print('[Announcer] Failed to get WiFi IP: $e');
      return null;
    }
  }

  Future<NetworkInterface?> _getWifiInterface() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();

        if (name.startsWith('wlan') ||
            name.startsWith('wlp') ||
            name.startsWith('en0') ||
            name.startsWith('ap')) {
          if (interface.addresses.isEmpty) continue;

          final addr = interface.addresses.first;

          if (addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            return interface;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> stop() async {
    if (!_isAnnouncing) return;

    try {
      _announceTimer?.cancel();
      _socket?.close();

      _isAnnouncing = false;
      _socket = null;
      _announceTimer = null;

      print('[Announcer] Stopped');
    } catch (e) {
      print('[Announcer] Stop error: $e');
    }
  }

  void dispose() {
    stop();
  }
}
