import 'package:equatable/equatable.dart';

/// Модель файла для передачи
class FileInfoModel extends Equatable {
  final String id; // Уникальный ID файла
  final String fileName; // Имя файла
  final int size; // Размер в байтах
  final String fileType; // MIME type
  final String? sha256; // SHA-256 хеш (опционально)
  final String? preview; // Base64 превью (для изображений)

  const FileInfoModel({
    required this.id,
    required this.fileName,
    required this.size,
    required this.fileType,
    this.sha256,
    this.preview,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'size': size,
      'fileType': fileType,
      if (sha256 != null) 'sha256': sha256,
      if (preview != null) 'preview': preview,
    };
  }

  factory FileInfoModel.fromJson(Map<String, dynamic> json) {
    return FileInfoModel(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      size: json['size'] as int,
      fileType: json['fileType'] as String,
      sha256: json['sha256'] as String?,
      preview: json['preview'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, fileName, size, fileType, sha256, preview];
}
