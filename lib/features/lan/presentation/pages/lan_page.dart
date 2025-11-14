import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rapid/features/lan/domain/entities/device.dart';
import 'package:rapid/features/lan/domain/entities/shared_file.dart';
import 'package:rapid/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:rapid/features/settings/presentation/bloc/settings_state.dart';
import '../../../../core/di/injection.dart';
import '../bloc/lan_bloc.dart';
import '../bloc/lan_event.dart';
import '../bloc/lan_state.dart';
import '../widgets/user_profile_card.dart';
import '../widgets/device_list.dart';
import '../widgets/shared_files_list.dart';
import '../widgets/text_share_input.dart';
import '../widgets/transfer_progress_card.dart';

class LANPage extends StatelessWidget {
  const LANPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LanBloc>()..add(LanInitialize()),
      child: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, settingsState) {
          if (settingsState is SettingsLoaded) {
            // При изменении настроек обновляем LanBloc
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
    return Scaffold(
      appBar: AppBar(title: const Text('Rapid LAN'), centerTitle: true),
      body: BlocBuilder<LanBloc, LanState>(
        builder: (context, state) {
          if (state is LanLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is LanError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<LanBloc>().add(LanInitialize()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is LanLoaded) {
            return Column(
              children: [
                // Профиль пользователя
                UserProfileCard(settings: state.userSettings),

                const SizedBox(height: 16),

                // Переключатель Share / Receive
                _ModeToggle(isShareMode: state.isShareMode),

                const SizedBox(height: 16),

                // Контент в зависимости от режима
                Expanded(
                  child: state.isShareMode
                      ? _ShareModeContent(sharedFiles: state.sharedFiles)
                      : _ReceiveModeContent(
                          devices: state.availableDevices,
                          selectedDevice: state.selectedDevice,
                          receivedFiles: state.receivedFiles,
                        ),
                ),

                // Поле для отправки текста (внизу)
                const TextShareInput(),
              ],
            );
          }

          if (state is LanLoaded) {
            return Column(
              children: [
                UserProfileCard(settings: state.userSettings),
                const SizedBox(height: 16),
                _ModeToggle(isShareMode: state.isShareMode),
                const SizedBox(height: 16),

                // НОВОЕ: Показываем активные передачи
                if (state.activeTransfers.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: state.activeTransfers.length,
                      itemBuilder: (context, index) {
                        return TransferProgressCard(
                          transfer: state.activeTransfers[index],
                        );
                      },
                    ),
                  ),

                // Основной контент
                Expanded(
                  flex: 3,
                  child: state.isShareMode
                      ? _ShareModeContent(sharedFiles: state.sharedFiles)
                      : _ReceiveModeContent(
                          devices: state.availableDevices,
                          selectedDevice: state.selectedDevice,
                          receivedFiles: state.receivedFiles,
                        ),
                ),

                const TextShareInput(),
              ],
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}

/// Переключатель между Share и Receive
class _ModeToggle extends StatelessWidget {
  final bool isShareMode;

  const _ModeToggle({required this.isShareMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  context.read<LanBloc>().add(const LanToggleMode(true)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isShareMode
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: isShareMode
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Share',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  context.read<LanBloc>().add(const LanToggleMode(false)),
              style: ElevatedButton.styleFrom(
                backgroundColor: !isShareMode
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: !isShareMode
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Receive',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Контент для режима Share
class _ShareModeContent extends StatelessWidget {
  final List<SharedFile> sharedFiles;

  const _ShareModeContent({required this.sharedFiles});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Кнопка добавления файлов
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: () => context.read<LanBloc>().add(LanPickFiles()),
            icon: const Icon(Icons.add),
            label: const Text('Add Files'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Список расшаренных файлов
        Expanded(child: SharedFilesList(files: sharedFiles)),
      ],
    );
  }
}

/// Контент для режима Receive
class _ReceiveModeContent extends StatelessWidget {
  final List<Device> devices;
  final dynamic selectedDevice;
  final List<SharedFile>? receivedFiles;

  const _ReceiveModeContent({
    required this.devices,
    required this.selectedDevice,
    required this.receivedFiles,
  });

  @override
  Widget build(BuildContext context) {
    return DeviceList(
      devices: devices,
      selectedDevice: selectedDevice,
      receivedFiles: receivedFiles,
    );
  }
}
