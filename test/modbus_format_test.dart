import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/utils/modbus_format.dart';

void main() {
  test('formats registers without widget state', () {
    final formatted = computeDisplayValue(
      40001,
      'UInt32',
      {40001: 1, 40002: 2},
      registerOrder: 'MSRF',
      byteOrder: 'Direct',
    );

    expect(formatted, '65538');
  });
}
