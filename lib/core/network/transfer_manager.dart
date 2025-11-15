import 'dart:async';
import 'dart:collection';
import 'package:injectable/injectable.dart';
import '../../features/lan/data/models/transfer_progress_model.dart';

@lazySingleton
class TransferManager {
  final _activeTransfers = <String, TransferProgressModel>{};
  final _transfersController =
      StreamController<List<TransferProgressModel>>.broadcast();

  final _cancelTokens = <String, RapidCancelToken>{};

  Timer? _updateTimer;

  // Флаг, что данные менялись с момента последней отправки в стрим
  bool _hasPendingChanges = false;

  Stream<List<TransferProgressModel>> get transfersStream =>
      _transfersController.stream;

  UnmodifiableListView<TransferProgressModel> get activeTransfers =>
      UnmodifiableListView(_activeTransfers.values);

  TransferManager() {
    // Периодический тик раз в секунду — только отсюда пушим в стрим
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_hasPendingChanges) {
        _notifyUpdate();
        _hasPendingChanges = false;
      }
    });
  }

  void startTransfer(TransferProgressModel transfer) {
    _activeTransfers[transfer.transferId] = transfer;
    _markChanged();
  }

  void updateProgress(String transferId, int transferredBytes) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    _activeTransfers[transferId] = transfer.copyWith(
      transferredBytes: transferredBytes,
      status: TransferStatus.active,
    );

    // Не пушим сразу, только помечаем изменение
    _markChanged();
  }

  void completeTransfer(String transferId) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    _activeTransfers[transferId] = transfer.copyWith(
      status: TransferStatus.completed,
      completedAt: DateTime.now(),
      transferredBytes: transfer.totalBytes,
    );

    _markChanged();

    // Удаляем через 5 секунд
    Future.delayed(const Duration(seconds: 5), () {
      _activeTransfers.remove(transferId);
      _markChanged();
    });
  }

  void failTransfer(String transferId, String errorMessage) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    _activeTransfers[transferId] = transfer.copyWith(
      status: TransferStatus.failed,
      errorMessage: errorMessage,
      completedAt: DateTime.now(),
    );

    _markChanged();
  }

  void cancelTransfer(String transferId) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) return;

    _activeTransfers[transferId] = transfer.copyWith(
      status: TransferStatus.cancelled,
      completedAt: DateTime.now(),
    );

    _markChanged();

    // Удаляем через 2 секунды
    Future.delayed(const Duration(seconds: 2), () {
      _activeTransfers.remove(transferId);
      _markChanged();
    });
  }

  /// Очистить все завершённые/неудачные передачи
  void clearCompleted() {
    _activeTransfers.removeWhere(
      (_, transfer) =>
          transfer.status == TransferStatus.completed ||
          transfer.status == TransferStatus.failed ||
          transfer.status == TransferStatus.cancelled,
    );
    _markChanged();
  }

  /// Зарегистрировать cancel token для передачи
  void registerCancelToken(String transferId, RapidCancelToken token) {
    _cancelTokens[transferId] = token;
  }

  /// Получить передачу по ID
  TransferProgressModel? getTransfer(String transferId) {
    return _activeTransfers[transferId];
  }

  void _markChanged() {
    _hasPendingChanges = true;
  }

  void _notifyUpdate() {
    _transfersController.add(activeTransfers.toList());
  }

  void dispose() {
    _updateTimer?.cancel();
    _transfersController.close();
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
