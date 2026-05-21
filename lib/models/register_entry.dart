class RegisterEntry {
  final int address;
  final String value;
  final String? previousValue;
  final String typeName;
  final String? comment;

  const RegisterEntry({
    required this.address,
    required this.value,
    this.previousValue,
    required this.typeName,
    this.comment,
  });
}

