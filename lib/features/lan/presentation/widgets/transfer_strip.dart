import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rapid/core/di/injection.dart';
import 'package:rapid/core/network/transfer_manager.dart';
import 'package:rapid/features/lan/data/models/transfer_progress_model.dart';
import '../widgets/transfer_progress_card.dart';

class TransfersStrip extends StatelessWidget {
  const TransfersStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final transferManager = getIt<TransferManager>();

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse, // ← разрешаем drag мышью
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad, // на всякий случай
        },
      ),
      child: StreamBuilder<List<TransferProgressModel>>(
        stream: transferManager.transfersStream,
        initialData: transferManager.activeTransfers.toList(),
        builder: (context, snapshot) {
          final transfers = snapshot.data ?? const [];

          if (transfers.isEmpty) {
            return const SizedBox.shrink();
          }

          return SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: transfers.length,
              itemBuilder: (context, index) {
                final transfer = transfers[index];
                return SizedBox(
                  width: 280,
                  child: TransferProgressCard(
                    transfer: transfer,
                    onCancel: () {
                      transferManager.cancelTransfer(transfer.transferId);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
