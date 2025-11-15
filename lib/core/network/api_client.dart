import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart' as dio;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:injectable/injectable.dart';
import 'package:rapid/core/network/transfer_manager.dart';
import '../../features/lan/data/models/device_info_model.dart';
import '../../features/lan/data/models/send_request_model.dart';

@lazySingleton
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Игнорируем ошибки сертификата для self-signed certificates
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
  }

  /// GET /api/rapid/v2/info - Получить информацию об устройстве
  Future<DeviceInfoModel> getDeviceInfo(String baseUrl) async {
    try {
      final response = await _dio.get('$baseUrl/api/rapid/v2/info');
      return DeviceInfoModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      print('[API] Get device info error: $e');
      rethrow;
    }
  }

  /// POST /api/rapid/v2/register - Зарегистрировать себя на другом устройстве
  Future<void> register(String baseUrl, DeviceInfoModel deviceInfo) async {
    try {
      await _dio.post(
        '$baseUrl/api/rapid/v2/register',
        data: deviceInfo.toJson(),
      );
    } catch (e) {
      print('[API] Register error: $e');
      rethrow;
    }
  }

  /// POST /api/rapid/v2/send-request - Отправить запрос на передачу файлов
  Future<String> sendRequest(String baseUrl, SendRequestModel request) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/rapid/v2/send-request',
        data: request.toJson(),
      );

      final sessionId = response.data['sessionId'] as String;
      return sessionId;
    } catch (e) {
      print('[API] Send request error: $e');
      rethrow;
    }
  }

  /// POST /api/rapid/v2/send - Подтвердить отправку
  Future<void> confirmSend(String baseUrl, String sessionId) async {
    try {
      await _dio.post(
        '$baseUrl/api/rapid/v2/send',
        data: {'sessionId': sessionId},
      );
    } catch (e) {
      print('[API] Confirm send error: $e');
      rethrow;
    }
  }

  /// POST /api/rapid/v2/cancel - Отменить передачу
  Future<void> cancelTransfer(String baseUrl, String sessionId) async {
    try {
      await _dio.post(
        '$baseUrl/api/rapid/v2/cancel',
        data: {'sessionId': sessionId},
      );
    } catch (e) {
      print('[API] Cancel error: $e');
      rethrow;
    }
  }

  /// POST /api/rapid/v2/upload - Загрузить файл на устройство
  Future<void> uploadFile({
    required String baseUrl,
    required String sessionId,
    required String fileId,
    required String fileName,
    required String filePath,
    required String fromDevice,
    Function(int sent, int total)? onProgress,
    RapidCancelToken? cancelToken,
  }) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();

      // Создаём multipart request
      final formData = FormData.fromMap({
        'sessionId': sessionId,
        'fileId': fileId,
        'fileName': fileName,
        'fromDevice': fromDevice,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      print('[API] Uploading $fileName ($fileSize bytes) to $baseUrl');

      await _dio.post(
        '$baseUrl/api/rapid/v2/upload',
        data: formData,
        onSendProgress: onProgress,
        cancelToken: _convertCancelToken(cancelToken),
      );

      print('[API] Upload completed: $fileName');
    } catch (e) {
      print('[API] Upload error: $e');
      rethrow;
    }
  }

  /// GET /api/rapid/v2/download/<fileId> - Скачать файл с устройства
  Future<String> downloadFile({
    required String baseUrl,
    required String fileId,
    required String fileName,
    Function(int received, int total)? onProgress,
    RapidCancelToken? cancelToken,
  }) async {
    try {
      // Определяем путь для сохранения
      final downloadsDir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final savePath = path.join(downloadsDir.path, 'Rapid', fileName);

      // Создаём директорию
      await Directory(path.dirname(savePath)).create(recursive: true);

      print('[API] Downloading $fileName from $baseUrl');

      await _dio.download(
        '$baseUrl/api/rapid/v2/download/$fileId',
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: _convertCancelToken(cancelToken),
      );

      print('[API] Download completed: $savePath');

      return savePath;
    } catch (e) {
      print('[API] Download error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableFiles(String baseUrl) async {
    try {
      final response = await _dio.get('$baseUrl/api/rapid/v2/files');

      final data = response.data as Map<String, dynamic>;
      final filesList = data['files'] as List;

      return filesList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('[API] Get files error: $e');
      rethrow;
    }
  }

  /// POST /api/rapid/v2/send-text - Отправить текст на устройство
  Future<void> sendText({
    required String baseUrl,
    required String text,
    required String fromDevice,
    required String fromDeviceName,
  }) async {
    try {
      await _dio.post(
        '$baseUrl/api/rapid/v2/send-text',
        data: {
          'text': text,
          'fromDevice': fromDevice,
          'fromDeviceName': fromDeviceName,
        },
      );

      print('[API] Text sent successfully');
    } catch (e) {
      print('[API] Send text error: $e');
      rethrow;
    }
  }

  /// Конвертация нашего CancelToken в Dio CancelToken
  dio.CancelToken? _convertCancelToken(RapidCancelToken? token) {
    if (token == null) return null;

    final dioToken = dio.CancelToken();

    // Периодически проверяем наш токен
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (token.isCancelled) {
        dioToken.cancel();
        timer.cancel();
      }
    });

    return dioToken;
  }
}
