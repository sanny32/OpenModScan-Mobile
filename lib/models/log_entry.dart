import 'dart:typed_data';

enum LogDirection { tx, rx }

enum LogEntryType { normal, error }

class LogEntry {
  final String time;
  final LogDirection? direction;
  final String function;
  final String data;
  final LogEntryType type;

  /// Raw ADU frame bytes (MBAP header + PDU), when available. Used by the
  /// traffic detail screen to decode the full breakdown.
  final Uint8List? frame;

  const LogEntry({
    required this.time,
    this.direction,
    required this.function,
    required this.data,
    this.type = LogEntryType.normal,
    this.frame,
  });
}
