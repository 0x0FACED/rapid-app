// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Rapid';

  @override
  String get lan => 'Локальная сеть';

  @override
  String get web => 'Интернет';

  @override
  String get settings => 'Настройки';

  @override
  String get share => 'Поделиться';

  @override
  String get receive => 'Получить';

  @override
  String get addFiles => 'Добавить файлы';

  @override
  String get noFilesShared => 'Нет расшаренных файлов';

  @override
  String get tapAddFiles => 'Нажмите \'Добавить файлы\' для начала';

  @override
  String get noDevicesFound => 'Устройства не найдены';

  @override
  String get searchingDevices => 'Поиск устройств в сети...';

  @override
  String get online => 'В сети';

  @override
  String get offline => 'Не в сети';

  @override
  String get sharedFiles => 'Общие файлы';

  @override
  String get noSharedFiles => 'Нет общих файлов';

  @override
  String get typeTextOrLink => 'Введите текст или вставьте ссылку...';

  @override
  String get sendTextTo => 'Отправить текст:';

  @override
  String textSentTo(Object deviceName) {
    return 'Текст отправлен $deviceName';
  }

  @override
  String get noDevicesAvailable => 'Нет доступных устройств';

  @override
  String get cancel => 'Отменить';

  @override
  String get download => 'Скачать';

  @override
  String get uploading => 'Загрузка';

  @override
  String get downloading => 'Скачивание';

  @override
  String get completed => 'Завершено';

  @override
  String get failed => 'Ошибка';

  @override
  String get cancelled => 'Отменено';

  @override
  String get profile => 'Профиль';

  @override
  String get deviceName => 'Имя устройства';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get language => 'Язык';

  @override
  String get network => 'Сеть';

  @override
  String get useHttps => 'Использовать HTTPS';

  @override
  String get serverPort => 'Порт сервера';

  @override
  String get about => 'О приложении';

  @override
  String get version => 'Версия';

  @override
  String get changeAvatar => 'Изменить аватар';

  @override
  String get enterDeviceName => 'Введите имя устройства';

  @override
  String get save => 'Сохранить';
}
