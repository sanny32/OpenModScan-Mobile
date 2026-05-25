import 'package:flutter/services.dart';

class MaxCountFormatter extends TextInputFormatter {
  final int max;

  const MaxCountFormatter({this.max = 125});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final n = int.tryParse(newValue.text);
    if (n == null || n > max) return oldValue;
    return newValue;
  }
}
