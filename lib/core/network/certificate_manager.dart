import 'dart:io';
import 'package:basic_utils/basic_utils.dart';
import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

final _log = Logger('Certificate Manager');

@lazySingleton
class CertificateManager {
  String? _certificatePath;
  String? _privateKeyPath;
  SecurityContext? _securityContext;

  SecurityContext? get securityContext => _securityContext;

  /// Генерация или загрузка существующего сертификата
  Future<void> initialize() async {
    final appDir = await getApplicationSupportDirectory();
    final certDir = Directory(path.join(appDir.path, 'certificates'));

    if (!await certDir.exists()) {
      await certDir.create(recursive: true);
    }

    _certificatePath = path.join(certDir.path, 'server_cert.pem');
    _privateKeyPath = path.join(certDir.path, 'server_key.pem');

    // Проверяем, существует ли сертификат
    final certFile = File(_certificatePath!);
    final keyFile = File(_privateKeyPath!);

    if (!await certFile.exists() || !await keyFile.exists()) {
      _log.info('Generating new self-signed certificate...');
      await _generateCertificate();
    } else {
      _log.info('Using existing certificate');
    }

    // Создаем SecurityContext для HTTPS сервера
    _securityContext = SecurityContext()
      ..useCertificateChain(_certificatePath!)
      ..usePrivateKey(_privateKeyPath!);

    _log.info('Initialized');
  }

  /// Генерация нового self-signed сертификата
  Future<void> _generateCertificate() async {
    try {
      // Генерируем RSA ключи
      final keyPair = CryptoUtils.generateRSAKeyPair();
      final privateKey = keyPair.privateKey as RSAPrivateKey;
      final publicKey = keyPair.publicKey as RSAPublicKey;

      // Создаем Distinguished Name
      final dn = {
        'CN': 'Rapid Self-Signed',
        'O': 'Rapid',
        'OU': 'Rapid App',
        'C': 'RU',
      };

      // Генерируем CSR (Certificate Signing Request)
      final csr = X509Utils.generateRsaCsrPem(dn, privateKey, publicKey);

      // Создаем self-signed сертификат (действителен 10 лет)
      final cert = X509Utils.generateSelfSignedCertificate(
        privateKey,
        csr,
        3650, // 10 лет
      );

      // Сохраняем сертификат и приватный ключ
      await File(_certificatePath!).writeAsString(cert);
      await File(
        _privateKeyPath!,
      ).writeAsString(CryptoUtils.encodeRSAPrivateKeyToPem(privateKey));

      _log.info('Generated and saved successfully');
    } catch (e) {
      _log.severe('Generation failed', e);
      rethrow;
    }
  }

  /// Получить fingerprint сертификата (SHA-256 hash)
  Future<String> getFingerprint() async {
    if (_certificatePath == null) {
      throw Exception('Certificate not initialized');
    }

    final certPem = await File(_certificatePath!).readAsString();
    // final cert = X509Utils.x509CertificateFromPem(certPem);

    // Вычисляем SHA-256 хеш от DER-encoded сертификата
    final certDer = CryptoUtils.getBytesFromPEMString(certPem);
    final hash = CryptoUtils.getHash(certDer);

    return hash;
  }

  /// Регенерация сертификата (если нужно)
  Future<void> regenerate() async {
    // Удаляем старые файлы
    if (_certificatePath != null && _privateKeyPath != null) {
      await File(_certificatePath!).delete();
      await File(_privateKeyPath!).delete();
    }

    // Генерируем новые
    await initialize();
  }
}
