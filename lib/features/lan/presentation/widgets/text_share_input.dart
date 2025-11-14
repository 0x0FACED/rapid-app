import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/lan_bloc.dart';
import '../bloc/lan_event.dart';
import '../bloc/lan_state.dart';

class TextShareInput extends StatefulWidget {
  const TextShareInput({super.key});

  @override
  State<TextShareInput> createState() => _TextShareInputState();
}

class _TextShareInputState extends State<TextShareInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Поле ввода
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Type text or paste link...',
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _controller.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(
                    () {},
                  ); // Обновляем UI для показа/скрытия кнопки clear
                },
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _sendText(context, value.trim());
                  }
                },
              ),
            ),

            const SizedBox(width: 8),

            // Кнопка отправки
            BlocBuilder<LanBloc, LanState>(
              builder: (context, state) {
                final hasText = _controller.text.trim().isNotEmpty;

                return FloatingActionButton(
                  mini: true,
                  onPressed: hasText
                      ? () => _sendText(context, _controller.text.trim())
                      : null,
                  backgroundColor: hasText
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.send,
                    color: hasText
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.4),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendText(BuildContext context, String text) {
    final state = context.read<LanBloc>().state;

    if (state is! LanLoaded) return;

    // Если есть выбранное устройство, отправляем ему
    if (state.selectedDevice != null) {
      context.read<LanBloc>().add(LanSendText(text, state.selectedDevice!.id));

      _controller.clear();
      _focusNode.unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Text sent to ${state.selectedDevice!.name}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Если нет выбранного устройства, показываем диалог выбора
      _showDeviceSelectionDialog(context, text, state);
    }
  }

  /// Диалог выбора устройства для отправки текста
  void _showDeviceSelectionDialog(
    BuildContext context,
    String text,
    LanLoaded state,
  ) {
    if (state.availableDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No devices available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send text to:',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...state.availableDevices.map((device) {
                return ListTile(
                  leading: const Icon(Icons.devices),
                  title: Text(device.name),
                  subtitle: Text(device.host),
                  trailing: device.isOnline
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.cancel, color: Colors.grey),
                  enabled: device.isOnline,
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    context.read<LanBloc>().add(LanSendText(text, device.id));

                    _controller.clear();
                    _focusNode.unfocus();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Text sent to ${device.name}'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
