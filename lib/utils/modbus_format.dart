import 'dart:typed_data';

import '../models/app_settings.dart';

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

    case 'Int16': {
      final v = r(address);
      return (v > 32767 ? v - 65536 : v).toString();
    }

    case 'Hex':
      return '0x${r(address).toRadixString(16).toUpperCase().padLeft(4, '0')}';

    case 'Binary': {
      final bin = r(address).toRadixString(2).padLeft(16, '0');
      return '${bin.substring(0, 4)} ${bin.substring(4, 8)} '
          '${bin.substring(8, 12)} ${bin.substring(12)}';
    }

    case 'UInt32':
    case 'Int32':
    case 'Float32': {
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
    case 'Float64': {
      final regs = List.generate(4, (i) => r(address + i));
      final ordered =
          regOrder == 'MSRF' ? regs : regs.reversed.toList();
      final bd = ByteData(8);
      for (var i = 0; i < 4; i++) {
        bd.setUint16(i * 2, ordered[i], Endian.big);
      }
      if (typeName == 'Float64') return formatFloat(bd.getFloat64(0, Endian.big));
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
