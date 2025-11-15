class DeviceInfoModel {
  final String alias;
  final String version;
  final String deviceModel;
  final String deviceType;
  final String fingerprint;
  final int port;
  final String protocol;
  final bool download;
  final String? avatar; // НОВОЕ

  DeviceInfoModel({
    required this.alias,
    required this.version,
    required this.deviceModel,
    required this.deviceType,
    required this.fingerprint,
    required this.port,
    required this.protocol,
    this.download = true,
    this.avatar, // НОВОЕ
  });

  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) {
    return DeviceInfoModel(
      alias: json['alias'] as String,
      version: json['version'] as String,
      deviceModel: json['deviceModel'] as String? ?? 'Unknown',
      deviceType: json['deviceType'] as String? ?? 'desktop',
      fingerprint: json['fingerprint'] as String,
      port: json['port'] as int,
      protocol: json['protocol'] as String? ?? 'https',
      download: json['download'] as bool? ?? true,
      avatar: json['avatar'] as String?, // НОВОЕ
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alias': alias,
      'version': version,
      'deviceModel': deviceModel,
      'deviceType': deviceType,
      'fingerprint': fingerprint,
      'port': port,
      'protocol': protocol,
      'download': download,
      'avatar': avatar, // НОВОЕ
    };
  }
}
