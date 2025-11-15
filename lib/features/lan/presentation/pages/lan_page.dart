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
      // ВАЖНО: buildWhen для контроля rebuild
      buildWhen: (previous, current) {
        print(
          '[LANPage] buildWhen: ${previous.runtimeType} -> ${current.runtimeType}',
        );
        return true; // Rebuild при любом изменении
      },
      builder: (context, state) {
        print('[LANPage] Building with state: ${state.runtimeType}');

        if (state is LanLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is LanError) {
          return Scaffold(
            body: Center(
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
            ),
          );
        }

        if (state is LanLoaded) {
          final selectedDevice = state.selectedDevice;

          // НОВОЕ: WillPopScope для обработки системной кнопки назад
          return WillPopScope(
            onWillPop: () async {
              if (selectedDevice != null) {
                context.read<LanBloc>().add(const LanSelectDevice(null));
                return false;
              }
              return true;
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  selectedDevice != null
                      ? selectedDevice
                            .name // Имя выбранного устройства
                      : 'Rapid LAN',
                ),
                centerTitle: true,
                // НОВОЕ: Кнопка назад при выборе устройства
                leading: selectedDevice != null
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          context.read<LanBloc>().add(
                            const LanSelectDevice(null),
                          );
                        },
                      )
                    : null,
              ),
              body: Column(
                children: [
                  // Профиль пользователя (только когда не выбрано устройство)
                  if (selectedDevice == null) ...[
                    UserProfileCard(settings: state.userSettings),
                    const SizedBox(height: 16),
                    _ModeToggle(isShareMode: state.isShareMode),
                    const SizedBox(height: 16),
                  ],

                  // Активные передачи
                  if (state.activeTransfers.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.activeTransfers.length,
                        itemBuilder: (context, index) {
                          return SizedBox(
                            width: 300,
                            child: TransferProgressCard(
                              transfer: state.activeTransfers[index],
                            ),
                          );
                        },
                      ),
                    ),

                  if (state.activeTransfers.isNotEmpty)
                    const SizedBox(height: 16),

                  // Основной контент
                  Expanded(
                    child: selectedDevice != null
                        ? _DeviceFilesView(
                            device: selectedDevice,
                            files: state.receivedFiles ?? [],
                          )
                        : (state.isShareMode
                              ? _ShareModeContent(
                                  sharedFiles: state.sharedFiles,
                                )
                              : _ReceiveModeContent(
                                  devices: state.availableDevices,
                                )),
                  ),

                  // Поле для отправки текста (только если не выбрано устройство)
                  if (selectedDevice == null) const TextShareInput(),
                ],
              ),
            ),
          );
        }

        return const Scaffold(body: Center(child: Text('Unknown state')));
      },
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
        Expanded(child: SharedFilesList(files: sharedFiles)),
      ],
    );
  }
}

/// Контент для режима Receive (список устройств)
class _ReceiveModeContent extends StatelessWidget {
  final List<Device> devices;

  const _ReceiveModeContent({required this.devices});

  @override
  Widget build(BuildContext context) {
    print('[ReceiveModeContent] Showing ${devices.length} devices');

    return DeviceList(devices: devices);
  }
}

/// НОВОЕ: Просмотр файлов выбранного устройства
class _DeviceFilesView extends StatelessWidget {
  final Device device;
  final List<SharedFile> files;

  const _DeviceFilesView({required this.device, required this.files});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No files available'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              _getFileIcon(file.mimeType),
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(file.name),
            subtitle: Text(_formatFileSize(file.size)),
            trailing: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                context.read<LanBloc>().add(
                  LanReceiveFiles(device.id, [file.id]),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Downloading ${file.name}...'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.video_file;
    if (mimeType.startsWith('audio/')) return Icons.audio_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('zip') || mimeType.contains('rar')) {
      return Icons.folder_zip;
    }
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
