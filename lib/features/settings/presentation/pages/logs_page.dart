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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          PopupMenuButton<Level>(
            onSelected: (level) {
              setState(() {
                _minLevel = level;
              });
            },
            itemBuilder: (context) => [
              _levelItem('ALL', Level.ALL),
              _levelItem('INFO+', Level.INFO),
              _levelItem('WARNING+', Level.WARNING),
              _levelItem('SEVERE+', Level.SEVERE),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<LogRecord>>(
        stream: LogService.instance.stream,
        initialData: LogService.instance.records,
        builder: (context, snapshot) {
          final records = (snapshot.data ?? [])
              .where((r) => r.level.value >= _minLevel.value)
              .toList()
              .reversed
              .toList(); // последние сверху

          if (records.isEmpty) {
            return const Center(child: Text('No logs yet'));
          }

          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final r = records[index];
              return ListTile(
                dense: true,
                title: Text(
                  '[${r.level.name}] ${r.loggerName}',
                  style: TextStyle(
                    color: _colorForLevel(r.level),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${r.time.toIso8601String()}\n${r.message}',
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }

  PopupMenuItem<Level> _levelItem(String label, Level level) {
    return PopupMenuItem(value: level, child: Text(label));
  }

  Color _colorForLevel(Level level) {
    if (level >= Level.SEVERE) return Colors.red;
    if (level >= Level.WARNING) return Colors.orange;
    if (level >= Level.INFO) return Colors.blue;
    return Colors.grey;
  }
}
