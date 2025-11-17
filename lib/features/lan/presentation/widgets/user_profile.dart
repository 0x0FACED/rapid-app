import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:rapid/core/network/ip_watcher.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_event.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_state.dart';
import 'package:rapid/features/lan/presentation/widgets/user_profile_card.dart';
import 'package:rapid/features/settings/domain/entities/user_settings.dart';

class UserProfileSection extends StatelessWidget {
  const UserProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => IPWatcher(),
      child: BlocSelector<LanBloc, LanState, _UserProfileVm>(
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
          // Теперь Consumer слушает IPWatcher и даёт IP всегда актуально
          return Consumer<IPWatcher>(
            builder: (context, watcher, _) {
              return UserProfileCard(
                settings: vm.settings,
                currentIp: watcher.currentIp,
                isLanOnline: vm.isLanOnline,
                onLanOnlineChanged: (value) async {
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
        },
      ),
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
