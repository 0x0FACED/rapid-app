import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rapid/features/lan/domain/entities/device.dart';
import 'package:rapid/features/lan/domain/entities/shared_file.dart';
import 'package:rapid/features/lan/presentation/pages/chat_page.dart';
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
      buildWhen: (previous, current) {
        if (previous is LanLoaded && current is LanLoaded) {
          // Проверяем изменения userSettings
          if (previous.userSettings.deviceName !=
                  current.userSettings.deviceName ||
              previous.userSettings.avatar != current.userSettings.avatar) {
            print('[LANPage] Settings changed, rebuilding...');
            return true;
          }

          // Проверяем изменения устройств
          final prevCount = previous.availableDevices.length;
          final currCount = current.availableDevices.length;

          if (prevCount != currCount) {
            print('[LANPage] Device count changed: $prevCount → $currCount');
            return true;
          }

          final prevIds = previous.availableDevices.map((d) => d.id).toSet();
          final currIds = current.availableDevices.map((d) => d.id).toSet();

          if (!prevIds.containsAll(currIds) || !currIds.containsAll(prevIds)) {
            print('[LANPage] Device IDs changed');
            return true;
          }

          // Проверяем изменения внутри устройств
          for (int i = 0; i < previous.availableDevices.length; i++) {
            final prevDevice = previous.availableDevices[i];
            final currDevice = current.availableDevices
                .cast<Device?>()
                .firstWhere((d) => d?.id == prevDevice.id, orElse: () => null);

            if (currDevice != null) {
              if (prevDevice.name != currDevice.name) {
                print(
                  '[LANPage] Device name changed: ${prevDevice.name} → ${currDevice.name}',
                );
                return true;
              }
              if (prevDevice.avatar != currDevice.avatar) {
                print('[LANPage] Device avatar changed for ${currDevice.name}');
                return true;
              }
            }
          }

          // НОВОЕ: Проверяем изменения receivedFiles
          final prevFiles = previous.receivedFiles;
          final currFiles = current.receivedFiles;

          if ((prevFiles == null) != (currFiles == null)) {
            print(
              '[LANPage] receivedFiles changed: ${prevFiles == null} → ${currFiles == null}',
            );
            return true;
          }

          if (prevFiles != null && currFiles != null) {
            final prevFileIds = prevFiles.map((f) => f.id).toSet();
            final currFileIds = currFiles.map((f) => f.id).toSet();

            if (prevFiles.length != currFiles.length) {
              print(
                '[LANPage] File count changed: ${prevFiles.length} → ${currFiles.length}',
              );
              return true;
            }

            if (!prevFileIds.containsAll(currFileIds) ||
                !currFileIds.containsAll(prevFileIds)) {
              print('[LANPage] File IDs changed');
              return true;
            }
          }

          return previous.selectedDevice != current.selectedDevice ||
              previous.isShareMode != current.isShareMode ||
              previous.sharedFiles.length != current.sharedFiles.length ||
              previous.activeTransfers.length != current.activeTransfers.length;
        }

        return true;
      },

      builder: (context, state) {
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
                          context.read<LanBloc>().add(
                            const LanSelectDevice(null),
                          );
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
                    UserProfileCard(settings: state.userSettings),
                    const SizedBox(height: 16),
                    _ModeToggle(isShareMode: state.isShareMode),
                    const SizedBox(height: 16),
                  ],

                  if (state.activeTransfers.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.activeTransfers.length,
                        itemBuilder: (context, index) {
                          return SizedBox(
                            width: 280,
                            child: TransferProgressCard(
                              transfer: state.activeTransfers[index],
                            ),
                          );
                        },
                      ),
                    ),

                  if (state.activeTransfers.isNotEmpty)
                    const SizedBox(height: 8),

                  // НОВОЕ: AnimatedSwitcher для плавной анимации
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (child, animation) {
                        // Slide transition справа налево
                        final offsetAnimation =
                            Tween<Offset>(
                              begin: const Offset(1.0, 0.0), // Начало справа
                              end: Offset.zero, // Конец в центре
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            );

                        return SlideTransition(
                          position: offsetAnimation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: selectedDevice != null
                          ? _DeviceFilesView(
                              key: ValueKey('device_${selectedDevice.id}'),
                              device: selectedDevice,
                              files: state.receivedFiles ?? [],
                            )
                          : (state.isShareMode
                                ? _ShareModeContent(
                                    key: const ValueKey('share_mode'),
                                    sharedFiles: state.sharedFiles,
                                  )
                                : _ReceiveModeContent(
                                    key: const ValueKey('receive_mode'),
                                    devices: state.availableDevices,
                                  )),
                    ),
                  ),

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

  const _ShareModeContent({super.key, required this.sharedFiles});

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

  const _ReceiveModeContent({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return DeviceList(devices: devices);
  }
}

