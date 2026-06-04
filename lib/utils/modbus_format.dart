import 'dart:typed_data';

import '../models/app_settings.dart';
import '../models/register_entry.dart';

String formatModbusTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}:'
    '${value.second.toString().padLeft(2, '0')}';

String formatModbusDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.'
    '${value.year.toString().padLeft(4, '0')}';

String formatFloat(double f) {
  if (f.isNaN) return 'NaN';
  if (f.isInfinite) return f > 0 ? '+inf' : '-inf';
  if (f == 0.0) return '0';
  final abs = f.abs();
  if (abs < 0.001 || abs >= 1e7) return f.toStringAsExponential(6);
  return f.toStringAsPrecision(7).replaceAll(RegExp(r'\.?0+$'), '');
}

/// Formats a raw uint16 value (or multi-register value) according to [typeName].
///
/// [rawValues] maps register address → raw uint16 integer.
/// Uses global [AppSettings] for register/byte order unless overridden.
String computeDisplayValue(
  int address,
  String typeName,
  Map<int, int> rawValues, {
  String? registerOrder,
  String? byteOrder,
}) {
  final regOrder = registerOrder ?? AppSettings.instance.registerOrder;
  final byteOrd = byteOrder ?? AppSettings.instance.byteOrder;

  int applyByteSwap(int v) =>
      byteOrd == 'Swapped' ? ((v & 0xFF) << 8) | ((v >> 8) & 0xFF) : v;

  int r(int addr) => applyByteSwap(rawValues[addr] ?? 0);

  switch (typeName) {
    case 'UInt16':
      return r(address).toString();

    case 'Int16':
      {
        final v = r(address);
        return (v > 32767 ? v - 65536 : v).toString();
      }

    case 'Hex':
      return '0x${r(address).toRadixString(16).toUpperCase().padLeft(4, '0')}';

    case 'Binary':
      {
        final bin = r(address).toRadixString(2).padLeft(16, '0');
        return '${bin.substring(0, 4)} ${bin.substring(4, 8)} '
            '${bin.substring(8, 12)} ${bin.substring(12)}';
      }

    case 'UInt32':
    case 'Int32':
    case 'Float32':
      {
        final hi = regOrder == 'MSRF' ? r(address) : r(address + 1);
        final lo = regOrder == 'MSRF' ? r(address + 1) : r(address);
        if (typeName == 'Float32') {
          final bd = ByteData(4);
          bd.setUint16(0, hi, Endian.big);
          bd.setUint16(2, lo, Endian.big);
          return formatFloat(bd.getFloat32(0, Endian.big));
        }
        final combined = (hi << 16) | lo;
        if (typeName == 'UInt32') return combined.toString();
        return (combined > 0x7FFFFFFF ? combined - 0x100000000 : combined)
            .toString();
      }

    case 'UInt64':
    case 'Int64':
    case 'Float64':
      {
        final regs = List.generate(4, (i) => r(address + i));
        final ordered = regOrder == 'MSRF' ? regs : regs.reversed.toList();
        final bd = ByteData(8);
        for (var i = 0; i < 4; i++) {
          bd.setUint16(i * 2, ordered[i], Endian.big);
        }
        if (typeName == 'Float64') {
          return formatFloat(bd.getFloat64(0, Endian.big));
        }
        final high = bd.getUint32(0, Endian.big);
        final low = bd.getUint32(4, Endian.big);
        final val = (BigInt.from(high) << 32) | BigInt.from(low);
        if (typeName == 'UInt64') return val.toString();
        return val.toSigned(64).toString();
      }

    default:
      return (rawValues[address] ?? 0).toString();
  }
}

