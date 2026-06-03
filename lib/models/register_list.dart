import 'register_address_type.dart';

class RegisterConfig {
  int address;
  String typeName;
  String? comment;

  RegisterConfig({
    required this.address,
    this.typeName = 'UInt16',
    this.comment,
  });

  RegisterConfig copyWith({
    int? address,
    String? typeName,
    String? comment,
    bool clearComment = false,
  }) => RegisterConfig(
    address: address ?? this.address,
    typeName: typeName ?? this.typeName,
    comment: clearComment ? null : comment ?? this.comment,
  );

  Map<String, dynamic> toJson() => {
    'address': address,
    'typeName': typeName,
    if (comment != null) 'comment': comment,
  };

  factory RegisterConfig.fromJson(Map<String, dynamic> json) => RegisterConfig(
    address: json['address'] as int,
    typeName: json['typeName'] as String? ?? 'UInt16',
    comment: json['comment'] as String?,
  );
}

class StatusConfig {
  String statusType;
  int address;
  String? comment;

  StatusConfig({
    required this.address,
    this.statusType = '0xxxx',
    this.comment,
  });

  StatusConfig copyWith({
    String? statusType,
    int? address,
    String? comment,
    bool clearComment = false,
  }) => StatusConfig(
    statusType: statusType ?? this.statusType,
    address: address ?? this.address,
    comment: clearComment ? null : comment ?? this.comment,
  );

  Map<String, dynamic> toJson() => {
    'statusType': statusType,
    'address': address,
    if (comment != null) 'comment': comment,
  };

  factory StatusConfig.fromJson(Map<String, dynamic> json) => StatusConfig(
    statusType: json['statusType'] as String? ?? '0xxxx',
    address: json['address'] as int,
    comment: json['comment'] as String?,
  );
}

const kMinRegisterRefreshIntervalMs = 100;
const kMaxRegisterRefreshIntervalMs = 60000;
const kDefaultRegisterRefreshIntervalMs = 1000;
const kStatusAddressModeDisplay = 'display';

/// Highest addressable Modbus register/bit (0-based, 16-bit address space).
const kMaxModbusAddress = 0xFFFF; // 65535
/// Size of the Modbus 16-bit address space (last valid address + 1).
const kModbusAddressSpace = 0x10000; // 65536
/// Maximum registers returned by a single Modbus read request.
const kMaxRegistersPerRead = 125;
/// Maximum bits (coils / discrete inputs) returned by a single Modbus read.
const kMaxBitsPerRead = 2000;

/// Largest read count that keeps `start + count - 1` within the address space,
/// capped by the per-request protocol limit.
int maxReadCountFor(int modbusStartAddress, {required int protocolLimit}) {
  final remaining = kModbusAddressSpace - modbusStartAddress;
  if (remaining < 1) return 1;
  return remaining < protocolLimit ? remaining : protocolLimit;
}

class RegisterList {
  String id;
  String name;
  String regType;
  String coilType;
  bool autoRefresh;
  int refreshIntervalMs;
  bool coilAutoRefresh;
  int coilRefreshIntervalMs;
  int startAddress;
  int count;
  int coilStartAddress;
  int coilCount;
  List<RegisterConfig> entries;
  List<StatusConfig> statusEntries;

