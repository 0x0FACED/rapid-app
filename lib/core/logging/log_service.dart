// lib/core/logging/log_service.dart
import 'dart:async';
import 'package:logging/logging.dart';

class LogService {
  static const int _maxEntries = 1000;

  final _records = <LogRecord>[];
  final _controller = StreamController<LogRecord>.broadcast();

  LogService._() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen(_onRecord);
  }

  static final LogService _instance = LogService._();
  static LogService get instance => _instance;

  /// Стрим по одной записи
  Stream<LogRecord> get stream => _controller.stream;

  /// Полный снапшот накопленных логов
  List<LogRecord> get records => List.unmodifiable(_records);

  void _onRecord(LogRecord record) {
    _records.add(record);
    if (_records.length > _maxEntries) {
      _records.removeAt(0);
    }
    _controller.add(record);
  }

  void setLevel(Level level) {
    Logger.root.level = level;
  }
}
