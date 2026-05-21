const kRegisterTypes = [
  'UInt16',
  'Int16',
  'UInt32',
  'Int32',
  'UInt64',
  'Int64',
  'Float32',
  'Float64',
  'Hex',
  'Binary',
];

class RegisterEntry {
  final int address;
  final String value;        // raw uint16 as decimal string
  final String? displayValue; // type-formatted value for display in list
  final String? previousValue;
  final String typeName;
  final String? comment;
  final String? timestamp;
  final String? date;

  const RegisterEntry({
    required this.address,
    required this.value,
    this.displayValue,
    this.previousValue,
    required this.typeName,
    this.comment,
    this.timestamp,
    this.date,
  });
}
