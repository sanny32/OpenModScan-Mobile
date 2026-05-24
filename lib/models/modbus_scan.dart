enum ModbusScanRequestType {
  coils,
  discreteInputs,
  holdingRegisters,
  inputRegisters,
}

extension ModbusScanRequestTypeX on ModbusScanRequestType {
  int get functionCode => switch (this) {
    ModbusScanRequestType.coils => 1,
    ModbusScanRequestType.discreteInputs => 2,
    ModbusScanRequestType.holdingRegisters => 3,
    ModbusScanRequestType.inputRegisters => 4,
  };

  bool get isBitRead => switch (this) {
    ModbusScanRequestType.coils || ModbusScanRequestType.discreteInputs => true,
    ModbusScanRequestType.holdingRegisters ||
    ModbusScanRequestType.inputRegisters => false,
  };

  static ModbusScanRequestType fromName(String? value) {
    return ModbusScanRequestType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ModbusScanRequestType.holdingRegisters,
    );
  }
}
