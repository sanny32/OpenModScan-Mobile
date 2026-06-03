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
    if (addressBase < 0 || addressBase > 1) {
      throw RangeError.value(addressBase, 'addressBase');
    }
    final firstDisplayAddress = displayOffset + addressBase;
    if (displayAddress < firstDisplayAddress) {
      throw RangeError.value(displayAddress, 'displayAddress');
    }
    return displayAddress - firstDisplayAddress;
  }

  /// Largest register/bit offset that still fits the classic 5-digit Modicon
  /// reference (e.g. holding 40000–49999).
  static const maxFiveDigitOffset = 9999;

  /// Formats a linear display address (as produced by [toDisplayAddress]:
  /// `displayOffset + addressBase + offset`) for presentation.
  ///
  /// The classic 5-digit Modicon reference is used while the offset fits
  /// (≤ [maxFiveDigitOffset]); past that it switches to the 6-digit reference
  /// (e.g. holding 400000–465535) so the leading type digit is preserved across
  /// the full 16-bit address space instead of overflowing it (40000 + 65000
  /// would otherwise read as 105000).
  int toReferenceDisplay(int displayAddress) {
    final offset = displayAddress - displayOffset;
    if (offset <= maxFiveDigitOffset) return displayAddress;
    return displayOffset * 10 + offset;
  }

  int toDisplayAddress(int modbusAddress, {int addressBase = 1}) {
    if (addressBase < 0 || addressBase > 1) {
      throw RangeError.value(addressBase, 'addressBase');
    }
    if (modbusAddress < 0) {
      throw RangeError.value(modbusAddress, 'modbusAddress');
    }
    return displayOffset + addressBase + modbusAddress;
  }

  int toCanonicalAddress(int displayAddress, {int addressBase = 1}) =>
      displayOffset + toModbusAddress(displayAddress, addressBase: addressBase);

  int canonicalAddressToDisplay(int canonicalAddress, {int addressBase = 1}) {
    final modbusAddress = toModbusAddress(canonicalAddress, addressBase: 0);
    return toDisplayAddress(modbusAddress, addressBase: addressBase);
  }

  int? tryCanonicalAddressToDisplay(
    int canonicalAddress, {
    int addressBase = 1,
  }) {
    try {
      return canonicalAddressToDisplay(
        canonicalAddress,
        addressBase: addressBase,
      );
    } on RangeError {
      return null;
    }
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
