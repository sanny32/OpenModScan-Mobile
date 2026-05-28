enum RegisterAddressType {
  coils('0xxxx', 'Coils (0xxxx)', 0, isBit: true, canWrite: true),
  discreteInputs('1xxxx', 'Discrete Input (1xxxx)', 10000, isBit: true),
  inputRegisters('3xxxx', 'Input (3xxxx)', 30000),
  holdingRegisters('4xxxx', 'Holding (4xxxx)', 40000, canWrite: true);

  final String code;
  final String label;
  final int displayOffset;
  final bool isBit;
  final bool canWrite;

  const RegisterAddressType(
    this.code,
    this.label,
    this.displayOffset, {
    this.isBit = false,
    this.canWrite = false,
  });

  bool get supportsRegisterRead => !isBit;

  bool get supportsStatusRead => isBit;

  int toModbusAddress(int displayAddress, {int addressBase = 1}) {
    final firstDisplayAddress = displayOffset + addressBase;
    if (addressBase < 0 || addressBase > 1) {
      throw RangeError.value(addressBase, 'addressBase');
    }
    if (displayAddress < firstDisplayAddress) {
      throw RangeError.value(displayAddress, 'displayAddress');
    }
    return displayAddress - firstDisplayAddress;
  }

  static RegisterAddressType fromCode(
    String? code, {
    RegisterAddressType fallback = RegisterAddressType.holdingRegisters,
  }) {
    return tryParse(code) ?? fallback;
  }

  static RegisterAddressType? tryParse(String? code) {
    for (final type in RegisterAddressType.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}
