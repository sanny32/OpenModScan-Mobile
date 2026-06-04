import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/modbus_exception.dart';
import 'package:omodscan_mobile/services/modbus_client.dart';

void main() {
  test('Modbus exception codes expose documented labels', () {
    expect(ModbusExceptionCode.fromCode(0x01)?.label, 'Illegal Function');
    expect(ModbusExceptionCode.fromCode(0x02)?.label, 'Illegal Data Address');
    expect(ModbusExceptionCode.fromCode(0x03)?.label, 'Illegal Data Value');
    expect(ModbusExceptionCode.fromCode(0x04)?.label, 'Server Device Failure');
    expect(ModbusExceptionCode.fromCode(0x05)?.label, 'Acknowledge');
    expect(ModbusExceptionCode.fromCode(0x06)?.label, 'Server Device Busy');
    expect(ModbusExceptionCode.fromCode(0x07)?.label, 'Negative Acknowledge');
    expect(ModbusExceptionCode.fromCode(0x08)?.label, 'Memory Parity Error');
    expect(
      ModbusExceptionCode.fromCode(0x0A)?.label,
      'Gateway Path Unavailable',
    );
    expect(
      ModbusExceptionCode.fromCode(0x0B)?.label,
      'Gateway Target Device Failed To Respond',
    );
  });

  test('ModbusClientException can be created from exception code', () {
    final exception = ModbusClientException.modbus(
      ModbusExceptionCode.illegalDataAddress,
    );

    expect(exception.message, 'Illegal Data Address');
    expect(exception.exceptionCode, ModbusExceptionCode.illegalDataAddress);
  });
}
