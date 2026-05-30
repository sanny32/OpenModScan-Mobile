import 'dart:typed_data';

import '../models/app_settings.dart';
import '../models/log_entry.dart';
import '../models/modbus_exception.dart';

/// A single decoded label/value pair from a Modbus PDU.
class TrafficField {
  final String label;
  final String value;
  const TrafficField(this.label, this.value);
}

/// Structured breakdown of a raw Modbus TCP ADU frame, used by the traffic
/// detail screen.
class ModbusFrameInfo {
  final int? transactionId;
  final int? protocolId;
  final int? length;
  final int? unitId;
  final int? functionCode;
  final String functionLabel;
  final bool isException;
  final List<TrafficField> fields;

  const ModbusFrameInfo({
    required this.transactionId,
    required this.protocolId,
    required this.length,
    required this.unitId,
    required this.functionCode,
    required this.functionLabel,
    required this.isException,
    required this.fields,
  });
}

/// Decodes a raw Modbus TCP ADU frame (MBAP header + PDU) into a [LogEntry]
/// suitable for the traffic screen. The row only carries the hex dump; the full
/// decoded breakdown is produced on demand by [describeModbusFrame].
///
/// The frame layout is:
/// ```
/// [0..1] Transaction ID   [2..3] Protocol ID   [4..5] Length
/// [6]    Unit ID          [7]    Function code  [8..]  PDU data
/// ```
LogEntry buildTrafficLogEntry({
  required Uint8List frame,
  required LogDirection direction,
  required DateTime time,
}) {
  final isError = _isException(frame);
  return LogEntry(
    time: formatTrafficTime(time),
    direction: direction,
    function: isError ? 'Exception Response' : _functionLabel(frame),
    data: formatHexBytes(frame),
    type: isError ? LogEntryType.error : LogEntryType.normal,
    frame: frame,
  );
}

/// Builds the full structured breakdown (MBAP header + decoded PDU fields).
ModbusFrameInfo describeModbusFrame(Uint8List frame, LogDirection direction) {
  int? at16(int offset) =>
      frame.length >= offset + 2 ? (frame[offset] << 8) | frame[offset + 1] : null;

  return ModbusFrameInfo(
    transactionId: at16(0),
    protocolId: at16(2),
    length: at16(4),
    unitId: frame.length > 6 ? frame[6] : null,
    functionCode: _functionCode(frame),
    functionLabel: _functionLabel(frame),
    isException: _isException(frame),
    fields: _decodeFields(frame, direction),
  );
}

/// Joins the decoded PDU fields into a single compact line, e.g.
/// `Start address: 0    Quantity: 20`. Empty when nothing is decoded.
String trafficDetailText(Uint8List frame, LogDirection direction) =>
    _decodeFields(frame, direction)
        .map((f) => '${f.label}: ${f.value}')
        .join('    ');

/// Formats bytes as space-separated, upper-case, two-digit hex, e.g.
/// `00 01 00 00 00 06 01 03`.
String formatHexBytes(Iterable<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');

/// Parses a hex string such as `00 01 0A FF` back into bytes. Returns an empty
/// list when the string contains no valid hex tokens.
Uint8List parseHexBytes(String hex) {
  final bytes = <int>[];
  for (final token in hex.trim().split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    final value = int.tryParse(token, radix: 16);
    if (value == null) return Uint8List(0);
    bytes.add(value);
  }
  return Uint8List.fromList(bytes);
}

/// Formats a timestamp as `HH:mm:ss.SSS` to match [LogEntry.time].
String formatTrafficTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}:'
    '${t.second.toString().padLeft(2, '0')}.'
    '${t.millisecond.toString().padLeft(3, '0')}';

const _kMbapLen = 7;

int? _functionCode(Uint8List frame) =>
    frame.length > _kMbapLen ? frame[_kMbapLen] : null;

bool _isException(Uint8List frame) {
  final fc = _functionCode(frame);
  return fc != null && (fc & 0x80) != 0;
}

const _functionNames = <int, String>{
  0x01: 'Read Coils',
  0x02: 'Read Discrete Inputs',
  0x03: 'Read Holding Registers',
  0x04: 'Read Input Registers',
  0x05: 'Write Single Coil',
  0x06: 'Write Single Register',
  0x0F: 'Write Multiple Coils',
  0x10: 'Write Multiple Registers',
};

