class StatusEntry {
  final int address;
  final bool value;
  final String comment;

  const StatusEntry({
    required this.address,
    required this.value,
    required this.comment,
  });

  StatusEntry copyWith({bool? value}) => StatusEntry(
    address: address,
    value: value ?? this.value,
    comment: comment,
  );
}
