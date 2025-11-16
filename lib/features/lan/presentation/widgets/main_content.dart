import 'dart:convert';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rapid/features/lan/domain/entities/device.dart';
import 'package:rapid/features/lan/domain/entities/shared_file.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_state.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_event.dart';
import 'package:rapid/features/lan/presentation/pages/chat_page.dart';
import 'package:rapid/features/lan/presentation/widgets/device_list.dart';
import 'package:rapid/features/lan/presentation/widgets/shared_files_list.dart';

class MainContentSection extends StatelessWidget {
  const MainContentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LanBloc, LanState, _MainContentState>(
      selector: (state) {
        if (state is! LanLoaded) {
          return const _MainContentState.empty();
        }

        return _MainContentState(
          isShareMode: state.isShareMode,
          selectedDevice: state.selectedDevice,
          availableDevices: state.availableDevices,
          sharedFiles: state.sharedFiles,
          receivedFiles: state.receivedFiles ?? const [],
        );
      },
      builder: (context, data) {
        return PageTransitionSwitcher(
          duration: const Duration(milliseconds: 350),
          // Можно поиграться с reverse, но для начала можно оставить false
          reverse: false,
          transitionBuilder:
              (
                Widget child,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
              ) {
                return SharedAxisTransition(
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  transitionType: SharedAxisTransitionType.scaled,
                  child: child,
                );
              },
          child: _buildChild(data),
        );
      },
    );
  }

  Widget _buildChild(_MainContentState data) {
    if (data.selectedDevice != null) {
      // Экран файлов устройства
      return _DeviceFilesView(
        key: ValueKey('device_${data.selectedDevice!.id}'),
        device: data.selectedDevice!,
        files: data.receivedFiles,
      );
    }

    if (data.isShareMode) {
      // Режим Share
      return _ShareModeContent(
        key: const ValueKey('share_mode'),
        sharedFiles: data.sharedFiles,
      );
    }

    // Режим Receive: список устройств
    return _ReceiveModeContent(
      key: const ValueKey('receive_mode'),
      devices: data.availableDevices,
    );
  }
}

/// DTO для выбора содержимого
class _MainContentState {
  final bool isShareMode;
  final Device? selectedDevice;
  final List<Device> availableDevices;
  final List<SharedFile> sharedFiles;
  final List<SharedFile> receivedFiles;

  const _MainContentState({
    required this.isShareMode,
    required this.selectedDevice,
    required this.availableDevices,
    required this.sharedFiles,
    required this.receivedFiles,
  });

  const _MainContentState.empty()
    : isShareMode = true,
      selectedDevice = null,
      availableDevices = const [],
      sharedFiles = const [],
      receivedFiles = const [];
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
              padding: const EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.onSecondary,
                      Theme.of(
                        context,
                      ).colorScheme.onSecondary.withOpacity(0.7),
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
                          padding: const EdgeInsets.all(
                            2,
                          ), // чуть меньше padding, т.к. внутри круг
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: _buildDeviceAvatar(context, device),
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

                    const SizedBox(height: 8),

                    // Info chips
                    Row(
                      children: [
                        _buildInfoChip(
                          context,
                          icon: Icons.check_circle_rounded,
                          label: 'Online',
                        ),
                        const SizedBox(width: 3),
                        _buildInfoChip(
                          context,
                          icon: Icons.folder_rounded,
                          label: '${files.length} files',
                        ),
                        const SizedBox(width: 3),
                        _buildInfoChip(
                          context,
                          icon: device.protocol == 'https'
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          label: device.protocol.toUpperCase(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // НОВОЕ: Кнопки действий
                    Row(
                      children: [
                        Expanded(
                          child: BlocSelector<LanBloc, LanState, bool>(
                            selector: (state) {
                              if (state is! LanLoaded) return false;
                              return state.favoriteDevices.any(
                                (d) => d.id == device.id,
                              );
                            },
                            builder: (context, isFavorite) {
                              return ElevatedButton.icon(
                                onPressed: () {
                                  context.read<LanBloc>().add(
                                    LanToggleFavorite(device),
                                  );
                                },
                                icon: Icon(
                                  isFavorite
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  isFavorite ? 'Unfavorite' : 'Favorite',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.2,
                                  ),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              );
                            },
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
    context.read<LanBloc>().add(LanToggleFavorite(device));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('${device.name} favorite status updated')),
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

  Widget _buildDeviceAvatar(BuildContext context, Device device) {
    final avatar = device.avatar;

    if (avatar != null && avatar.isNotEmpty) {
      try {
        // Если строка приходит с префиксом вида "data:image/png;base64,..."
        final cleaned = avatar.replaceAll(
          RegExp(r'^data:image\/[a-zA-Z]+;base64,'),
          '',
        );

        final bytes = base64Decode(cleaned);

        return CircleAvatar(
          radius: 24,
          backgroundImage: MemoryImage(bytes),
          onBackgroundImageError: (error, stackTrace) {
            // Логируем и показываем fallback
            debugPrint('[DeviceFilesView] avatar decode error: $error');
          },
          backgroundColor: Colors.white.withOpacity(0.1),
        );
      } on FormatException catch (e) {
        debugPrint('[DeviceFilesView] invalid base64 avatar: $e');
        // Падаем в fallback ниже
      }
    }

    // Fallback-иконка, если аватарки нет или она битая
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.white.withOpacity(0.1),
      child: const Icon(Icons.devices, color: Colors.white, size: 24),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
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
