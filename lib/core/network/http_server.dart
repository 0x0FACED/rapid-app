import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:mime/mime.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import 'certificate_manager.dart';
import '../../features/lan/data/models/device_info_model.dart';
import '../../features/lan/data/models/send_request_model.dart';

final _log = Logger('HTTP Server');

/// Модель входящего файла
class IncomingFileModel {
  final String sessionId;
  final String fileId;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String fromDevice;

  IncomingFileModel({
    required this.sessionId,
    required this.fileId,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.fromDevice,
  });
}

/// Модель входящего текста
class IncomingTextModel {
  final String text;
  final String fromDevice;
  final String fromDeviceName;
  final DateTime receivedAt;

  IncomingTextModel({
    required this.text,
    required this.fromDevice,
    required this.fromDeviceName,
    required this.receivedAt,
  });
}

/// Наш файл скачивают
class OutgoingDownloadModel {
  final String fileId;
  final String fileName;
  final int fileSize;
  final String? remoteAddress;

  OutgoingDownloadModel({
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    this.remoteAddress,
  });
}

@lazySingleton
class HttpServerService {
  final CertificateManager _certificateManager;

  HttpServer? _server;
  bool _isRunning = false;

  // Информация о текущем устройстве
  late String _deviceId;
  late String _deviceName;
  late String _fingerprint;
  String? _avatarBase64;

  // Callback'и для обработки запросов
  final _sendRequestController = StreamController<SendRequestModel>.broadcast();
  Stream<SendRequestModel> get sendRequests => _sendRequestController.stream;

  final _fileDownloadsController =
      StreamController<OutgoingDownloadModel>.broadcast();
  Stream<OutgoingDownloadModel> get outgoingDownloads =>
      _fileDownloadsController.stream;

  HttpServerService(this._certificateManager);

  bool get isRunning => _isRunning;
  int? get port => _server?.port;

  final Map<String, String> _availableFiles = {};

  final _incomingFilesController =
      StreamController<IncomingFileModel>.broadcast();
  Stream<IncomingFileModel> get incomingFiles =>
      _incomingFilesController.stream;

  final _incomingTextController =
      StreamController<IncomingTextModel>.broadcast();
  Stream<IncomingTextModel> get incomingTexts => _incomingTextController.stream;

  /// Запуск HTTP/HTTPS сервера
  Future<void> start({
    required String deviceId,
    required String deviceName,
    String? avatar,
    int? port,
    bool useHttps = true,
  }) async {
    if (_isRunning) return;

    _deviceId = deviceId;
    _deviceName = deviceName;
    if (avatar != null && avatar.isNotEmpty) {
      try {
        final file = File(avatar);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          _avatarBase64 = base64Encode(bytes);
          _log.fine('Avatar ok: ${bytes.length} bytes');
        }
      } catch (e) {
        _avatarBase64 = null;
      }
    }

    // Инициализируем сертификаты если нужен HTTPS
    if (useHttps) {
      await _certificateManager.initialize();
      _fingerprint = await _certificateManager.getFingerprint();
    } else {
      _fingerprint = const Uuid().v4(); // Для HTTP просто UUID
    }

    // Создаем роутер
    final router = _buildRouter();

