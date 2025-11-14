import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

@lazySingleton
class SharedPrefsService {
  static const String _keyDeviceId = 'device_id';
  static const String _keyDeviceName = 'device_name';
  static const String _keyDeviceAvatar = 'device_avatar';
  static const String _keyThemeMode =
      'theme_mode'; // 'light' | 'dark' | 'system'
  static const String _keyLanguage = 'language'; // 'en' | 'ru'
  static const String _keyUseHttps = 'use_https';
  static const String _keyServerPort = 'server_port';

  SharedPreferences? _prefs;

  /// Инициализация SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Генерируем deviceId при первом запуске
    if (!_prefs!.containsKey(_keyDeviceId)) {
      await setDeviceId(const Uuid().v4());
    }

    // Дефолтное имя устройства
    if (!_prefs!.containsKey(_keyDeviceName)) {
      await setDeviceName('My Rapid Device');
    }

    print('[Storage] Initialized');
  }

  // Device ID
  String getDeviceId() => _prefs?.getString(_keyDeviceId) ?? const Uuid().v4();
  Future<void> setDeviceId(String id) async =>
      await _prefs?.setString(_keyDeviceId, id);

  // Device Name
  String getDeviceName() =>
      _prefs?.getString(_keyDeviceName) ?? 'Unknown Device';
  Future<void> setDeviceName(String name) async =>
      await _prefs?.setString(_keyDeviceName, name);

  // Avatar (base64 или URL)
  String? getDeviceAvatar() => _prefs?.getString(_keyDeviceAvatar);
  Future<void> setDeviceAvatar(String? avatar) async {
    if (avatar != null) {
      await _prefs?.setString(_keyDeviceAvatar, avatar);
    } else {
      await _prefs?.remove(_keyDeviceAvatar);
    }
  }

  // Theme Mode
  String getThemeMode() => _prefs?.getString(_keyThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) async =>
      await _prefs?.setString(_keyThemeMode, mode);

  // Language
  String getLanguage() => _prefs?.getString(_keyLanguage) ?? 'ru';
  Future<void> setLanguage(String lang) async =>
      await _prefs?.setString(_keyLanguage, lang);

  // HTTPS toggle
  bool getUseHttps() => _prefs?.getBool(_keyUseHttps) ?? true;
  Future<void> setUseHttps(bool value) async =>
      await _prefs?.setBool(_keyUseHttps, value);

  // Server Port
  int getServerPort() => _prefs?.getInt(_keyServerPort) ?? 53317;
  Future<void> setServerPort(int port) async =>
      await _prefs?.setInt(_keyServerPort, port);
}
