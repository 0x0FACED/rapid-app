import 'package:equatable/equatable.dart';

class SharedFile extends Equatable {
  final String id;
  final String name;
  final String path; // Путь к файлу на устройстве
  final int size;
  final String mimeType;
  final DateTime addedAt;

  const SharedFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
    required this.addedAt,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  List<Object?> get props => [id, name, path, size, mimeType, addedAt];
}
