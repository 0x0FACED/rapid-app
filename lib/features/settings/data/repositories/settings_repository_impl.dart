import 'package:injectable/injectable.dart';
import '../../../../core/storage/shared_prefs_service.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';

@LazySingleton(as: SettingsRepository)
class SettingsRepositoryImpl implements SettingsRepository {
  final SharedPrefsService _prefs;

  SettingsRepositoryImpl(this._prefs);

  @override
  Future<UserSettings> getSettings() async {
    return UserSettings(
      deviceId: _prefs.getDeviceId(),
      deviceName: _prefs.getDeviceName(),
      avatar: _prefs.getDeviceAvatar(),
      themeMode: _prefs.getThemeMode(),
      language: _prefs.getLanguage(),
      useHttps: _prefs.getUseHttps(),
      serverPort: _prefs.getServerPort(),
    );
  }

  @override
  Future<void> updateSettings(UserSettings settings) async {
    await _prefs.setDeviceId(settings.deviceId);
    await _prefs.setDeviceName(settings.deviceName);
    await _prefs.setDeviceAvatar(settings.avatar);
    await _prefs.setThemeMode(settings.themeMode);
    await _prefs.setLanguage(settings.language);
    await _prefs.setUseHttps(settings.useHttps);
    await _prefs.setServerPort(settings.serverPort);
  }

  @override
  Future<void> updateDeviceName(String name) async {
    await _prefs.setDeviceName(name);
  }

  @override
  Future<void> updateAvatar(String? avatar) async {
    await _prefs.setDeviceAvatar(avatar);
  }

  @override
  Future<void> updateThemeMode(String mode) async {
    await _prefs.setThemeMode(mode);
  }

  @override
  Future<void> updateLanguage(String language) async {
    await _prefs.setLanguage(language);
  }
}
