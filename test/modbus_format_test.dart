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

  test('encodes integer values as inverse of display formatting', () {
    final cases = <String, String>{
      'UInt16': '65535',
      'Int16': '-1',
      'UInt32': '65538',
      'Int32': '-2',
      'UInt64': '4294967298',
      'Int64': '-2',
      'Hex': '0x0102',
      'Binary': '0000 0001 0000 0010',
    };

    for (final entry in cases.entries) {
      final words = encodeRegisterValue(
        entry.key,
        entry.value,
        registerOrder: 'MSRF',
        byteOrder: 'Direct',
      );
      final raw = {for (var i = 0; i < words.length; i++) 40001 + i: words[i]};

      expect(
        computeDisplayValue(
          40001,
          entry.key,
          raw,
          registerOrder: 'MSRF',
          byteOrder: 'Direct',
        ),
        entry.key == 'Binary' ? '0000 0001 0000 0010' : entry.value,
      );
    }
  });

  test('encodes register and byte order for multi-word values', () {
    final words = encodeRegisterValue(
      'UInt32',
      '16909060',
      registerOrder: 'LSRF',
      byteOrder: 'Swapped',
    );

    expect(words, [0x0403, 0x0201]);
    expect(
      computeDisplayValue(
        40001,
        'UInt32',
        {40001: words[0], 40002: words[1]},
        registerOrder: 'LSRF',
        byteOrder: 'Swapped',
      ),
      '16909060',
    );
  });

  test('encodes float values as inverse of display formatting', () {
    final words = encodeRegisterValue(
      'Float32',
      '1.5',
      registerOrder: 'MSRF',
      byteOrder: 'Direct',
    );

    expect(
      computeDisplayValue(
        40001,
        'Float32',
        {40001: words[0], 40002: words[1]},
        registerOrder: 'MSRF',
        byteOrder: 'Direct',
      ),
      '1.5',
    );
  });

  test('rejects invalid typed values', () {
    expect(() => encodeRegisterValue('UInt16', '-1'), throwsFormatException);
    expect(() => encodeRegisterValue('Int16', '32768'), throwsFormatException);
    expect(() => encodeRegisterValue('Float32', 'NaN'), throwsFormatException);
    expect(() => encodeRegisterValue('Hex', '0x10000'), throwsFormatException);
    expect(() => encodeRegisterValue('Binary', '101'), throwsFormatException);
  });
}
