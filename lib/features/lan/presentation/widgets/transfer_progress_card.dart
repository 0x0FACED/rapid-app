import 'package:flutter/material.dart';
import 'package:rapid/features/lan/data/models/transfer_progress_model.dart';

class TransferProgressCard extends StatelessWidget {
  final TransferProgressModel transfer;
  final VoidCallback? onCancel;

  const TransferProgressCard({
    super.key,
    required this.transfer,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final speed = transfer.speed;
    final remaining = transfer.estimatedTimeRemaining;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Статус
                _buildStatusIcon(transfer.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    transfer.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (transfer.status == TransferStatus.active ||
                    transfer.status == TransferStatus.pending)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onCancel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: transfer.progress, minHeight: 6),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${(transfer.progress * 100).toStringAsFixed(0)}%'),
                const SizedBox(width: 12),
                if (transfer.status == TransferStatus.active)
                  Text(
                    '${_formatSpeed(speed)} • ${_formatDuration(remaining)}',
                  ),
                if (transfer.status != TransferStatus.active)
                  Text(_getStatusText(transfer.status)),
              ],
            ),
            if (transfer.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                transfer.errorMessage!,
                style: const TextStyle(color: Colors.red),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(TransferStatus status) {
    switch (status) {
      case TransferStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange, size: 20);
      case TransferStatus.active:
        return const Icon(Icons.downloading, color: Colors.blue, size: 20);
      case TransferStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case TransferStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case TransferStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.grey, size: 20);
    }
  }

  String _getStatusText(TransferStatus status) {
    switch (status) {
      case TransferStatus.pending:
        return 'Pending';
      case TransferStatus.active:
        return 'Active';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    }
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }
}