/// ИСПРАВЛЕНО: Улучшенный экран файлов устройства
class _DeviceFilesView extends StatelessWidget {
  final Device device;
  final List<SharedFile> files;

  const _DeviceFilesView({
    super.key,
    required this.device,
    required this.files,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ИСПРАВЛЕНО: Плашка с padding и закруглениями
        Hero(
          tag: 'device_card_${device.id}',
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.tertiary,
                      Theme.of(context).colorScheme.tertiary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Верхняя часть: иконка + название + кнопка refresh
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.devices,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${device.host}:${device.port}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              context.read<LanBloc>().add(
                                LanRefreshDeviceFiles(device.id),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Refreshing files...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Info chips
                    Row(
                      children: [
                        _buildInfoChip(
                          context,
                          icon: Icons.folder_rounded,
                          label: '${files.length} files',
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          context,
                          icon: device.protocol == 'https'
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          label: device.protocol.toUpperCase(),
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          context,
                          icon: Icons.check_circle_rounded,
                          label: 'Online',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // НОВОЕ: Кнопки действий
                    Row(
                      children: [
                        // Кнопка "Добавить в избранное"
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _addToFavorites(context, device);
                            },
                            icon: const Icon(Icons.star_rounded, size: 18),
                            label: const Text('Favorite'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Кнопка "Открыть чат"
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _openChat(context, device);
                            },
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text('Chat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.tertiary,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Список файлов
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              context.read<LanBloc>().add(LanRefreshDeviceFiles(device.id));
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: files.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return _FileCard(file: file, device: device);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _addToFavorites(BuildContext context, Device device) {
    // TODO: Реализовать логику добавления в избранное
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('${device.name} added to favorites')),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openChat(BuildContext context, Device device) {
    // ИСПРАВЛЕНО: Передаём существующий LanBloc
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<LanBloc>(), // Используем существующий BLoC
          child: ChatPage(device: device),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No files shared',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Карточка файла с улучшенным дизайном
class _FileCard extends StatelessWidget {
  final SharedFile file;
  final Device device;

  const _FileCard({required this.file, required this.device});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showFileOptions(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Иконка файла
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getFileColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getFileIcon(), color: _getFileColor(), size: 28),
              ),

              const SizedBox(width: 16),

              // Информация о файле
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatFileSize(file.size),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),

              // Кнопка скачивания
              IconButton(
                icon: Icon(
                  Icons.download_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  _downloadFile(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _downloadFile(BuildContext context) {
    context.read<LanBloc>().add(LanReceiveFiles(device.id, [file.id]));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${file.name}...'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFileOptions(BuildContext context) {
    // ИСПРАВЛЕНО: Захватываем BLoC ДО открытия BottomSheet
    final lanBloc = context.read<LanBloc>();

    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                // ИСПРАВЛЕНО: Используем захваченный BLoC
                lanBloc.add(LanReceiveFiles(device.id, [file.id]));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Downloading ${file.name}...'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('File info'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _showFileInfo(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFileInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${file.name}'),
            const SizedBox(height: 8),
            Text('Size: ${_formatFileSize(file.size)}'),
            const SizedBox(height: 8),
            Text('Type: ${file.mimeType}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon() {
    if (file.mimeType.startsWith('image/')) return Icons.image_rounded;
    if (file.mimeType.startsWith('video/')) return Icons.video_file_rounded;
    if (file.mimeType.startsWith('audio/')) return Icons.audio_file_rounded;
    if (file.mimeType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (file.mimeType.contains('zip') || file.mimeType.contains('rar')) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor() {
    if (file.mimeType.startsWith('image/')) return Colors.blue;
    if (file.mimeType.startsWith('video/')) return Colors.purple;
    if (file.mimeType.startsWith('audio/')) return Colors.orange;
    if (file.mimeType.contains('pdf')) return Colors.red;
    if (file.mimeType.contains('zip') || file.mimeType.contains('rar')) {
      return Colors.amber;
    }
    return Colors.grey;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
