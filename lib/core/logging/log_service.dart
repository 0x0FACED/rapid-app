// lib/core/logging/log_service.dart
import 'dart:async';
import 'package:logging/logging.dart';

class LogService {
  static const int _maxEntries = 1000;

  final _records = <LogRecord>[];
  final _controller = StreamController<List<LogRecord>>.broadcast();

  LogService._() {
    // Включаем и настраиваем root-логгер
    Logger.root.level = Level.ALL; // потом можно менять динамически
    Logger.root.onRecord.listen(_onRecord);
  }

  static final LogService _instance = LogService._();
  static LogService get instance => _instance;

  Stream<List<LogRecord>> get stream => _controller.stream;
  List<LogRecord> get records => List.unmodifiable(_records);

  void _onRecord(LogRecord record) {
    _records.add(record);
    if (_records.length > _maxEntries) {
      _records.removeAt(0);
    }
    _controller.add(List.unmodifiable(_records));
  }

  // Позволяет менять уровень логирования "на лету"
  void setLevel(Level level) {
    Logger.root.level = level;
  }
}
