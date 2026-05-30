import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/log_entry.dart';
import 'package:omodscan_mobile/utils/modbus_traffic_format.dart';

Uint8List _frame(List<int> bytes) => Uint8List.fromList(bytes);

TrafficField _field(ModbusFrameInfo info, String label) =>
    info.fields.firstWhere((f) => f.label == label);

void main() {
  // The formatter reads the global address base; keep tests deterministic.
  setUp(() => AppSettings.instance.addressBase = AppSettings.addressBases.first);

  group('buildTrafficLogEntry', () {
    final readReq = _frame([
      0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0x01,
      0x03, 0x00, 0x00, 0x00, 0x02,
    ]);

    test('row data is hex-only and keeps the raw frame', () {
      final entry = buildTrafficLogEntry(
        frame: readReq,
        direction: LogDirection.tx,
        time: DateTime(2026, 5, 30, 10, 42, 31, 234),
      );

      expect(entry.function, '03 Read Holding Registers');
      expect(entry.time, '10:42:31.234');
      expect(entry.data, '00 01 00 00 00 06 01 03 00 00 00 02');
      expect(entry.data, isNot(contains('Addr')));
      expect(entry.data, isNot(contains('\n')));
      expect(entry.frame, readReq);
    });

    test('marks exception responses as errors', () {
      final entry = buildTrafficLogEntry(
        frame: _frame([0x00, 0x01, 0x00, 0x00, 0x00, 0x03, 0x01, 0x83, 0x02]),
        direction: LogDirection.rx,
        time: DateTime(2026, 5, 30),
      );
      expect(entry.function, 'Exception Response');
      expect(entry.type, LogEntryType.error);
    });
  });

  group('describeModbusFrame', () {
    test('decodes MBAP + read request fields', () {
      final info = describeModbusFrame(
        _frame([
          0x00, 0x07, 0x00, 0x00, 0x00, 0x06, 0x01,
          0x03, 0x00, 0x00, 0x00, 0x14,
        ]),
        LogDirection.tx,
      );

      expect(info.transactionId, 0x0007);
      expect(info.protocolId, 0x0000);
      expect(info.length, 0x0006);
      expect(info.unitId, 1);
      expect(info.functionCode, 0x03);
      expect(info.functionLabel, '03 Read Holding Registers');
      expect(info.isException, isFalse);
      expect(_field(info, 'Start address').value, '0');
      expect(_field(info, 'Quantity').value, '20');
    });

    test('decodes read response values', () {
      final info = describeModbusFrame(
        _frame([
          0x00, 0x01, 0x00, 0x00, 0x00, 0x07, 0x01,
          0x03, 0x04, 0x00, 0x7B, 0x00, 0x2D, // 123, 45
        ]),
        LogDirection.rx,
      );
      expect(_field(info, 'Byte count').value, '4');
      expect(_field(info, 'Values').value, '123, 45');
    });

    test('decodes write single register', () {
      final info = describeModbusFrame(
        _frame([
          0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0x01,
          0x06, 0x00, 0x09, 0x00, 0x7B,
        ]),
        LogDirection.tx,
      );
      expect(info.functionLabel, '06 Write Single Register');
      expect(_field(info, 'Address').value, '9');
      expect(_field(info, 'Value').value, '123');
    });

    test('decodes write single coil ON/OFF', () {
      final info = describeModbusFrame(
        _frame([
          0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0x01,
          0x05, 0x00, 0x02, 0xFF, 0x00,
        ]),
        LogDirection.tx,
      );
      expect(info.functionLabel, '05 Write Single Coil');
      expect(_field(info, 'Value').value, 'ON');
    });

    test('decodes exception code and description', () {
      final info = describeModbusFrame(
        _frame([0x00, 0x01, 0x00, 0x00, 0x00, 0x03, 0x01, 0x83, 0x02]),
        LogDirection.rx,
      );
      expect(info.isException, isTrue);
      expect(info.functionCode, 0x83);
      expect(_field(info, 'Exception code').value, '0x02');
      expect(_field(info, 'Description').value, 'Illegal Data Address');
    });

    test('honours a 1-based address base', () {
      AppSettings.instance.addressBase = AppSettings.addressBases[1];
      addTearDown(
        () => AppSettings.instance.addressBase = AppSettings.addressBases.first,
      );

      final info = describeModbusFrame(
        _frame([
          0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0x01,
          0x03, 0x00, 0x00, 0x00, 0x02,
        ]),
        LogDirection.tx,
      );
      expect(_field(info, 'Start address').value, '1');
    });
  });
}
