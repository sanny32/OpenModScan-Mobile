enum LogDirection { tx, rx }

enum LogEntryType { normal, error }

class LogEntry {
  final String time;
  final LogDirection? direction;
  final String function;
  final String data;
  final LogEntryType type;

  const LogEntry({
    required this.time,
    this.direction,
    required this.function,
    required this.data,
    this.type = LogEntryType.normal,
  });
}
