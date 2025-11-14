// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Rapid';

  @override
  String get lan => 'LAN';

  @override
  String get web => 'WEB';

  @override
  String get settings => 'Settings';

  @override
  String get share => 'Share';

  @override
  String get receive => 'Receive';

  @override
  String get addFiles => 'Add Files';

  @override
  String get noFilesShared => 'No files shared yet';

  @override
  String get tapAddFiles => 'Tap \'Add Files\' to start sharing';

  @override
  String get noDevicesFound => 'No devices found';

  @override
  String get searchingDevices => 'Searching for devices in network...';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get sharedFiles => 'Shared files';

  @override
  String get noSharedFiles => 'No shared files';

  @override
  String get typeTextOrLink => 'Type text or paste link...';

  @override
  String get sendTextTo => 'Send text to:';

  @override
  String textSentTo(Object deviceName) {
    return 'Text sent to $deviceName';
  }

  @override
  String get noDevicesAvailable => 'No devices available';

  @override
  String get cancel => 'Cancel';

  @override
  String get download => 'Download';

  @override
  String get uploading => 'Uploading';

  @override
  String get downloading => 'Downloading';

  @override
  String get completed => 'Completed';

  @override
  String get failed => 'Failed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get profile => 'Profile';

  @override
  String get deviceName => 'Device Name';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get network => 'Network';

  @override
  String get useHttps => 'Use HTTPS';

  @override
  String get serverPort => 'Server Port';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get changeAvatar => 'Change Avatar';

  @override
  String get enterDeviceName => 'Enter device name';

  @override
  String get save => 'Save';
}
