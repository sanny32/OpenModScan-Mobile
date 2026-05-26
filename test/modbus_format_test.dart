import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/register_entry.dart';
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

  test('register word count matches type width', () {
    expect(registerWordCount('UInt16'), 1);
    expect(registerWordCount('Int16'), 1);
    expect(registerWordCount('Hex'), 1);
    expect(registerWordCount('Binary'), 1);
    expect(registerWordCount('UInt32'), 2);
    expect(registerWordCount('Int32'), 2);
    expect(registerWordCount('Float32'), 2);
    expect(registerWordCount('UInt64'), 4);
    expect(registerWordCount('Int64'), 4);
    expect(registerWordCount('Float64'), 4);
  });
}
