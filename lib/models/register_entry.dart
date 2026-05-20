enum RegisterQuality { good, bad, uncertain }

class RegisterEntry {
  final int address;
  final String value;
  final String typeName;
  final RegisterQuality quality;

  const RegisterEntry({
    required this.address,
    required this.value,
    required this.typeName,
    this.quality = RegisterQuality.good,
  });
}

const mockRegisters = [
  RegisterEntry(address: 40001, value: '123', typeName: 'UInt16'),
  RegisterEntry(address: 40002, value: '45.6', typeName: 'Float'),
  RegisterEntry(address: 40003, value: '78.9', typeName: 'Float'),
  RegisterEntry(address: 40004, value: '1', typeName: 'Bool'),
  RegisterEntry(address: 40005, value: '1000', typeName: 'UInt32'),
  RegisterEntry(address: 40006, value: '-12.34', typeName: 'Float'),
  RegisterEntry(address: 40007, value: '32767', typeName: 'Int16'),
  RegisterEntry(address: 40008, value: '0', typeName: 'UInt16'),
  RegisterEntry(address: 40009, value: '25.0', typeName: 'Float'),
  RegisterEntry(address: 40010, value: '65535', typeName: 'UInt16'),
];
