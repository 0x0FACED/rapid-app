import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_bloc.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_event.dart';
import 'package:rapid/features/lan/presentation/bloc/lan_state.dart';

class ModeToggleSection extends StatelessWidget {
  const ModeToggleSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LanBloc, LanState, bool>(
      selector: (state) {
        if (state is LanLoaded) return state.isShareMode;
        return true; // или false, или assert — зависит от логики
      },
      builder: (context, isShareMode) {
        return _ModeToggle(isShareMode: isShareMode);
      },
    );
  }
}

/// Переключатель между Share и Receive
class _ModeToggle extends StatelessWidget {
  final bool isShareMode;

  const _ModeToggle({required this.isShareMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  context.read<LanBloc>().add(const LanToggleMode(true)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isShareMode
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: isShareMode
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Share',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  context.read<LanBloc>().add(const LanToggleMode(false)),
              style: ElevatedButton.styleFrom(
                backgroundColor: !isShareMode
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: !isShareMode
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Receive',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
