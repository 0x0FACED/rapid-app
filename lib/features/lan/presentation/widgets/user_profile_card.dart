import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String? currentIp;

  const UserProfileCard({
    super.key,
    required this.settings,
    required this.isLanOnline,
    required this.onLanOnlineChanged,
    this.currentIp,
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
                      buildDeviceIcon(context),
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
                  Builder(
                    builder: (context) {
                      final ip = currentIp;
                      final hostPort = ip != null
                          ? '$ip:${settings.serverPort}'
                          : null;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                alignment: Alignment.centerLeft,
                              ),
                              onPressed: hostPort == null
                                  ? null
                                  : () {
                                      Clipboard.setData(
                                        ClipboardData(text: hostPort),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Адрес скопирован: $hostPort',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                              child: Text(
                                hostPort ?? 'IP не найден',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: hostPort == null
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.6)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
                        final lanBloc = context
                            .read<LanBloc>(); // берём существующий

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: lanBloc,
                              child: const FavoritesPage(),
                            ),
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

  Widget buildDeviceIcon(BuildContext context) {
    final deviceType = _getDeviceType();

    final iconColor = Theme.of(context).colorScheme.secondary;
    const iconSize = 16.0;

    if (deviceType == 'Android') {
      return Icon(Icons.android, size: iconSize, color: iconColor);
    } else if (deviceType == 'iPhone') {
      return Icon(Icons.phone_iphone, size: iconSize, color: iconColor);
    } else if (deviceType == 'Windows') {
      return Icon(Icons.window, size: iconSize, color: iconColor);
    } else if (deviceType == 'Linux') {
      // Вместо Icons.linux показываем PNG из assets
      return Image.asset(
        'assets/linux-icon.png',
        width: iconSize,
        height: iconSize,
        color: iconColor,
        colorBlendMode: BlendMode
            .srcIn, // Применяет цвет к png, если она монохромная с прозрачным фоном
        fit: BoxFit.contain,
      );
    } else if (deviceType == 'MacOS') {
      return Icon(Icons.laptop_mac, size: iconSize, color: iconColor);
    } else {
      return Icon(Icons.devices_other, size: iconSize, color: iconColor);
    }
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
