import 'package:equatable/equatable.dart';

class UserSettings extends Equatable {
  final String deviceId;
  final String deviceName;
  final String? avatar;
  final String themeMode; // 'light' | 'dark' | 'system'
  final String language; // 'en' | 'ru'
  final bool useHttps;
  final int serverPort;

  const UserSettings({
    required this.deviceId,
    required this.deviceName,
    this.avatar,
    this.themeMode = 'system',
    this.language = 'ru',
    this.useHttps = true,
    this.serverPort = 53317,
  });

  UserSettings copyWith({
    String? deviceId,
    String? deviceName,
    String? avatar,
    String? themeMode,
    String? language,
    bool? useHttps,
    int? serverPort,
  }) {
    return UserSettings(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      avatar: avatar ?? this.avatar,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      useHttps: useHttps ?? this.useHttps,
      serverPort: serverPort ?? this.serverPort,
    );
  }

  @override
  List<Object?> get props => [
    deviceId,
    deviceName,
    avatar,
    themeMode,
    language,
    useHttps,
    serverPort,
  ];
}
