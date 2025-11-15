import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import '../../features/lan/domain/entities/notification.dart';

@lazySingleton
class NotificationService {
  final List<AppNotification> _notifications = [];
  final _notificationsController =
      StreamController<List<AppNotification>>.broadcast();

  Stream<List<AppNotification>> get notificationsStream =>
      _notificationsController.stream;
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void addTextNotification({
    required String deviceName,
    required String deviceId,
    required String text,
  }) {
    final notification = AppNotification(
      id: const Uuid().v4(),
      type: NotificationType.textReceived,
      title: 'Text from $deviceName',
      message: text,
      timestamp: DateTime.now(),
      deviceName: deviceName,
      deviceId: deviceId,
    );

    _notifications.insert(0, notification); // Новые сверху
    _notificationsController.add(_notifications);

    print('[Notifications] Added text notification from $deviceName');
  }

  void addFileDownloadedNotification({
    required String deviceName,
    required String fileName,
    required String filePath,
  }) {
    final notification = AppNotification(
      id: const Uuid().v4(),
      type: NotificationType.fileDownloaded,
      title: 'File downloaded',
      message: '$fileName from $deviceName',
      timestamp: DateTime.now(),
      deviceName: deviceName,
      metadata: {'filePath': filePath, 'fileName': fileName},
    );

    _notifications.insert(0, notification);
    _notificationsController.add(_notifications);

    print('[Notifications] Added file download notification: $fileName');
  }

  void addFileDownloadFailedNotification({
    required String deviceName,
    required String fileName,
    required String error,
  }) {
    final notification = AppNotification(
      id: const Uuid().v4(),
      type: NotificationType.fileDownloadFailed,
      title: 'Download failed',
      message: '$fileName from $deviceName: $error',
      timestamp: DateTime.now(),
      deviceName: deviceName,
      metadata: {'fileName': fileName, 'error': error},
    );

    _notifications.insert(0, notification);
    _notificationsController.add(_notifications);
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _notificationsController.add(_notifications);
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    _notificationsController.add(_notifications);
  }

  void clearAll() {
    _notifications.clear();
    _notificationsController.add(_notifications);
  }

  void dispose() {
    _notificationsController.close();
  }
}
