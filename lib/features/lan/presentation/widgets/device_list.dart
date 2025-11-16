import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/device.dart';
import '../bloc/lan_bloc.dart';
import '../bloc/lan_event.dart';

class DeviceList extends StatelessWidget {
  final List<Device> devices;
  final void Function(Device)? onDeviceTap;
  final bool showFavoriteIcon;
  final bool Function(Device)? isFavorite;
  final void Function(Device)? onFavoriteTap;

  const DeviceList({
    super.key,
    required this.devices,
    this.onDeviceTap,
    this.showFavoriteIcon = false,
    this.isFavorite,
    this.onFavoriteTap,
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return _DeviceCard(
          key: ValueKey(device.id),
          device: device,
          onTap: onDeviceTap,
          showFavoriteIcon: showFavoriteIcon,
          isFavorite: isFavorite,
          onFavoriteTap: onFavoriteTap,
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Device device;
  final void Function(Device)? onTap;
  final bool showFavoriteIcon;
  final bool Function(Device)? isFavorite;
  final void Function(Device)? onFavoriteTap;

  const _DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.showFavoriteIcon = false,
    this.isFavorite,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final favorite = isFavorite?.call(device) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (onTap != null) {
            onTap!(device);
          } else {
            context.read<LanBloc>().add(LanSelectDevice(device.id));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildAvatar(context),
              const SizedBox(width: 16),
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
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
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
              const SizedBox(width: 8),
              if (showFavoriteIcon)
                IconButton(
                  icon: Icon(
                    favorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: favorite
                        ? Colors.amber
                        : Theme.of(context).iconTheme.color,
                  ),
                  onPressed: () {
                    onFavoriteTap?.call(device);
                  },
                )
              else
                const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    print('[DeviceCard] Building avatar for ${device.name}');

    if (device.avatar != null && device.avatar!.isNotEmpty) {
      print('[DeviceCard]   avatar length: ${device.avatar!.length} chars');

      // ИСПРАВЛЕНО: Проверяем что это base64
      try {
        final bytes = base64Decode(device.avatar!);
        print('[DeviceCard]   ✓ Decoded ${bytes.length} bytes from base64');
        return CircleAvatar(
          radius: 28,
          backgroundImage: MemoryImage(bytes),
          onBackgroundImageError: (error, stackTrace) {
            print('[DeviceCard]   ✗ Failed to load image: $error');
          },
        );
      } catch (e) {
        print('[DeviceCard]   ✗ Not a valid base64: $e');
      }
    } else {
      print('[DeviceCard]   avatar is null or empty');
    }

    // Fallback
    print('[DeviceCard]   → Using fallback icon');
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: device.isOnline
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.devices,
        color: device.isOnline
            ? Theme.of(context).colorScheme.primary
            : Colors.grey,
        size: 32,
      ),
    );
  }
}
