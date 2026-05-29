/// Latest read/written value for a register address, with the prior value and
/// the moment it was captured. Replaces the positional `(String, String?,
/// DateTime?)` tuple for readability at call sites.
typedef RegisterRuntimeValue = ({
  String value,
  String? previous,
  DateTime? readAt,
});

/// Latest read/written value for a status (coil/discrete) address.
typedef StatusRuntimeValue = ({bool value, bool? previous, DateTime? readAt});
