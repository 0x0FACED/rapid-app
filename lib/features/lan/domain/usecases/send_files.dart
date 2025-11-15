import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:rapid/core/network/certificate_manager.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/transfer_manager.dart';
import '../../../../core/storage/shared_prefs_service.dart';
import '../../data/models/device_info_model.dart';
import '../../data/models/file_info_model.dart';
import '../../data/models/send_request_model.dart';
import '../../data/models/transfer_progress_model.dart';
import '../entities/device.dart';
import '../entities/shared_file.dart';

@injectable
class SendFilesUseCase {
  final ApiClient _apiClient;
  final TransferManager _transferManager;
  final SharedPrefsService _prefs;
  final CertificateManager _certificateManager;

  SendFilesUseCase(
    this._apiClient,
    this._transferManager,
    this._prefs,
    this._certificateManager,
  );

  /// Отправить файлы на устройство
  Future<void> execute({
    required Device targetDevice,
    required List<SharedFile> files,
  }) async {
    final fingerprint = await _certificateManager.getFingerprint();

    try {
      // 1. Создаём информацию о нашем устройстве
      final ourDeviceInfo = DeviceInfoModel(
        alias: _prefs.getDeviceName(),
        version: '2.0',
        deviceModel: _getDeviceModel(),
        deviceType: _getDeviceType(),
        fingerprint: fingerprint,
        port: _prefs.getServerPort(),
        protocol: _prefs.getUseHttps() ? 'https' : 'http',
      );

      // 2. Создаём карту файлов для отправки
      final filesMap = <String, FileInfoModel>{};
      for (final file in files) {
        filesMap[file.id] = FileInfoModel(
          id: file.id,
          fileName: file.name,
          size: file.size,
          fileType: file.mimeType,
        );
      }

      // 3. Отправляем send-request
      final sendRequest = SendRequestModel(
        info: ourDeviceInfo,
        files: filesMap,
      );

      final sessionId = await _apiClient.sendRequest(
        targetDevice.baseUrl,
        sendRequest,
      );

      print('[SendFiles] Session created: $sessionId');

      // 4. Подтверждаем отправку
      await _apiClient.confirmSend(targetDevice.baseUrl, sessionId);

      // 5. Отправляем каждый файл
      for (final file in files) {
        final transferId = const Uuid().v4();
        final cancelToken = RapidCancelToken();

        // Регистрируем передачу
        _transferManager.startTransfer(
          TransferProgressModel(
            transferId: transferId,
            fileId: file.id,
            fileName: file.name,
            totalBytes: file.size,
            status: TransferStatus.pending,
            startedAt: DateTime.now(),
          ),
        );

        _transferManager.registerCancelToken(transferId, cancelToken);

        try {
          // Загружаем файл
          await _apiClient.uploadFile(
            baseUrl: targetDevice.baseUrl,
            sessionId: sessionId,
            fileId: file.id,
            fileName: file.name,
            filePath: file.path,
            fromDevice: _prefs.getDeviceName(),
            cancelToken: cancelToken,
            onProgress: (sent, total) {
              _transferManager.updateProgress(transferId, sent);
            },
          );

          // Завершаем передачу
          _transferManager.completeTransfer(transferId);

          print('[SendFiles] File sent: ${file.name}');
        } catch (e) {
          if (cancelToken.isCancelled) {
            print('[SendFiles] Transfer cancelled: ${file.name}');
          } else {
            _transferManager.failTransfer(transferId, e.toString());
            print('[SendFiles] Transfer failed: ${file.name} - $e');
          }
        }
      }
    } catch (e) {
      print('[SendFiles] Error: $e');
      rethrow;
    }
  }

  // НОВОЕ: Определение модели устройства
  String _getDeviceModel() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'MacOS';
    return 'Unknown';
  }

  // НОВОЕ: Определение типа устройства
  String _getDeviceType() {
    return (Platform.isAndroid || Platform.isIOS) ? 'mobile' : 'desktop';
  }
}
