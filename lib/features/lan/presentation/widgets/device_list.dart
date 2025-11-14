import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/shared_file.dart';
import '../bloc/lan_bloc.dart';
import '../bloc/lan_event.dart';

class DeviceList extends StatelessWidget {
  final List<Device> devices;
  final Device? selectedDevice;
  final List<SharedFile>? receivedFiles;

  const DeviceList({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.receivedFiles,
  });

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Searching for devices in network...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      );
    }

    // Если устройство выбрано, показываем его файлы
    if (selectedDevice != null) {
      return Column(
        children: [
          _DeviceHeader(device: selectedDevice!),
          const Divider(height: 1),
          Expanded(child: _ReceivedFilesList(files: receivedFiles ?? [])),
        ],
      );
    }

    // Иначе показываем список устройств
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return _DeviceCard(device: device);
      },
    );
  }
}

/// Карточка устройства
class _DeviceCard extends StatelessWidget {
  final Device device;

  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.read<LanBloc>().add(LanSelectDevice(device.id));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Иконка устройства
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: device.isOnline
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.devices,
                  color: device.isOnline
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  size: 32,
                ),
              ),

              const SizedBox(width: 16),

              // Информация об устройстве
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${device.host}:${device.port}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: device.isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          device.isOnline ? 'Online' : 'Offline',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: device.isOnline
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          device.protocol == 'https'
                              ? Icons.lock
                              : Icons.lock_open,
                          size: 14,
                          color: device.protocol == 'https'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          device.protocol.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: device.protocol == 'https'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Заголовок выбранного устройства
class _DeviceHeader extends StatelessWidget {
  final Device device;

  const _DeviceHeader({required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.read<LanBloc>().add(const LanSelectDevice(null));
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Shared files',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Список полученных файлов от выбранного устройства
class _ReceivedFilesList extends StatelessWidget {
  final List<SharedFile> files;

  const _ReceivedFilesList({required this.files});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No shared files',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _ReceivedFileCard(file: file);
      },
    );
  }
}

/// Карточка полученного файла
class _ReceivedFileCard extends StatelessWidget {
  final SharedFile file;

  const _ReceivedFileCard({required this.file});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildFileIcon(context),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          file.sizeFormatted,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.download,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () {
            // TODO: Download file
            print('Download file: ${file.id}');
          },
        ),
      ),
    );
  }

  Widget _buildFileIcon(BuildContext context) {
    IconData icon;
    Color color;

    if (file.mimeType.startsWith('image/')) {
      icon = Icons.image;
      color = Colors.blue;
    } else if (file.mimeType.startsWith('video/')) {
      icon = Icons.video_file;
      color = Colors.purple;
    } else if (file.mimeType.startsWith('audio/')) {
      icon = Icons.audio_file;
      color = Colors.orange;
    } else if (file.mimeType.contains('pdf')) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}