String _functionLabel(Uint8List frame) {
  final fc = _functionCode(frame);
  if (fc == null) return 'Unknown';
  final code = fc & 0x7f;
  final name = _functionNames[code];
  final hexCode = code.toRadixString(16).toUpperCase().padLeft(2, '0');
  return name == null ? hexCode : '$hexCode $name';
}

/// PDU view starting just after the MBAP header (i.e. function code at index 0).
ByteData? _pdu(Uint8List frame) {
  if (frame.length <= _kMbapLen) return null;
  return ByteData.sublistView(frame, _kMbapLen);
}

String _displayAddress(int rawAddress) =>
    (rawAddress + AppSettings.instance.addressBaseStart).toString();

List<TrafficField> _decodeFields(Uint8List frame, LogDirection direction) {
  final pdu = _pdu(frame);
  if (pdu == null) return const [];
  final fc = pdu.getUint8(0);

  // Exception response: function code + 0x80, then exception code.
  if ((fc & 0x80) != 0) {
    if (pdu.lengthInBytes < 2) return const [];
    final code = pdu.getUint8(1);
    final exception = ModbusExceptionCode.fromCode(code);
    return [
      TrafficField('Exception code', '0x${code.toRadixString(16).toUpperCase().padLeft(2, '0')}'),
      TrafficField('Description', exception?.label ?? 'Unknown exception'),
    ];
  }

  return switch (fc) {
    0x01 || 0x02 || 0x03 || 0x04 =>
      direction == LogDirection.tx
          ? _readRequestFields(pdu)
          : _readResponseFields(pdu, isBits: fc == 0x01 || fc == 0x02),
    0x05 => _writeSingleCoilFields(pdu),
    0x06 => _writeSingleRegisterFields(pdu),
    // Write multiple req/resp both start with start-address + quantity.
    0x0F || 0x10 => _addressQuantityFields(pdu),
    _ => const [],
  };
}

List<TrafficField> _readRequestFields(ByteData pdu) {
  if (pdu.lengthInBytes < 5) return const [];
  return [
    TrafficField('Start address', _displayAddress(pdu.getUint16(1))),
    TrafficField('Quantity', '${pdu.getUint16(3)}'),
  ];
}

List<TrafficField> _readResponseFields(ByteData pdu, {required bool isBits}) {
  if (pdu.lengthInBytes < 2) return const [];
  final byteCount = pdu.getUint8(1);
  final available = pdu.lengthInBytes - 2;
  final count = byteCount <= available ? byteCount : available;
  final values = <int>[];
  if (isBits) {
    for (var i = 0; i < count; i++) {
      final byte = pdu.getUint8(2 + i);
      for (var bit = 0; bit < 8; bit++) {
        values.add((byte >> bit) & 0x01);
      }
    }
  } else {
    for (var i = 0; i + 1 < count; i += 2) {
      values.add(pdu.getUint16(2 + i));
    }
  }
  return [
    TrafficField('Byte count', '$byteCount'),
    TrafficField('Values', values.join(', ')),
  ];
}

List<TrafficField> _writeSingleRegisterFields(ByteData pdu) {
  if (pdu.lengthInBytes < 5) return const [];
  return [
    TrafficField('Address', _displayAddress(pdu.getUint16(1))),
    TrafficField('Value', '${pdu.getUint16(3)}'),
  ];
}

List<TrafficField> _writeSingleCoilFields(ByteData pdu) {
  if (pdu.lengthInBytes < 5) return const [];
  final on = pdu.getUint16(3) == 0xFF00;
  return [
    TrafficField('Address', _displayAddress(pdu.getUint16(1))),
    TrafficField('Value', on ? 'ON' : 'OFF'),
  ];
}

List<TrafficField> _addressQuantityFields(ByteData pdu) {
  if (pdu.lengthInBytes < 5) return const [];
  return [
    TrafficField('Start address', _displayAddress(pdu.getUint16(1))),
    TrafficField('Quantity', '${pdu.getUint16(3)}'),
  ];
}
