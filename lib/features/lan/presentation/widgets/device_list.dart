import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/device.dart';
import '../bloc/lan_bloc.dart';
import '../bloc/lan_event.dart';

class DeviceList extends StatelessWidget {
  final List<Device> devices;

  const DeviceList({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    print('[DeviceList] Building with ${devices.length} devices');

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

    // ТОЛЬКО список устройств, БЕЗ обработки selectedDevice
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        print('[DeviceList] Item $index: ${device.name}');
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
          print('[DeviceCard] Tapped: ${device.id}');
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
