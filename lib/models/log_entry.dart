import 'dart:typed_data';

enum LogDirection { tx, rx }

enum LogEntryType { normal, error }

enum LogFrameKind { modbusTcp, modbusRtu }

class LogEntry {
  final String time;
  final LogDirection? direction;
  final String function;
  final String data;
  final LogEntryType type;

  /// Raw ADU frame bytes (MBAP header + PDU), when available. Used by the
  /// traffic detail screen to decode the full breakdown.
  final Uint8List? frame;

  /// Transport frame shape for [frame]. TCP frames contain MBAP + PDU; RTU
  /// frames contain unit id + PDU + CRC16.
  final LogFrameKind frameKind;

  const LogEntry({
    required this.time,
    this.direction,
    required this.function,
    required this.data,
    this.type = LogEntryType.normal,
    this.frame,
    this.frameKind = LogFrameKind.modbusTcp,
  });
}
