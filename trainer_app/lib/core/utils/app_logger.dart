import 'dart:collection';

enum LogTag { chat, rtc, schedule, auth, general }

class LogEntry {
  final LogTag tag;
  final String message;
  final DateTime timestamp;

  const LogEntry({
    required this.tag,
    required this.message,
    required this.timestamp,
  });

  @override
  String toString() => '[${tag.name.toUpperCase()}] ${timestamp.toIso8601String()} — $message';
}

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  final Queue<LogEntry> _logs = Queue();
  static const int _maxLogs = 20;

  void log(LogTag tag, String message) {
    final entry = LogEntry(tag: tag, message: message, timestamp: DateTime.now());
    if (_logs.length >= _maxLogs) _logs.removeFirst();
    _logs.addLast(entry);
  }

  void chat(String message) => log(LogTag.chat, message);
  void rtc(String message) => log(LogTag.rtc, message);
  void schedule(String message) => log(LogTag.schedule, message);
  void auth(String message) => log(LogTag.auth, message);

  List<LogEntry> get recentLogs => _logs.toList().reversed.toList();
}

final logger = AppLogger.instance;
