import 'package:equatable/equatable.dart';

enum NotificationType { textReceived, fileDownloaded, fileDownloadFailed }

class AppNotification extends Equatable {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? deviceName; // От кого
  final String? deviceId;
  final Map<String, dynamic>? metadata; // Доп. данные

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.deviceName,
    this.deviceId,
    this.metadata,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      deviceName: deviceName,
      deviceId: deviceId,
      metadata: metadata,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    title,
    message,
    timestamp,
    isRead,
    deviceName,
    deviceId,
    metadata,
  ];
}
