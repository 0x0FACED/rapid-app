import 'package:injectable/injectable.dart';
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

import '../../../../core/network/transfer_manager.dart' show RapidCancelToken;

@injectable
class SendFilesUseCase {
  final ApiClient _apiClient;
  final TransferManager _transferManager;
  final SharedPrefsService _prefs;

  SendFilesUseCase(this._apiClient, this._transferManager, this._prefs);

  /// Отправить файлы на устройство
  Future<void> execute({
    required Device targetDevice,
    required List<SharedFile> files,
  }) async {
    try {
      // 1. Создаём информацию о нашем устройстве
      final ourDeviceInfo = DeviceInfoModel(
        alias: _prefs.getDeviceName(),
        version: '2.0',
        deviceModel: 'Mobile',
        deviceType: 'mobile',
        fingerprint: 'temp', // TODO: получить реальный
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
}
