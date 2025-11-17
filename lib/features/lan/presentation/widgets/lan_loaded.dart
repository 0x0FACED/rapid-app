import 'dart:io';

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

  const LanLoadedScaffold({super.key, required this.state});

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
        resizeToAvoidBottomInset: true,
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
        body: SafeArea(
          child: Column(
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
      ),
    );
  }
}

class ManualDeviceDialog extends StatefulWidget {
  const ManualDeviceDialog({super.key});

  @override
  State<ManualDeviceDialog> createState() => _ManualDeviceDialogState();
}

class _ManualDeviceDialogState extends State<ManualDeviceDialog> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '53317');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add device manually'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'IP address',
              hintText: '192.168.0.10',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _loading ? null : () => _onConfirm(context),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _onConfirm(BuildContext context) async {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();

    final parsedIp = InternetAddress.tryParse(ip);
    if (parsedIp == null || parsedIp.type != InternetAddressType.IPv4) {
      setState(() => _error = 'Invalid IPv4 address');
      return;
    }

    final port = int.tryParse(portStr);
    if (port == null || port <= 0 || port > 65535) {
      setState(() => _error = 'Invalid port');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    context.read<LanBloc>().add(LanAddManualDevice(ip, port));

    Navigator.pop(context);
  }
}
