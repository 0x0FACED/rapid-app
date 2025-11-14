import '../entities/user_settings.dart';

abstract class SettingsRepository {
  Future<UserSettings> getSettings();
  Future<void> updateSettings(UserSettings settings);
  Future<void> updateDeviceName(String name);
  Future<void> updateAvatar(String? avatar);
  Future<void> updateThemeMode(String mode);
  Future<void> updateLanguage(String language);
}
