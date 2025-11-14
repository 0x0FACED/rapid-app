import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/shared_file.dart';
import '../bloc/lan_bloc.dart';
import '../bloc/lan_event.dart';

class SharedFilesList extends StatelessWidget {
  final List<SharedFile> files;

  const SharedFilesList({super.key, required this.files});

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
              'No files shared yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Files" to start sharing',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileCard(file: file);
      },
    );
  }
}

class _FileCard extends StatelessWidget {
  final SharedFile file;

  const _FileCard({required this.file});

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
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () {
            context.read<LanBloc>().add(LanRemoveSharedFile(file.id));
          },
        ),
      ),
    );
  }

  /// Иконка файла в зависимости от типа
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
    } else if (file.mimeType.contains('zip') || file.mimeType.contains('rar')) {
      icon = Icons.folder_zip;
      color = Colors.amber;
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
