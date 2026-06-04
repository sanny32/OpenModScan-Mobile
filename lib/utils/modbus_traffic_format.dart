import 'dart:typed_data';

import '../models/app_settings.dart';
import '../models/log_entry.dart';
import '../models/modbus_exception.dart';
import 'modbus_crc.dart';

/// A single decoded label/value pair from a Modbus PDU.
class TrafficField {
  final String label;
  final String value;
  const TrafficField(this.label, this.value);
}

/// Structured breakdown of a raw Modbus ADU frame, used by the traffic detail
/// screen.
class ModbusFrameInfo {
  final LogFrameKind frameKind;
  final int? transactionId;
  final int? protocolId;
  final int? length;
  final int? unitId;
  final int? functionCode;
  final String functionLabel;
  final bool isException;
  final int? crc;
  final bool? crcValid;
  final List<TrafficField> fields;

  const ModbusFrameInfo({
    required this.frameKind,
    required this.transactionId,
    required this.protocolId,
    required this.length,
    required this.unitId,
    required this.functionCode,
    required this.functionLabel,
    required this.isException,
    required this.crc,
    required this.crcValid,
    required this.fields,
  });

  bool get isRtu => frameKind == LogFrameKind.modbusRtu;
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
  LogFrameKind frameKind = LogFrameKind.modbusTcp,
}) {
  final isError = _isException(frame, frameKind);
  return LogEntry(
    time: formatTrafficTime(time),
    direction: direction,
    function: isError ? 'Exception Response' : _functionLabel(frame, frameKind),
    data: formatHexBytes(frame),
    type: isError ? LogEntryType.error : LogEntryType.normal,
    frame: frame,
    frameKind: frameKind,
  );
}

/// Builds the full structured breakdown (MBAP header + decoded PDU fields).
ModbusFrameInfo describeModbusFrame(
  Uint8List frame,
  LogDirection direction, {
  LogFrameKind frameKind = LogFrameKind.modbusTcp,
}) {
  int? at16(int offset) => frame.length >= offset + 2
      ? (frame[offset] << 8) | frame[offset + 1]
      : null;

  final crc = frameKind == LogFrameKind.modbusRtu && frame.length >= 2
      ? frame[frame.length - 2] | (frame[frame.length - 1] << 8)
      : null;
  final crcValid = frameKind == LogFrameKind.modbusRtu && frame.length >= 4
      ? rtuCrcValid(frame)
      : null;

  return ModbusFrameInfo(
    frameKind: frameKind,
    transactionId: frameKind == LogFrameKind.modbusTcp ? at16(0) : null,
    protocolId: frameKind == LogFrameKind.modbusTcp ? at16(2) : null,
    length: frameKind == LogFrameKind.modbusTcp ? at16(4) : null,
    unitId: _unitId(frame, frameKind),
    functionCode: _functionCode(frame, frameKind),
    functionLabel: _functionLabel(frame, frameKind),
    isException: _isException(frame, frameKind),
    crc: crc,
    crcValid: crcValid,
    fields: _decodeFields(frame, direction, frameKind),
  );
}

/// Joins the decoded PDU fields into a single compact line, e.g.
/// `Start address: 0    Quantity: 20`. Empty when nothing is decoded.
String trafficDetailText(
  Uint8List frame,
  LogDirection direction, {
  LogFrameKind frameKind = LogFrameKind.modbusTcp,
}) => _decodeFields(
  frame,
  direction,
  frameKind,
).map((f) => '${f.label}: ${f.value}').join('    ');

/// Resolves the raw frame bytes for a log [entry]: the captured [LogEntry.frame]
/// when present, otherwise the hex parsed from the first line of its data.
/// Returns an empty list for entries without a decodable frame (e.g. errors),
/// which the UI uses to decide whether a detail screen can be opened.
Uint8List frameForEntry(LogEntry entry) =>
    entry.frame ?? parseHexBytes(entry.data.split('\n').first);

/// Formats bytes as space-separated, upper-case, two-digit hex, e.g.
/// `00 01 00 00 00 06 01 03`.
String formatHexBytes(Iterable<int> bytes) => bytes
    .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
    .join(' ');

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

int _pduOffset(LogFrameKind frameKind) =>
    frameKind == LogFrameKind.modbusTcp ? _kMbapLen : 1;

int? _unitId(Uint8List frame, LogFrameKind frameKind) {
  if (frameKind == LogFrameKind.modbusTcp) {
    return frame.length > 6 ? frame[6] : null;
  }
  return frame.isNotEmpty ? frame[0] : null;
}

int? _functionCode(Uint8List frame, LogFrameKind frameKind) {
  final offset = _pduOffset(frameKind);
  return frame.length > offset ? frame[offset] : null;
}

bool _isException(Uint8List frame, LogFrameKind frameKind) {
  final fc = _functionCode(frame, frameKind);
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

String _functionLabel(Uint8List frame, LogFrameKind frameKind) {
  final fc = _functionCode(frame, frameKind);
  if (fc == null) return 'Unknown';
  final code = fc & 0x7f;
  final name = _functionNames[code];
  final hexCode = code.toRadixString(16).toUpperCase().padLeft(2, '0');
  return name == null ? hexCode : '$hexCode $name';
}

/// PDU view (function code at index 0).
ByteData? _pdu(Uint8List frame, LogFrameKind frameKind) {
  final offset = _pduOffset(frameKind);
  final checksumLen = frameKind == LogFrameKind.modbusRtu ? 2 : 0;
  if (frame.length <= offset + checksumLen) return null;
  return ByteData.sublistView(frame, offset, frame.length - checksumLen);
}

String _displayAddress(int rawAddress) =>
    (rawAddress + AppSettings.instance.addressBaseStart).toString();

List<TrafficField> _decodeFields(
  Uint8List frame,
  LogDirection direction,
  LogFrameKind frameKind,
) {
  final pdu = _pdu(frame, frameKind);
  if (pdu == null) return const [];
  final fc = pdu.getUint8(0);
  final fields = <TrafficField>[];

  if ((fc & 0x80) != 0) {
    if (pdu.lengthInBytes < 2) return fields;
    final code = pdu.getUint8(1);
    final exception = ModbusExceptionCode.fromCode(code);
    fields.addAll([
      TrafficField(
        'Exception code',
        '0x${code.toRadixString(16).toUpperCase().padLeft(2, '0')}',
      ),
      TrafficField('Description', exception?.label ?? 'Unknown exception'),
    ]);
    return fields;
  }

  fields.addAll(switch (fc) {
    0x01 || 0x02 || 0x03 || 0x04 =>
      direction == LogDirection.tx
          ? _readRequestFields(pdu)
          : _readResponseFields(pdu, isBits: fc == 0x01 || fc == 0x02),
    0x05 => _writeSingleCoilFields(pdu),
    0x06 => _writeSingleRegisterFields(pdu),
    0x0F || 0x10 => _addressQuantityFields(pdu),
    _ => const [],
  });
  return fields;
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
