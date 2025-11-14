import 'dart:async';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:injectable/injectable.dart';
import '../constants/app_constants.dart';

@lazySingleton
class MDnsService {
  MDnsClient? _client;
  bool _isRunning = false;

  // Контроллер для стрима обнаруженных устройств
  final _discoveredDevicesController =
      StreamController<DiscoveredDevice>.broadcast();
  Stream<DiscoveredDevice> get discoveredDevices =>
      _discoveredDevicesController.stream;

  bool get isRunning => _isRunning;

  /// Запуск mDNS клиента для обнаружения устройств
  Future<void> start() async {
    if (_isRunning) return;

    try {
      _client = MDnsClient();
      await _client!.start();
      _isRunning = true;

      print(
        '[mDNS] Service started, listening for ${AppConstants.serviceName}',
      );

      // Начинаем непрерывное сканирование
      _startContinuousDiscovery();
    } catch (e) {
      print('[mDNS] Failed to start: $e');
      rethrow;
    }
  }

  /// Остановка mDNS клиента
  Future<void> stop() async {
    if (!_isRunning) return;

    _client?.stop();
    _isRunning = false;
    _client = null;

    print('[mDNS] Service stopped');
  }

  /// Непрерывное обнаружение устройств с интервалом
  void _startContinuousDiscovery() {
    Timer.periodic(AppConstants.discoveryInterval, (timer) async {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      await _discoverDevices();
    });
  }

  /// Поиск устройств с сервисом _rapid._tcp
  Future<void> _discoverDevices() async {
    if (_client == null || !_isRunning) return;

    try {
      // Ищем PTR записи для нашего сервиса
      await for (final PtrResourceRecord ptr
          in _client!
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(AppConstants.serviceName),
              )
              .timeout(const Duration(seconds: 3))) {
        // Для каждой PTR записи получаем SRV (host + port)
        await _resolveSrvRecords(ptr.domainName);
      }
    } catch (e) {
      // Timeout или другие ошибки - это нормально при сканировании
      if (e is! TimeoutException) {
        print('[mDNS] Discovery error: $e');
      }
    }
  }

  /// Резолв SRV записей для получения host:port
  Future<void> _resolveSrvRecords(String domainName) async {
    try {
      await for (final SrvResourceRecord srv
          in _client!
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(domainName),
              )
              .timeout(const Duration(seconds: 2))) {
        // Получаем TXT записи для дополнительной информации
        final txtData = await _resolveTxtRecords(domainName);

        // Резолвим IP адрес из target
        final ipAddress = await _resolveIpAddress(srv.target);

        if (ipAddress != null) {
          final device = DiscoveredDevice(
            name: txtData['name'] ?? domainName,
            id: txtData['id'] ?? srv.target,
            host: ipAddress,
            port: srv.port,
            protocol: txtData['protocol'] ?? 'https',
            avatar: txtData['avatar'],
            metadata: txtData,
          );

          _discoveredDevicesController.add(device);
          print(
            '[mDNS] Discovered: ${device.name} at ${device.host}:${device.port}',
          );
        }
      }
    } catch (e) {
      if (e is! TimeoutException) {
        print('[mDNS] SRV resolution error: $e');
      }
    }
  }

  /// Резолв TXT записей для метаданных
  Future<Map<String, String>> _resolveTxtRecords(String domainName) async {
    final Map<String, String> result = {};

    try {
      await for (final TxtResourceRecord txt
          in _client!
              .lookup<TxtResourceRecord>(ResourceRecordQuery.text(domainName))
              .timeout(const Duration(seconds: 1))) {
        // txt.text это String, не Iterable
        // TXT записи могут содержать несколько пар key=value, разделённых пробелами
        final textData = txt.text;

        // Если это пустая строка, пропускаем
        if (textData.isEmpty) continue;

        // Разбиваем по пробелам (или другому разделителю)
        final entries = textData.split(' ');

        for (final entry in entries) {
          final parts = entry.split('=');
          if (parts.length == 2) {
            result[parts[0].trim()] = parts[1].trim();
          }
        }
      }
    } catch (e) {
      // TXT записи не обязательны
      if (e is! TimeoutException) {
        print('[mDNS] TXT resolution error: $e');
      }
    }

    return result;
  }

  /// Резолв IP адреса из hostname
  Future<String?> _resolveIpAddress(String hostname) async {
    try {
      // Сначала пробуем IPv4
      await for (final IPAddressResourceRecord ip
          in _client!
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(hostname),
              )
              .timeout(const Duration(seconds: 1))) {
        return ip.address.address;
      }

      // Если не нашли IPv4, пробуем IPv6
      await for (final IPAddressResourceRecord ip
          in _client!
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv6(hostname),
              )
              .timeout(const Duration(seconds: 1))) {
        return ip.address.address;
      }
    } catch (e) {
      print('[mDNS] IP resolution failed for $hostname: $e');
    }

    return null;
  }

  /// Очистка ресурсов
  void dispose() {
    stop();
    _discoveredDevicesController.close();
  }
}

/// Модель обнаруженного устройства
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
