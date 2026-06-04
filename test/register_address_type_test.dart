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
    'converts one-based display register addresses to Modbus zero-based addresses',
    () {
      expect(RegisterAddressType.holdingRegisters.toModbusAddress(40001), 0);
      expect(RegisterAddressType.holdingRegisters.toModbusAddress(40010), 9);
      expect(RegisterAddressType.inputRegisters.toModbusAddress(30001), 0);
    },
  );

  test('converts zero-based display addresses to Modbus addresses', () {
    expect(
      RegisterAddressType.holdingRegisters.toModbusAddress(
        40000,
        addressBase: 0,
      ),
      0,
    );
    expect(
      RegisterAddressType.holdingRegisters.toModbusAddress(
        40001,
        addressBase: 0,
      ),
      1,
    );
    expect(RegisterAddressType.coils.toModbusAddress(0, addressBase: 0), 0);
    expect(RegisterAddressType.coils.toModbusAddress(1, addressBase: 0), 1);
  });

  test(
    'converts Modbus offsets and canonical addresses to display addresses',
    () {
      expect(
        RegisterAddressType.holdingRegisters.toDisplayAddress(
          0,
          addressBase: 0,
        ),
        40000,
      );
      expect(RegisterAddressType.holdingRegisters.toDisplayAddress(0), 40001);
      expect(
        RegisterAddressType.holdingRegisters.canonicalAddressToDisplay(
          40001,
          addressBase: 1,
        ),
        40002,
      );
      expect(
        RegisterAddressType.holdingRegisters.toCanonicalAddress(
          40001,
          addressBase: 1,
        ),
        40000,
      );
    },
  );

  test('safe canonical conversion ignores addresses from another type', () {
    expect(
      RegisterAddressType.holdingRegisters.tryCanonicalAddressToDisplay(30000),
      isNull,
    );
    expect(
      RegisterAddressType.holdingRegisters.tryCanonicalAddressToDisplay(40000),
      40001,
    );
  });

  test('rejects addresses below configured base', () {
    expect(
      () => RegisterAddressType.holdingRegisters.toModbusAddress(40000),
      throwsRangeError,
    );
    expect(
      () => RegisterAddressType.inputRegisters.toModbusAddress(30000),
      throwsRangeError,
    );
    expect(
      () => RegisterAddressType.coils.toModbusAddress(0),
      throwsRangeError,
    );
    expect(
      () => RegisterAddressType.discreteInputs.toModbusAddress(10000),
      throwsRangeError,
    );
    expect(
      () => RegisterAddressType.coils.toModbusAddress(-1, addressBase: 0),
      throwsRangeError,
    );
  });

  test(
    'formats display addresses as 5-digit Modicon while the offset fits',
    () {
      expect(
        RegisterAddressType.holdingRegisters.toReferenceDisplay(40000),
        40000,
      );
      expect(
        RegisterAddressType.holdingRegisters.toReferenceDisplay(49999),
        49999,
      );
      expect(
        RegisterAddressType.inputRegisters.toReferenceDisplay(30000),
        30000,
      );
      expect(
        RegisterAddressType.discreteInputs.toReferenceDisplay(19999),
        19999,
      );
      expect(RegisterAddressType.coils.toReferenceDisplay(9999), 9999);
    },
  );

  test('switches to 6-digit reference past the 9999 offset boundary', () {
    expect(
      RegisterAddressType.holdingRegisters.toReferenceDisplay(50000),
      410000,
    );
    expect(
      RegisterAddressType.holdingRegisters.toReferenceDisplay(105000),
      465000,
    );
    expect(
      RegisterAddressType.holdingRegisters.toReferenceDisplay(105535),
      465535,
    );
    expect(
      RegisterAddressType.inputRegisters.toReferenceDisplay(95000),
      365000,
    );
    expect(
      RegisterAddressType.discreteInputs.toReferenceDisplay(25000),
      115000,
    );
    expect(RegisterAddressType.coils.toReferenceDisplay(15000), 15000);
  });

  test('describes bit and writable address ranges', () {
    expect(RegisterAddressType.coils.isBit, isTrue);
    expect(RegisterAddressType.coils.canWrite, isTrue);
    expect(RegisterAddressType.discreteInputs.canWrite, isFalse);
    expect(RegisterAddressType.holdingRegisters.supportsRegisterRead, isTrue);
    expect(RegisterAddressType.inputRegisters.label, 'Input (3xxxx)');
  });
}