/// Encodes a typed user value into raw uint16 words in address order.
///
/// This is the inverse of [computeDisplayValue] for the register formats the UI
/// supports. The returned words are ready to write to consecutive Holding
/// registers, honoring the selected register and byte order.
List<int> encodeRegisterValue(
  String typeName,
  String input, {
  String? registerOrder,
  String? byteOrder,
}) {
  final regOrder = registerOrder ?? AppSettings.instance.registerOrder;
  final byteOrd = byteOrder ?? AppSettings.instance.byteOrder;
  final wordCount = registerWordCount(typeName);

  int applyByteSwap(int v) =>
      byteOrd == 'Swapped' ? ((v & 0xFF) << 8) | ((v >> 8) & 0xFF) : v;

  List<int> orderWords(List<int> mostSignificantFirst) {
    final ordered = regOrder == 'MSRF'
        ? mostSignificantFirst
        : mostSignificantFirst.reversed.toList();
    return ordered.map(applyByteSwap).toList();
  }

  switch (typeName) {
    case 'UInt16':
      return [applyByteSwap(_parseUnsigned(input, 16).toInt())];
    case 'Int16':
      return [applyByteSwap(_signedToUnsignedWords(input, 16, 1).single)];
    case 'Hex':
      return [applyByteSwap(_parseHexWord(input))];
    case 'Binary':
      return [applyByteSwap(_parseBinaryWord(input))];
    case 'UInt32':
      return orderWords(_unsignedWords(_parseUnsigned(input, 32), wordCount));
    case 'Int32':
      return orderWords(_signedToUnsignedWords(input, 32, wordCount));
    case 'UInt64':
      return orderWords(_unsignedWords(_parseUnsigned(input, 64), wordCount));
    case 'Int64':
      return orderWords(_signedToUnsignedWords(input, 64, wordCount));
    case 'Float32':
      return orderWords(_floatWords(input, 4));
    case 'Float64':
      return orderWords(_floatWords(input, 8));
    default:
      throw FormatException('Unsupported register type: $typeName');
  }
}

BigInt _parseInteger(String input) {
  final trimmed = input.trim();
  if (!RegExp(r'^[+-]?\d+$').hasMatch(trimmed)) {
    throw const FormatException('Enter a whole number.');
  }
  return BigInt.parse(trimmed);
}

BigInt _parseUnsigned(String input, int bits) {
  final value = _parseInteger(input);
  final max = (BigInt.one << bits) - BigInt.one;
  if (value < BigInt.zero || value > max) {
    throw FormatException('Value must be in range 0 – $max.');
  }
  return value;
}

List<int> _signedToUnsignedWords(String input, int bits, int wordCount) {
  final value = _parseInteger(input);
  final min = -(BigInt.one << (bits - 1));
  final max = (BigInt.one << (bits - 1)) - BigInt.one;
  if (value < min || value > max) {
    throw FormatException('Value must be in range $min – $max.');
  }
  final unsigned = value < BigInt.zero ? value + (BigInt.one << bits) : value;
  return _unsignedWords(unsigned, wordCount);
}

List<int> _unsignedWords(BigInt value, int wordCount) => [
  for (var i = wordCount - 1; i >= 0; i--)
    ((value >> (i * 16)) & BigInt.from(0xffff)).toInt(),
];

int _parseHexWord(String input) {
  final normalized = input.trim().replaceFirst(
    RegExp(r'^0x', caseSensitive: false),
    '',
  );
  if (!RegExp(r'^[0-9a-fA-F]{1,4}$').hasMatch(normalized)) {
    throw const FormatException('Enter 1-4 hex digits.');
  }
  return int.parse(normalized, radix: 16);
}

int _parseBinaryWord(String input) {
  final normalized = input.replaceAll(RegExp(r'\s+'), '');
  if (!RegExp(r'^[01]{16}$').hasMatch(normalized)) {
    throw const FormatException('Enter exactly 16 binary digits.');
  }
  return int.parse(normalized, radix: 2);
}

List<int> _floatWords(String input, int byteCount) {
  final value = double.tryParse(input.trim());
  if (value == null || value.isNaN || value.isInfinite) {
    throw const FormatException('Enter a finite number.');
  }
  final bd = ByteData(byteCount);
  if (byteCount == 4) {
    bd.setFloat32(0, value, Endian.big);
  } else {
    bd.setFloat64(0, value, Endian.big);
  }
  return [
    for (var offset = 0; offset < byteCount; offset += 2)
      bd.getUint16(offset, Endian.big),
  ];
}