    // Middleware для логирования и CORS
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);

    // Запускаем сервер
    try {
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        port ?? AppConstants.defaultPort,
        securityContext: useHttps ? _certificateManager.securityContext : null,
      );

      _isRunning = true;

      _log.info(
        '${useHttps ? 'HTTPS' : 'HTTP'} server started on port ${_server!.port}',
      );
    } catch (e) {
      _log.severe('Failed to start', e);
      rethrow;
    }
  }

  /// Остановка сервера
  Future<void> stop() async {
    if (!_isRunning) return;

    await _server?.close(force: true);
    _server = null;
    _isRunning = false;

    _log.info('Stopped');
  }

  /// Построение роутера с endpoint'ами
  Router _buildRouter() {
    final router = Router();

    // API v2 endpoints (совместимы с LocalSend protocol v2)

    // GET /api/rapid/v2/info - Информация о устройстве
    router.get('/api/rapid/v2/info', _handleGetInfo);

    // POST /api/rapid/v2/register - Регистрация устройства
    router.post('/api/rapid/v2/register', _handleRegister);

    // POST /api/rapid/v2/send-request - Запрос на отправку файлов
    router.post('/api/rapid/v2/send-request', _handleSendRequest);

    // POST /api/rapid/v2/send - Подтверждение получения
    router.post('/api/rapid/v2/send', _handleSend);

    // POST /api/rapid/v2/cancel - Отмена передачи
    router.post('/api/rapid/v2/cancel', _handleCancel);

    // GET /api/rapid/v2/download/<fileId> - Скачивание файла
    router.get('/api/rapid/v2/download/<fileId>', _handleDownload);

    router.get('/api/rapid/v2/files', _handleGetFiles);

    // НОВОЕ: Upload endpoint (для приёма файлов)
    router.post('/api/rapid/v2/upload', _handleUpload);

    // НОВОЕ: Download endpoint (для отдачи файлов)
    router.get('/api/rapid/v2/download/<fileId>', _handleDownload);

    router.post('/api/rapid/v2/send-text', _handleSendText);

    // Health check
    router.get('/health', (Request request) {
      return Response.ok('OK');
    });

    return router;
  }

  /// GET /api/rapid/v2/info - Отдаем информацию о нашем устройстве
  Response _handleGetInfo(Request request) {
    final info = DeviceInfoModel(
      alias: _deviceName,
      version: '2.0',
      deviceModel: Platform.isAndroid
          ? 'Android'
          : Platform.isIOS
          ? 'iPhone'
          : Platform.isLinux
          ? 'Linux'
          : 'Desktop',
      deviceType: Platform.isAndroid || Platform.isIOS ? 'mobile' : 'desktop',
      fingerprint: _fingerprint,
      port: _server!.port,
      protocol: _certificateManager.securityContext != null ? 'https' : 'http',
      download: true,
      avatar: _avatarBase64, // НОВОЕ: отдаём аватарку
    );

    return Response.ok(
      jsonEncode(info.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// POST /api/rapid/v2/register - Регистрация другого устройства
  Future<Response> _handleRegister(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final deviceInfo = DeviceInfoModel.fromJson(json);

      _log.info('Device registered: ${deviceInfo.alias}');

      // Здесь можно сохранить информацию об устройстве
      // Пока просто отвечаем OK

      return Response.ok(
        jsonEncode({'status': 'registered'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _log.severe('Register error', e);
      return Response.badRequest(body: 'Invalid request body');
    }
  }

  /// POST /api/rapid/v2/send-request - Получение запроса на отправку файлов
  Future<Response> _handleSendRequest(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final sendRequest = SendRequestModel.fromJson(json);

      _log.info('Send request from: ${sendRequest.info.alias}');
      _log.info('Files count: ${sendRequest.files.length}');

      // Отправляем запрос в стрим для обработки UI
      _sendRequestController.add(sendRequest);

      // Отвечаем с нашим session ID
      final sessionId = const Uuid().v4();

      return Response.ok(
        jsonEncode({'sessionId': sessionId}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _log.severe('Send request error', e);
      return Response.badRequest(body: 'Invalid send request');
    }
  }

  /// POST /api/rapid/v2/send - Подтверждение отправки
  Future<Response> _handleSend(Request request) async {
    // Здесь обрабатываем начало передачи файлов
    _log.info('Send confirmed');

    return Response.ok(
      jsonEncode({'status': 'accepted'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// POST /api/rapid/v2/cancel - Отмена передачи
  Future<Response> _handleCancel(Request request) async {
    _log.info('Transfer cancelled');

    return Response.ok(
      jsonEncode({'status': 'cancelled'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// POST /api/rapid/v2/upload - Приём файла
  Future<Response> _handleUpload(Request request) async {
    try {
      //if (!request.isMultipart) {
      //  return Response.badRequest(body: 'Expected multipart request');
      //}

      final multipart = request.multipart();

      if (multipart == null) {
        return Response.badRequest(body: 'Expected multipart request');
      }

      String? sessionId;
      String? fileId;
      String? fileName;
      String? fromDevice;
      int fileSize = 0;
      String? savedPath;

      await for (final part in multipart.parts) {
        if (part.headers['content-disposition']?.contains('name="sessionId"') ??
            false) {
          sessionId = await part.readString();
        } else if (part.headers['content-disposition']?.contains(
              'name="fileId"',
            ) ??
            false) {
          fileId = await part.readString();
        } else if (part.headers['content-disposition']?.contains(
              'name="fileName"',
            ) ??
            false) {
          fileName = await part.readString();
        } else if (part.headers['content-disposition']?.contains(
              'name="fromDevice"',
            ) ??
            false) {
          fromDevice = await part.readString();
        } else if (part.headers['content-disposition']?.contains(
              'name="file"',
            ) ??
            false) {
          // Это сам файл
          final downloadsDir =
              await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final safeName = fileName ?? 'file_$timestamp';
          final filePath = path.join(downloadsDir.path, 'Rapid', safeName);

          // Создаём директорию если не существует
          await Directory(path.dirname(filePath)).create(recursive: true);

          // Сохраняем файл
          final file = File(filePath);
          final sink = file.openWrite();

          await for (final chunk in part) {
            sink.add(chunk);
            fileSize += chunk.length;
          }

          await sink.close();
          savedPath = filePath;

          _log.info('File saved: $filePath ($fileSize bytes)');
        }
      }

      if (savedPath == null || fileId == null || sessionId == null) {
        return Response.badRequest(body: 'Missing required fields');
      }

      // Отправляем в стрим для обработки UI
      _incomingFilesController.add(
        IncomingFileModel(
          sessionId: sessionId,
          fileId: fileId,
          fileName: fileName ?? 'unknown',
          filePath: savedPath,
          fileSize: fileSize,
          fromDevice: fromDevice ?? 'Unknown Device',
        ),
      );

      return Response.ok(
        jsonEncode({'status': 'received', 'fileId': fileId, 'size': fileSize}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _log.severe('Upload error', e);
      return Response.internalServerError(body: 'Upload failed: $e');
    }
  }

  /// GET /api/rapid/v2/files - Отдать список доступных файлов
  Response _handleGetFiles(Request request) {
    try {
      final filesList = _availableFiles.entries.map((entry) {
        final filePath = entry.value;
        final file = File(filePath);

        return {
          'id': entry.key,
          'fileName': path.basename(filePath),
          'size': file.existsSync() ? file.lengthSync() : 0,
          'fileType': lookupMimeType(filePath) ?? 'application/octet-stream',
        };
      }).toList();

      return Response.ok(
        jsonEncode({'files': filesList}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _log.info('Get files error', e);
      return Response.internalServerError(body: 'Failed to get files');
    }
  }

  /// GET /api/rapid/v2/download/<fileId> - Отдача файла
  Future<Response> _handleDownload(Request request, String fileId) async {
    try {
      // Проверяем, есть ли такой файл
      if (!_availableFiles.containsKey(fileId)) {
        return Response.notFound('File not found');
      }

      final filePath = _availableFiles[fileId]!;
      final file = File(filePath);

      if (!await file.exists()) {
        return Response.notFound('File no longer exists');
      }

      // Получаем размер файла
      final fileSize = await file.length();
      final fileName = path.basename(filePath);

      String? remoteAddress;
      final connectionInfo =
          request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      remoteAddress = connectionInfo?.remoteAddress.address;

      _log.info('Sending file: $fileName ($fileSize bytes)');

      _fileDownloadsController.add(
        OutgoingDownloadModel(
          fileId: fileId,
          fileName: fileName,
          fileSize: fileSize,
          remoteAddress: remoteAddress,
        ),
      );

      // Отдаём файл как stream
      return Response.ok(
        file.openRead(),
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': 'attachment; filename="$fileName"',
          'Content-Length': fileSize.toString(),
        },
      );
    } catch (e) {
      _log.severe('Download error', e);
      return Response.internalServerError(body: 'Download failed: $e');
    }
  }

  /// POST /api/rapid/v2/send-text - Приём текстового сообщения
  Future<Response> _handleSendText(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final text = json['text'] as String;
      final fromDevice = json['fromDevice'] as String;
      final fromDeviceName = json['fromDeviceName'] as String?;

      _log.info('Received text from $fromDeviceName: $text');

      // Отправляем в стрим
      _incomingTextController.add(
        IncomingTextModel(
          text: text,
          fromDevice: fromDevice,
          fromDeviceName: fromDeviceName ?? 'Unknown Device',
          receivedAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({'status': 'received'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      _log.severe('Send text error', e);
      return Response.badRequest(body: 'Invalid request');
    }
  }

  /// Зарегистрировать файл для скачивания
  void registerFile(String fileId, String filePath) {
    _availableFiles[fileId] = filePath;
    _log.info('Registered file for download: $fileId -> $filePath');
  }

  /// Удалить файл из доступных
  void unregisterFile(String fileId) {
    _availableFiles.remove(fileId);
    _log.info('Unregistered file: $fileId');
  }

  /// Получить список доступных файлов
  Map<String, String> get availableFiles => Map.unmodifiable(_availableFiles);

  /// CORS middleware для кросс-доменных запросов
  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        final response = await handler(request);

        return response.change(headers: _corsHeaders);
      };
    };
  }

  final Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization',
  };

  void dispose() {
    stop();
    _sendRequestController.close();
    _fileDownloadsController.close();
    _incomingFilesController.close();
    _incomingTextController.close();
  }
}
