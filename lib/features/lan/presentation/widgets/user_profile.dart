import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_event.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_state.dart';
import 'package:rapid/features/lan/presentation/widgets/user_profile_card.dart';
import 'package:rapid/features/settings/domain/entities/user_settings.dart';

class UserProfileSection extends StatelessWidget {
  const UserProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LanBloc, LanState, _UserProfileVm>(
      selector: (state) {
        if (state is LanLoaded) {
          return _UserProfileVm(
            settings: state.userSettings,
            isLanOnline: state.isLanOnline,
            hasActiveTransfers: state.activeTransfers.isNotEmpty,
          );
        }
        throw StateError('UserProfileSection used outside LanLoaded');
      },
      builder: (context, vm) {
        return UserProfileCard(
          settings: vm.settings,
          isLanOnline: vm.isLanOnline,
          onLanOnlineChanged: (value) async {
            // Если выключаем, а есть активные передачи — спрашиваем
            if (!value && vm.hasActiveTransfers) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Go offline?'),
                  content: const Text(
                    'There are active transfers. Going offline will cancel them.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Go offline'),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;
            }

            context.read<LanBloc>().add(LanSetOnline(value));
          },
        );
      },
    );
  }
}

class _UserProfileVm {
  final UserSettings settings;
  final bool isLanOnline;
  final bool hasActiveTransfers;

  _UserProfileVm({
    required this.settings,
    required this.isLanOnline,
    required this.hasActiveTransfers,
  });
}
