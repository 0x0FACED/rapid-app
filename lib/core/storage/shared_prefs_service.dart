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
  static const String _keyFavoriteDevices = 'favorite_devices';

  SharedPreferences? _prefs;

  /// Инициализация SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Генерируем deviceId при первом запуске
    if (!_prefs!.containsKey(_keyDeviceId)) {
      final newId = const Uuid().v4();
      await setDeviceId(newId);
      print('[Storage] Generated new device ID: $newId');
    } else {
      print('[Storage] Loaded existing device ID: ${getDeviceId()}');
    }

    // Дефолтное имя устройства
    if (!_prefs!.containsKey(_keyDeviceName)) {
      await setDeviceName('My Rapid Device');
    }

    print('[Storage] Initialized');
  }

  // Device ID
  String getDeviceId() {
    final id = _prefs?.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      // Fallback: генерируем новый ID если что-то пошло не так
      final newId = const Uuid().v4();
      setDeviceId(newId);
      return newId;
    }
    return id;
  }

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

  // ============================================================
  // НОВОЕ: Generic методы для работы с произвольными ключами
  // ============================================================

  /// Получить строку по ключу
  String? getString(String key) {
    return _prefs?.getString(key);
  }

  /// Сохранить строку по ключу
  Future<bool> setString(String key, String value) async {
    if (_prefs == null) {
      print('[Storage] ⚠️ SharedPreferences not initialized');
      return false;
    }
    return await _prefs!.setString(key, value);
  }

  /// Получить int по ключу
  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  /// Сохранить int по ключу
  Future<bool> setInt(String key, int value) async {
    if (_prefs == null) return false;
    return await _prefs!.setInt(key, value);
  }

  /// Получить bool по ключу
  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  /// Сохранить bool по ключу
  Future<bool> setBool(String key, bool value) async {
    if (_prefs == null) return false;
    return await _prefs!.setBool(key, value);
  }

  /// Получить double по ключу
  double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  /// Сохранить double по ключу
  Future<bool> setDouble(String key, double value) async {
    if (_prefs == null) return false;
    return await _prefs!.setDouble(key, value);
  }

  /// Получить список строк по ключу
  List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  /// Сохранить список строк по ключу
  Future<bool> setStringList(String key, List<String> value) async {
    if (_prefs == null) return false;
    return await _prefs!.setStringList(key, value);
  }

  /// Удалить значение по ключу
  Future<bool> remove(String key) async {
    if (_prefs == null) return false;
    return await _prefs!.remove(key);
  }

  /// Проверить наличие ключа
  bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  /// Получить все ключи
  Set<String> getKeys() {
    return _prefs?.getKeys() ?? {};
  }

  /// Очистить все данные
  Future<bool> clear() async {
    if (_prefs == null) return false;
    return await _prefs!.clear();
  }
}
