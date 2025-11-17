import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rapid/features/lan/domain/entities/device.dart';
import 'package:rapid/features/lan/presentation/widgets/lan_loaded.dart';
import 'package:rapid/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:rapid/features/settings/presentation/bloc/settings_state.dart';
import '../../../../core/di/injection.dart';
import '../bloc/lan_bloc.dart';
import '../bloc/lan_event.dart';
import '../bloc/lan_state.dart';

class LANPage extends StatelessWidget {
  const LANPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LanBloc>()..add(LanInitialize()),
      child: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, settingsState) {
          if (settingsState is SettingsLoaded) {
            context.read<LanBloc>().add(LanRefreshSettings());
          }
        },
        child: const _LANPageContent(),
      ),
    );
  }
}

class _LANPageContent extends StatelessWidget {
  const _LANPageContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanBloc, LanState>(
      // Больше не пытаемся вручную diff'ать весь LanLoaded
      buildWhen: (previous, current) {
        // Если тип состояния изменился (Loading -> Loaded, Error и т.п.)
        if (previous.runtimeType != current.runtimeType) return true;

        if (previous is LanLoaded && current is LanLoaded) {
          final selectedChanged =
              previous.selectedDevice != current.selectedDevice;
          final modeChanged = previous.isShareMode != current.isShareMode;

          final devicesChanged =
              previous.availableDevices.length !=
                  current.availableDevices.length ||
              !_sameDeviceList(
                previous.availableDevices,
                current.availableDevices,
              );

          return selectedChanged || modeChanged || devicesChanged;
        }

        return false;
      },
      builder: (context, state) {
        if (state is LanLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is LanError) {
          return _LanErrorView(message: state.message);
        }

        if (state is LanLoaded) {
          return LanLoadedScaffold(state: state);
        }

        return const Scaffold(body: Center(child: Text('Unknown state')));
      },
    );
  }

  bool _sameDeviceList(List<Device> a, List<Device> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final d1 = a[i];
      final d2 = b[i];
      if (d1.id != d2.id ||
          d1.name != d2.name ||
          d1.host != d2.host ||
          d1.port != d2.port ||
          d1.protocol != d2.protocol ||
          d1.isOnline != d2.isOnline ||
          d1.avatar != d2.avatar) {
        return false;
      }
    }
    return true;
  }
}

class _LanErrorView extends StatelessWidget {
  final String message;

  const _LanErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<LanBloc>().add(LanInitialize()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
