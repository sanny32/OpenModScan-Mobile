import 'package:flutter/services.dart';

class MaxCountFormatter extends TextInputFormatter {
  final int? max;
  final int min;

  const MaxCountFormatter({this.max = 125, this.min = 0});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final n = int.tryParse(newValue.text);
    if (n == null || n < min || (max != null && n > max!)) return oldValue;
    return newValue;
  }
}
