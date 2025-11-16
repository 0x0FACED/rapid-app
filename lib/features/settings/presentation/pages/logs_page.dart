import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:rapid/core/logging/log_service.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:rapid/core/logging/log_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  Level _minLevel = Level.ALL;
  final _records = <LogRecord>[];
  StreamSubscription<LogRecord>? _subscription;

  final _scrollController = ScrollController();
  bool _autoScroll = true; // true, если пользователь у низа

  // Пустое множество = отображаем все логгеры
  Set<String> _enabledLoggers = {};

  @override
  void initState() {
    super.initState();

    _records.addAll(LogService.instance.records);
    _enabledLoggers = _collectLoggerNames();

    _scrollController.addListener(_onScroll);

    _subscription = LogService.instance.stream.listen((record) {
      final shouldAutoScroll = _autoScroll; // снимаем снимок до setState

      setState(() {
        _records.add(record);
        if (_records.length > 1000) {
          _records.removeAt(0);
        }
        if (_enabledLoggers.isEmpty) {
          _enabledLoggers = _collectLoggerNames();
        }
      });

      if (shouldAutoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          final position = _scrollController.position.maxScrollExtent;
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    const threshold = 80.0; // пикселей до низа, когда считаем, что мы "внизу"
    final atBottom = position.maxScrollExtent - position.pixels <= threshold;
    _autoScroll = atBottom;
  }

  Set<String> _collectLoggerNames() {
    return _records.map((r) => r.loggerName).toSet();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allLoggers = _collectLoggerNames().toList()..sort();

    final enabled = _enabledLoggers.isEmpty
        ? allLoggers.toSet()
        : _enabledLoggers;

    // БЕЗ reversed: новые логи внизу
    final filtered = _records
        .where((r) => r.level.value >= _minLevel.value)
        .where((r) => enabled.contains(r.loggerName))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          PopupMenuButton<Level>(
            icon: const Icon(Icons.filter_list),
            onSelected: (level) {
              setState(() {
                _minLevel = level;
              });
            },
            itemBuilder: (context) => [
              _levelItem('ALL', Level.ALL),
              _levelItem('DEBUG', Level.FINE),
              _levelItem('INFO', Level.INFO),
              _levelItem('WARNING', Level.WARNING),
              _levelItem('ERROR', Level.SEVERE),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filter by logger',
            onPressed: () => _showLoggerFilterDialog(context, allLoggers),
          ),
        ],
      ),
      body: filtered.isEmpty
          ? const Center(child: Text('No logs yet'))
          : ListView.builder(
              controller: _scrollController,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final r = filtered[index];
                return _LogTile(record: r);
              },
            ),
    );
  }

  PopupMenuItem<Level> _levelItem(String label, Level level) {
    return PopupMenuItem(value: level, child: Text(label));
  }

  void _showLoggerFilterDialog(BuildContext context, List<String> allLoggers) {
    final currentEnabled = _enabledLoggers.isEmpty
        ? allLoggers.toSet()
        : _enabledLoggers;

    showDialog(
      context: context,
      builder: (dialogContext) {
        var tmpSelected = currentEnabled.toSet();

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Filter loggers'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allLoggers.length,
                  itemBuilder: (context, index) {
                    final name = allLoggers[index];
                    final selected = tmpSelected.contains(name);
                    return CheckboxListTile(
                      value: selected,
                      title: Text(name),
                      dense: true,
                      onChanged: (value) {
                        setStateDialog(() {
                          if (value == true) {
                            tmpSelected.add(name);
                          } else {
                            tmpSelected.remove(name);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _enabledLoggers = tmpSelected;
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LogTile extends StatefulWidget {
  final LogRecord record;

  const _LogTile({super.key, required this.record});

  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final levelColor = _colorForLevel(r.level);

    final fullMessage = r.message;
    final shortMessage = fullMessage.length > 100
        ? '${fullMessage.substring(0, 100)}…'
        : fullMessage;

    final hasError = r.error != null && r.error.toString().trim().isNotEmpty;
    final hasStack =
        r.stackTrace != null && r.stackTrace.toString().trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: _expanded ? 0.9 : 0.6),
                boxShadow: _expanded
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Шапка
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: levelColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '[${r.level.name}] ${r.loggerName}',
                          style: TextStyle(
                            color: levelColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(r.time),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).iconTheme.color?.withValues(alpha: 0.8),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Сообщение (короткое / полное)
                  Text(
                    _expanded ? fullMessage : shortMessage,
                    style: const TextStyle(fontSize: 12),
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),

                  if (_expanded) ...[
                    const SizedBox(height: 6),
                    // Доп. метаданные
                    Text(
                      'Time: ${r.time.toIso8601String()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      'Logger: ${r.loggerName}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    if (hasError) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Error:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.error.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                    if (hasStack) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Stack trace:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.stackTrace.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color _colorForLevel(Level level) {
    if (level >= Level.SEVERE) return Colors.red;
    if (level >= Level.WARNING) return Colors.orange;
    if (level >= Level.INFO) return Colors.blue;
    return Colors.grey;
  }
}
