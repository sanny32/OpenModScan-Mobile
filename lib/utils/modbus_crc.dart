import 'dart:typed_data';

/// Computes the Modbus RTU CRC16 (polynomial 0xA001) over [bytes].
///
/// Returns the two checksum bytes in transmission order (low byte first, then
/// high byte), matching how an RTU frame carries its trailing CRC.
Uint8List modbusCrc16(Iterable<int> bytes) {
  var crc = 0xffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      final lsb = crc & 1;
      crc >>= 1;
      if (lsb != 0) crc ^= 0xa001;
    }
  }
  return Uint8List.fromList([crc & 0xff, (crc >> 8) & 0xff]);
}

/// Returns true when the trailing two bytes of an RTU [frame] match the CRC16
/// computed over the preceding bytes. Frames shorter than 4 bytes are invalid.
bool rtuCrcValid(Uint8List frame) {
  if (frame.length < 4) return false;
  final crc = modbusCrc16(frame.sublist(0, frame.length - 2));
  return crc[0] == frame[frame.length - 2] && crc[1] == frame[frame.length - 1];
}
