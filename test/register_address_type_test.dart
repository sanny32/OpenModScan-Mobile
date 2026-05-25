import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/register_address_type.dart';

void main() {
  test('parses known register address type codes', () {
    expect(
      RegisterAddressType.fromCode('4xxxx'),
      RegisterAddressType.holdingRegisters,
    );
    expect(
      RegisterAddressType.fromCode('3xxxx'),
      RegisterAddressType.inputRegisters,
    );
    expect(
      RegisterAddressType.fromCode('1xxxx'),
      RegisterAddressType.discreteInputs,
    );
    expect(RegisterAddressType.fromCode('0xxxx'), RegisterAddressType.coils);
    expect(RegisterAddressType.tryParse('unknown'), isNull);
  });

  test(
    'converts display register addresses to Modbus zero-based addresses',
    () {
      expect(RegisterAddressType.holdingRegisters.toModbusAddress(40001), 0);
      expect(RegisterAddressType.holdingRegisters.toModbusAddress(40010), 9);
      expect(RegisterAddressType.inputRegisters.toModbusAddress(30001), 0);
    },
  );

  test('describes bit and writable address ranges', () {
    expect(RegisterAddressType.coils.isBit, isTrue);
    expect(RegisterAddressType.coils.canWrite, isTrue);
    expect(RegisterAddressType.discreteInputs.canWrite, isFalse);
    expect(RegisterAddressType.holdingRegisters.supportsRegisterRead, isTrue);
    expect(RegisterAddressType.inputRegisters.label, 'Input (3xxxx)');
  });
}
