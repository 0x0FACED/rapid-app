import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_event.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_state.dart';
import 'package:rapid/features/lan/presentation/widgets/main_content.dart';
import 'package:rapid/features/lan/presentation/widgets/mode_toggle.dart';
import 'package:rapid/features/lan/presentation/widgets/text_share_input.dart';
import 'package:rapid/features/lan/presentation/widgets/transfer_strip.dart';
import 'package:rapid/features/lan/presentation/widgets/user_profile.dart';

class LanLoadedScaffold extends StatelessWidget {
  final LanLoaded state;

  const LanLoadedScaffold({required this.state});

  @override
  Widget build(BuildContext context) {
    final selectedDevice = state.selectedDevice;

    return PopScope(
      canPop: selectedDevice == null,
      onPopInvoked: (didPop) {
        if (!didPop && selectedDevice != null) {
          context.read<LanBloc>().add(const LanSelectDevice(null));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: selectedDevice != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    context.read<LanBloc>().add(const LanSelectDevice(null));
                  },
                )
              : null,
          title: Text(
            selectedDevice != null ? selectedDevice.name : 'Rapid LAN',
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            if (selectedDevice == null) ...[
              const UserProfileSection(),
              const SizedBox(height: 16),
              const ModeToggleSection(),
              const SizedBox(height: 16),
            ],

            // Наш TransfersStrip живёт отдельно на StreamBuilder
            const TransfersStrip(),

            const Expanded(child: MainContentSection()),

            if (selectedDevice == null) const TextShareInput(),
          ],
        ),
      ),
    );
  }
}
