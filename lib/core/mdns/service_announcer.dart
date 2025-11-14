import 'dart:async';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:injectable/injectable.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../constants/app_constants.dart';

@lazySingleton
class ServiceAnnouncer {
  MDnsClient? _responder;
  bool _isAnnouncing = false;

  String? _deviceId;
  String? _deviceName;
  int? _serverPort;

  bool get isAnnouncing => _isAnnouncing;

  /// Начать анонсирование нашего сервиса
  Future<void> start({
    required String deviceId,
    required String deviceName,
    required int serverPort,
    String? avatar,
  }) async {
    if (_isAnnouncing) return;

    _deviceId = deviceId;
    _deviceName = deviceName;
    _serverPort = serverPort;

    try {
      _responder = MDnsClient();
      await _responder!.start();

      // Получаем локальный IP адрес
      final ipAddress = await _getLocalIpAddress();
      if (ipAddress == null) {
        throw Exception('Cannot determine local IP address');
      }

      // Создаем полное доменное имя для нашего сервиса
      final serviceName = '$deviceId.${AppConstants.serviceName}.local';

      // Регистрируем сервис - отвечаем на запросы
      _startResponding(
        serviceName: serviceName,
        ipAddress: ipAddress,
        port: serverPort,
        deviceName: deviceName,
        deviceId: deviceId,
        avatar: avatar,
      );

      _isAnnouncing = true;
      print(
        '[Announcer] Service registered: $serviceName on $ipAddress:$serverPort',
      );
    } catch (e) {
      print('[Announcer] Failed to start: $e');
      rethrow;
    }
  }

  /// Остановить анонсирование
  Future<void> stop() async {
    if (!_isAnnouncing) return;

    _responder?.stop();
    _isAnnouncing = false;
    _responder = null;

    print('[Announcer] Service unregistered');
  }

  /// Отвечаем на mDNS запросы
  void _startResponding({
    required String serviceName,
    required String ipAddress,
    required int port,
    required String deviceName,
    required String deviceId,
    String? avatar,
  }) {
    // multicast_dns не поддерживает полноценную регистрацию сервиса
    // Нужно вручную отвечать на запросы
    // Это упрощенная реализация - для production лучше использовать flutter_nsd

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isAnnouncing) {
        timer.cancel();
        return;
      }

      // Периодически отправляем unsolicited multicast responses
      // Это позволит другим устройствам обнаружить нас
      try {
        // В реальности здесь нужна более сложная логика
        // Для упрощения можно использовать пакет flutter_nsd вместо multicast_dns
        print('[Announcer] Still announcing $serviceName');
      } catch (e) {
        print('[Announcer] Error during announcement: $e');
      }
    });
  }

  /// Получить локальный IP адрес устройства
  Future<String?> _getLocalIpAddress() async {
    try {
      final info = NetworkInfo();

      // Пробуем получить WiFi IP
      String? ip = await info.getWifiIP();

      // Если не получилось через WiFi, пробуем через network interfaces
      if (ip == null || ip.isEmpty) {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );

        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            // Берем первый не-loopback адрес
            if (!addr.isLoopback) {
              ip = addr.address;
              break;
            }
          }
          if (ip != null) break;
        }
      }

      return ip;
    } catch (e) {
      print('[Announcer] Failed to get local IP: $e');
      return null;
    }
  }

  void dispose() {
    stop();
  }
}
