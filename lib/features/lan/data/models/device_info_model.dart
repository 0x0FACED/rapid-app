import 'package:equatable/equatable.dart';

/// Модель информации об устройстве для API
class DeviceInfoModel extends Equatable {
  final String alias; // Псевдоним устройства
  final String version; // Версия протокола (2.0)
  final String? deviceModel; // Модель устройства
  final String? deviceType; // mobile | desktop | web | headless
  final String fingerprint; // SHA-256 хеш сертификата
  final int port; // Порт сервера
  final String protocol; // http | https
  final bool download; // Поддержка download API

  const DeviceInfoModel({
    required this.alias,
    required this.version,
    this.deviceModel,
    this.deviceType,
    required this.fingerprint,
    required this.port,
    this.protocol = 'https',
    this.download = true,
  });

  /// Сериализация в JSON
  Map<String, dynamic> toJson() {
    return {
      'alias': alias,
      'version': version,
      if (deviceModel != null) 'deviceModel': deviceModel,
      if (deviceType != null) 'deviceType': deviceType,
      'fingerprint': fingerprint,
      'port': port,
      'protocol': protocol,
      'download': download,
    };
  }

  /// Десериализация из JSON
  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) {
    return DeviceInfoModel(
      alias: json['alias'] as String,
      version: json['version'] as String,
      deviceModel: json['deviceModel'] as String?,
      deviceType: json['deviceType'] as String?,
      fingerprint: json['fingerprint'] as String,
      port: json['port'] as int,
      protocol: json['protocol'] as String? ?? 'https',
      download: json['download'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
    alias,
    version,
    deviceModel,
    deviceType,
    fingerprint,
    port,
    protocol,
    download,
  ];
}
