import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/transfer_manager.dart';
import '../../data/models/transfer_progress_model.dart';
import '../entities/device.dart';
import '../entities/shared_file.dart';

@injectable
class ReceiveFilesUseCase {
  final ApiClient _apiClient;
  final TransferManager _transferManager;

  ReceiveFilesUseCase(this._apiClient, this._transferManager);

  /// Скачать файлы с устройства
  Future<void> execute({
    required Device sourceDevice,
    required List<SharedFile> files,
  }) async {
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
        // Скачиваем файл
        final savedPath = await _apiClient.downloadFile(
          baseUrl: sourceDevice.baseUrl,
          fileId: file.id,
          fileName: file.name,
          cancelToken: cancelToken,
          onProgress: (received, total) {
            _transferManager.updateProgress(transferId, received);
          },
        );

        // Завершаем передачу
        _transferManager.completeTransfer(transferId);

        print('[ReceiveFiles] File downloaded: $savedPath');
      } catch (e) {
        if (cancelToken.isCancelled) {
          print('[ReceiveFiles] Transfer cancelled: ${file.name}');
        } else {
          _transferManager.failTransfer(transferId, e.toString());
          print('[ReceiveFiles] Transfer failed: ${file.name} - $e');
        }
      }
    }
  }
}
