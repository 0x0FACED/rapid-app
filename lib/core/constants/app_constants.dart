class AppConstants {
  // Network
  static const int defaultPort = 53317;
  static const String multicastAddress = '224.0.0.167';
  static const String serviceName = '_rapid._tcp';
  static const String protocol = 'https'; // http для разработки

  // File Transfer
  static const int maxFileSize = 10 * 1024 * 1024 * 1024; // 10 GB
  static const int chunkSize = 1024 * 1024; // 1 MB chunks

  // mDNS
  static const Duration discoveryInterval = Duration(seconds: 5);
  static const Duration deviceTimeout = Duration(seconds: 30);

  // App
  static const String appName = 'Rapid';
  static const String appVersion = '0.1.0';
}
