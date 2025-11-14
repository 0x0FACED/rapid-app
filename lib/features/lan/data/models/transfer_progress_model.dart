import 'package:equatable/equatable.dart';

enum TransferStatus {
  pending, // Ожидание подтверждения
  active, // Идёт передача
  completed, // Завершена
  failed, // Ошибка
  cancelled, // Отменена
}

/// Модель прогресса передачи файла
class TransferProgressModel extends Equatable {
  final String transferId;
  final String fileId;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final TransferStatus status;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const TransferProgressModel({
    required this.transferId,
    required this.fileId,
    required this.fileName,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.status = TransferStatus.pending,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  /// Процент выполнения (0.0 - 1.0)
  double get progress {
    if (totalBytes == 0) return 0.0;
    return transferredBytes / totalBytes;
  }

  /// Процент в виде строки
  String get progressPercent => '${(progress * 100).toStringAsFixed(0)}%';

  /// Скорость передачи (bytes/sec)
  double get speed {
    if (status != TransferStatus.active) return 0.0;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    if (elapsed == 0) return 0.0;
    return transferredBytes / elapsed;
  }

  /// Оставшееся время
  Duration? get estimatedTimeRemaining {
    if (status != TransferStatus.active || speed == 0) return null;
    final remaining = totalBytes - transferredBytes;
    return Duration(seconds: (remaining / speed).round());
  }

  TransferProgressModel copyWith({
    String? transferId,
    String? fileId,
    String? fileName,
    int? totalBytes,
    int? transferredBytes,
    TransferStatus? status,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return TransferProgressModel(
      transferId: transferId ?? this.transferId,
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
    transferId,
    fileId,
    fileName,
    totalBytes,
    transferredBytes,
    status,
    errorMessage,
    startedAt,
    completedAt,
  ];
}
