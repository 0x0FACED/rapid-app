import 'dart:io';
import 'package:flutter/material.dart';
import '../../../settings/domain/entities/user_settings.dart';

class UserProfileCard extends StatelessWidget {
  final UserSettings settings;

  const UserProfileCard({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
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
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Кнопка настроек
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // TODO: Navigate to settings
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Получить инициалы из имени
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }

    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  /// Определить тип устройства
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
