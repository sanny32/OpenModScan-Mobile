class StatusEntry {
  final int address; // linear display address, used as the lookup/matching key
  final int? displayAddress; // type-formatted reference shown to the user
  final bool value;
  final bool? previousValue;
  final String comment;
  final String? timestamp;
  final String? date;

  const StatusEntry({
    required this.address,
    this.displayAddress,
    required this.value,
    this.previousValue,
    required this.comment,
    this.timestamp,
    this.date,
  });

  StatusEntry copyWith({bool? value}) => StatusEntry(
    address: address,
    displayAddress: displayAddress,
    value: value ?? this.value,
    previousValue: previousValue,
    comment: comment,
    timestamp: timestamp,
    date: date,
  );
}
