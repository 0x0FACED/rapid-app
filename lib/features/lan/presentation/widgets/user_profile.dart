import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_state.dart';
import 'package:rapid/features/lan/presentation/widgets/user_profile_card.dart';
import 'package:rapid/features/settings/domain/entities/user_settings.dart';

class UserProfileSection extends StatelessWidget {
  const UserProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LanBloc, LanState, UserSettings>(
      selector: (state) {
        if (state is LanLoaded) return state.userSettings;
        // Можно вернуть дефолт или кинуть assert — на твой вкус
        throw StateError('UserProfileSection used outside LanLoaded');
      },
      builder: (context, settings) {
        return UserProfileCard(settings: settings);
      },
    );
  }
}
