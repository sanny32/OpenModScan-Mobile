const kRegisterTypes = [
  'UInt16',
  'Int16',
  'UInt32',
  'Int32',
  'Float',
  'Double',
  'Bool',
];

class RegisterEntry {
  final int address;
  final String value;
  final String? previousValue;
  final String typeName;
  final String? comment;
  final String? timestamp;

  const RegisterEntry({
    required this.address,
    required this.value,
    this.previousValue,
    required this.typeName,
    this.comment,
    this.timestamp,
  });
}

