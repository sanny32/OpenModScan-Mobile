import 'package:flutter/material.dart';

/// Keyboard type for entering a register value of the given Modbus data type:
/// Hex needs letters, floats need a decimal point and sign, signed integers
/// need a sign, everything else is digits only.
TextInputType valueKeyboardTypeFor(String type) {
  switch (type) {
    case 'Hex':
      return TextInputType.text;
    case 'Float32':
    case 'Float64':
      return const TextInputType.numberWithOptions(signed: true, decimal: true);
    case 'Int16':
    case 'Int32':
    case 'Int64':
      return const TextInputType.numberWithOptions(signed: true);
    default:
      return TextInputType.number;
  }
}
