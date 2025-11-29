import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_event.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_state.dart';
import 'package:rapid/features/lan/presentation/pages/chat_page.dart';
import 'package:rapid/features/lan/presentation/widgets/device_list.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: BlocBuilder<LanBloc, LanState>(
        builder: (context, state) {
          if (state is! LanLoaded || state.favoriteDevices.isEmpty) {
            return const Center(child: Text('No favorite devices yet'));
          }

          final loaded = state;
          final favorites = loaded.favoriteDevices;

          return DeviceList(
            devices: favorites,
            showFavoriteIcon: true,
            isFavorite: (device) =>
                loaded.favoriteDevices.any((d) => d.id == device.id),
            onFavoriteTap: (device) {
              context.read<LanBloc>().add(LanToggleFavorite(device));
            },
            onDeviceTap: (device) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<LanBloc>(),
                    child: ChatPage(device: device),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
