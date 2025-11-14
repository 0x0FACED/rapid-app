import 'dart:async';
import 'dart:collection';
import 'package:injectable/injectable.dart';
import '../../features/lan/data/models/transfer_progress_model.dart';

@lazySingleton
class TransferManager {
  // Активные передачи: transferId -> TransferProgressModel
  final _activeTransfers = <String, TransferProgressModel>{};

  // Стрим обновлений передач
  final _transfersController =
      StreamController<List<TransferProgressModel>>.broadcast();
  Stream<List<TransferProgressModel>> get transfersStream =>
      _transfersController.stream;

  // Контроллеры для отмены отдельных передач
  final _cancelTokens = <String, RapidCancelToken>{};

  UnmodifiableListView<TransferProgressModel> get activeTransfers =>
      UnmodifiableListView(_activeTransfers.values);

  /// Начать новую передачу
  void startTransfer(TransferProgressModel transfer) {
    _activeTransfers[transfer.transferId] = transfer;
    _notifyUpdate();
  }

  /// Обновить прогресс передачи
  void updateProgress(String transferId, int transferredBytes) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    _activeTransfers[transferId] = transfer.copyWith(
      transferredBytes: transferredBytes,
      status: TransferStatus.active,
    );

    _notifyUpdate();
  }

  /// Завершить передачу успешно
  void completeTransfer(String transferId) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    _activeTransfers[transferId] = transfer.copyWith(
      status: TransferStatus.completed,
      completedAt: DateTime.now(),
      transferredBytes: transfer.totalBytes,
    );

    _notifyUpdate();

    // Удаляем через 5 секунд
    Future.delayed(const Duration(seconds: 5), () {
      _activeTransfers.remove(transferId);
      _notifyUpdate();
    });
  }

  /// Пометить передачу как неудачную
  void failTransfer(String transferId, String errorMessage) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    _activeTransfers[transferId] = transfer.copyWith(
      status: TransferStatus.failed,
      errorMessage: errorMessage,
      completedAt: DateTime.now(),
    );

    _notifyUpdate();
  }

  /// Отменить передачу
  void cancelTransfer(String transferId) {
    final token = _cancelTokens[transferId];
    token?.cancel();

    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    _activeTransfers[transferId] = transfer.copyWith(
      status: TransferStatus.cancelled,
      completedAt: DateTime.now(),
    );

    _notifyUpdate();

    // Удаляем через 2 секунды
    Future.delayed(const Duration(seconds: 2), () {
      _activeTransfers.remove(transferId);
      _cancelTokens.remove(transferId);
      _notifyUpdate();
    });
  }

  /// Зарегистрировать cancel token для передачи
  void registerCancelToken(String transferId, RapidCancelToken token) {
    _cancelTokens[transferId] = token;
  }

  /// Получить передачу по ID
  TransferProgressModel? getTransfer(String transferId) {
    return _activeTransfers[transferId];
  }

  /// Очистить все завершённые/неудачные передачи
  void clearCompleted() {
    _activeTransfers.removeWhere(
      (_, transfer) =>
          transfer.status == TransferStatus.completed ||
          transfer.status == TransferStatus.failed ||
          transfer.status == TransferStatus.cancelled,
    );
    _notifyUpdate();
  }

  void _notifyUpdate() {
    _transfersController.add(activeTransfers.toList());
  }

  void dispose() {
    _transfersController.close();
    _cancelTokens.values.forEach((token) => token.cancel());
    _cancelTokens.clear();
  }
}

/// Token для отмены передачи (простая реализация)
class RapidCancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
