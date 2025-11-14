import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/transfer_progress_model.dart';
import '../bloc/lan_bloc.dart';
import '../bloc/lan_event.dart';

class TransferProgressCard extends StatelessWidget {
  final TransferProgressModel transfer;

  const TransferProgressCard({super.key, required this.transfer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Имя файла и статус
            Row(
              children: [
                Expanded(
                  child: Text(
                    transfer.fileName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusIcon(context),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            if (transfer.status == TransferStatus.active ||
                transfer.status == TransferStatus.pending)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: transfer.progress,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        transfer.progressPercent,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatSpeed(transfer.speed),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            // Сообщение об ошибке
            if (transfer.status == TransferStatus.failed &&
                transfer.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  transfer.errorMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.red),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Кнопка отмены (только для активных)
            if (transfer.status == TransferStatus.active ||
                transfer.status == TransferStatus.pending)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      context.read<LanBloc>().add(
                        LanCancelTransfer(transfer.transferId),
                      );
                    },
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    IconData icon;
    Color color;

    switch (transfer.status) {
      case TransferStatus.pending:
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case TransferStatus.active:
        icon = Icons.cloud_upload;
        color = Theme.of(context).colorScheme.primary;
        break;
      case TransferStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case TransferStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
      case TransferStatus.cancelled:
        icon = Icons.cancel;
        color = Colors.grey;
        break;
    }

    return Icon(icon, color: color, size: 24);
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond == 0) return '';

    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }
}
