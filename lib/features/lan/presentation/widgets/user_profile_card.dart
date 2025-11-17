import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_bloc.dart';
import 'package:rapid/features/lan/presentation/pages/favorites_page.dart';
import 'package:rapid/features/lan/presentation/pages/notification_page.dart';
import '../../../settings/domain/entities/user_settings.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/notification_service.dart';

class UserProfileCard extends StatelessWidget {
  final UserSettings settings;
  final bool isLanOnline;
  final ValueChanged<bool> onLanOnlineChanged;

  const UserProfileCard({
    super.key,
    required this.settings,
    required this.isLanOnline,
    required this.onLanOnlineChanged,
  });

  @override
  Widget build(BuildContext context) {
    final notificationService = getIt<NotificationService>();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Аватар
            CircleAvatar(
              radius: 32,
              backgroundColor: Theme.of(context).colorScheme.primary,
              backgroundImage: settings.avatar != null
                  ? FileImage(File(settings.avatar!))
                  : null,
              child: settings.avatar == null
                  ? Text(
                      _getInitials(settings.deviceName),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 16),

            // Информация о пользователе
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.deviceName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.smartphone,
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getDeviceType(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        settings.useHttps ? Icons.lock : Icons.lock_open,
                        size: 16,
                        color: settings.useHttps ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        settings.useHttps ? 'HTTPS' : 'HTTP',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: settings.useHttps
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Port: ${settings.serverPort}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Правая колонка: online switch + favorites + notifications
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Компактный переключатель онлайн/оффлайн
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 4),
                    Switch(
                      value: isLanOnline,
                      onChanged: onLanOnlineChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      //hoverColor: Colors.green,
                      activeThumbColor: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Ряд: избранное + уведомления
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Кнопка избранных устройств
                    IconButton(
                      icon: const Icon(Icons.star_rounded),
                      tooltip: 'Favorites',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FavoritesPage(),
                          ),
                        );
                      },
                    ),

                    // Кнопка уведомлений с badge
                    StreamBuilder<List>(
                      stream: notificationService.notificationsStream,
                      initialData: notificationService.notifications,
                      builder: (context, snapshot) {
                        final unreadCount = notificationService.unreadCount;
                        return Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsPage(),
                                  ),
                                );
                              },
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadCount > 9 ? '9+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }

    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _getDeviceType() {
    return Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
        ? 'iPhone'
        : Platform.isWindows
        ? 'Windows'
        : Platform.isLinux
        ? 'Linux'
        : Platform.isMacOS
        ? 'MacOS'
        : 'Unknown';
  }
}
