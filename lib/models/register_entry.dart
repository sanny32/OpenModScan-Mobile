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

int registerWordCount(String typeName) {
  switch (typeName) {
    case 'UInt32':
    case 'Int32':
    case 'Float32':
      return 2;
    case 'UInt64':
    case 'Int64':
    case 'Float64':
      return 4;
    default:
      return 1;
  }
}

enum RegisterValueState { received, unavailable, exception }

class RegisterEntry {
  final int address;
  final String value; // raw uint16 as decimal string
  final String? displayValue; // type-formatted value for display in list
  final String? previousValue;
  final RegisterValueState valueState;
  final String typeName;
  final String? comment;
  final String? timestamp;
  final String? date;
  // Raw uint16 values for this and neighbouring registers (needed for multi-word types).
  final Map<int, int> rawWords;

  const RegisterEntry({
    required this.address,
    required this.value,
    this.displayValue,
    this.previousValue,
    this.valueState = RegisterValueState.received,
    required this.typeName,
    this.comment,
    this.timestamp,
    this.date,
    this.rawWords = const {},
  });
}
