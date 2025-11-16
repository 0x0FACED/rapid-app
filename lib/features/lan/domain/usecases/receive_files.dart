import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/transfer_manager.dart';
import '../../../../core/network/certificate_manager.dart';
import '../../data/models/transfer_progress_model.dart';
import '../entities/device.dart';
import '../entities/shared_file.dart';

@injectable
class ReceiveFilesUseCase {
  final ApiClient _apiClient;
  final TransferManager _transferManager;
  final CertificateManager _certificateManager;

  ReceiveFilesUseCase(
    this._apiClient,
    this._transferManager,
    this._certificateManager,
  );

  // НОВОЕ: Возвращаем список путей к скачанным файлам
  Future<List<String>> execute({
    required Device sourceDevice,
    required List<SharedFile> files,
  }) async {
    final downloadedPaths = <String>[];

    try {
      final fingerprint = await _certificateManager.getFingerprint();
      print('[ReceiveFiles] Our fingerprint: $fingerprint');

      for (final file in files) {
        final transferId = const Uuid().v4();
        final cancelToken = RapidCancelToken();

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
          final savedPath = await _apiClient.downloadFile(
            baseUrl: sourceDevice.baseUrl,
            fileId: file.id,
            fileName: file.name,
            cancelToken: cancelToken,
            onProgress: (received, total) {
              _transferManager.updateProgress(transferId, received);
            },
          );

          _transferManager.completeTransfer(transferId);
          downloadedPaths.add(savedPath); // НОВОЕ: Сохраняем путь
          print('[ReceiveFiles] ✓ File received: $savedPath');
        } catch (e) {
          if (cancelToken.isCancelled) {
            print('[ReceiveFiles] Transfer cancelled: ${file.name}');
          } else {
            _transferManager.failTransfer(transferId, e.toString());
            print('[ReceiveFiles] ✗ Transfer failed: ${file.name} - $e');
          }
        }
      }
    } catch (e) {
      print('[ReceiveFiles] ✗ Error: $e');
      rethrow;
    }

    return downloadedPaths; // НОВОЕ: Возвращаем пути
  }
}