  RegisterList({
    String? id,
    required this.name,
    this.regType = '4xxxx',
    this.coilType = '0xxxx',
    this.autoRefresh = true,
    int refreshIntervalMs = kDefaultRegisterRefreshIntervalMs,
    this.coilAutoRefresh = true,
    int coilRefreshIntervalMs = kDefaultRegisterRefreshIntervalMs,
    int startAddress = 0,
    int count = 20,
    int coilStartAddress = 0,
    int coilCount = 20,
    List<RegisterConfig>? entries,
    List<StatusConfig>? statusEntries,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       startAddress = startAddress < 0 ? 0 : startAddress,
       count = count < 1 ? 20 : count,
       coilStartAddress = coilStartAddress < 0 ? 0 : coilStartAddress,
       coilCount = coilCount < 1 ? 20 : coilCount,
       refreshIntervalMs = _clampRegisterRefreshIntervalMs(refreshIntervalMs),
       coilRefreshIntervalMs = _clampRegisterRefreshIntervalMs(
         coilRefreshIntervalMs,
       ),
       entries = entries ?? [],
       statusEntries = statusEntries ?? [];

  RegisterList copyWith({
    String? id,
    String? name,
    String? regType,
    String? coilType,
    bool? autoRefresh,
    int? refreshIntervalMs,
    bool? coilAutoRefresh,
    int? coilRefreshIntervalMs,
    int? startAddress,
    int? count,
    int? coilStartAddress,
    int? coilCount,
    List<RegisterConfig>? entries,
    List<StatusConfig>? statusEntries,
  }) => RegisterList(
    id: id ?? this.id,
    name: name ?? this.name,
    regType: regType ?? this.regType,
    coilType: coilType ?? this.coilType,
    autoRefresh: autoRefresh ?? this.autoRefresh,
    refreshIntervalMs: refreshIntervalMs ?? this.refreshIntervalMs,
    coilAutoRefresh: coilAutoRefresh ?? this.coilAutoRefresh,
    coilRefreshIntervalMs: coilRefreshIntervalMs ?? this.coilRefreshIntervalMs,
    startAddress: startAddress ?? this.startAddress,
    count: count ?? this.count,
    coilStartAddress: coilStartAddress ?? this.coilStartAddress,
    coilCount: coilCount ?? this.coilCount,
    entries: entries ?? List.of(this.entries),
    statusEntries: statusEntries ?? List.of(this.statusEntries),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'regType': regType,
    'coilType': coilType,
    'autoRefresh': autoRefresh,
    'refreshIntervalMs': refreshIntervalMs,
    'coilAutoRefresh': coilAutoRefresh,
    'coilRefreshIntervalMs': coilRefreshIntervalMs,
    'startAddress': startAddress,
    'count': count,
    'coilStartAddress': coilStartAddress,
    'coilCount': coilCount,
    'statusAddressMode': kStatusAddressModeDisplay,
    'entries': entries.map((e) => e.toJson()).toList(),
    'statusEntries': statusEntries.map((e) => e.toJson()).toList(),
  };

  factory RegisterList.fromJson(Map<String, dynamic> json) {
    final hasDisplayStatusAddresses =
        json['statusAddressMode'] == kStatusAddressModeDisplay;
    final rawCoilStartAddress = json['coilStartAddress'] as int?;
    final statusEntries = (json['statusEntries'] as List<dynamic>? ?? [])
        .map((e) => StatusConfig.fromJson(e as Map<String, dynamic>))
        .map(
          (entry) => hasDisplayStatusAddresses
              ? entry
              : entry.copyWith(
                  address: _legacyStatusAddressToDisplay(
                    entry.statusType,
                    entry.address,
                  ),
                ),
        )
        .toList();

    return RegisterList(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'List 1',
      regType: json['regType'] as String? ?? '4xxxx',
      coilType: json['coilType'] as String? ?? '0xxxx',
      autoRefresh: json['autoRefresh'] as bool? ?? true,
      refreshIntervalMs:
          json['refreshIntervalMs'] as int? ??
          kDefaultRegisterRefreshIntervalMs,
      coilAutoRefresh: json['coilAutoRefresh'] as bool? ?? true,
      coilRefreshIntervalMs:
          json['coilRefreshIntervalMs'] as int? ??
          kDefaultRegisterRefreshIntervalMs,
      startAddress: json['startAddress'] as int? ?? 0,
      count: json['count'] as int? ?? 20,
      coilStartAddress: hasDisplayStatusAddresses
          ? rawCoilStartAddress ?? 0
          : (rawCoilStartAddress ?? 0) + 1,
      coilCount: json['coilCount'] as int? ?? 20,
      entries: (json['entries'] as List<dynamic>? ?? [])
          .map((e) => RegisterConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      statusEntries: statusEntries,
    );
  }
}

int _clampRegisterRefreshIntervalMs(int value) {
  if (value < kMinRegisterRefreshIntervalMs) {
    return kMinRegisterRefreshIntervalMs;
  }
  if (value > kMaxRegisterRefreshIntervalMs) {
    return kMaxRegisterRefreshIntervalMs;
  }
  return value;
}

int _legacyStatusAddressToDisplay(String statusType, int rawAddress) {
  final addressType = RegisterAddressType.fromCode(
    statusType,
    fallback: RegisterAddressType.coils,
  );
  return addressType.displayOffset + rawAddress + 1;
}
