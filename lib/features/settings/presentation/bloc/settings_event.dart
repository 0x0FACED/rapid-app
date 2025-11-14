import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class SettingsInitialize extends SettingsEvent {}

class SettingsChangeTheme extends SettingsEvent {
  final String themeMode; // 'system' | 'light' | 'dark'

  const SettingsChangeTheme(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class SettingsChangeLanguage extends SettingsEvent {
  final String language; // 'en' | 'ru'

  const SettingsChangeLanguage(this.language);

  @override
  List<Object?> get props => [language];
}

class SettingsUpdateDeviceName extends SettingsEvent {
  final String name;

  const SettingsUpdateDeviceName(this.name);

  @override
  List<Object?> get props => [name];
}

class SettingsUpdateAvatar extends SettingsEvent {
  final String? avatarPath;

  const SettingsUpdateAvatar(this.avatarPath);

  @override
  List<Object?> get props => [avatarPath];
}

class SettingsToggleHttps extends SettingsEvent {
  final bool useHttps;

  const SettingsToggleHttps(this.useHttps);

  @override
  List<Object?> get props => [useHttps];
}
