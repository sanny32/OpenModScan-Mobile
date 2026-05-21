class RegisterEntry {
  final int address;
  final String value;
  final String typeName;
  final String? comment;

  const RegisterEntry({
    required this.address,
    required this.value,
    required this.typeName,
    this.comment,
  });
}

