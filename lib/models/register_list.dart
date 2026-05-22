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

class RegisterList {
  String id;
  String name;
  String regType;
  String coilType;
  int addrMode;
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
    this.addrMode = 0,
    this.autoRefresh = true,
    int refreshIntervalMs = kDefaultRegisterRefreshIntervalMs,
    this.coilAutoRefresh = true,
    int coilRefreshIntervalMs = kDefaultRegisterRefreshIntervalMs,
    this.startAddress = 1,
    this.count = 20,
    this.coilStartAddress = 0,
    this.coilCount = 20,
    List<RegisterConfig>? entries,
    List<StatusConfig>? statusEntries,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
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
    int? addrMode,
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
    addrMode: addrMode ?? this.addrMode,
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
    'addrMode': addrMode,
    'autoRefresh': autoRefresh,
    'refreshIntervalMs': refreshIntervalMs,
    'coilAutoRefresh': coilAutoRefresh,
    'coilRefreshIntervalMs': coilRefreshIntervalMs,
    'startAddress': startAddress,
    'count': count,
    'coilStartAddress': coilStartAddress,
    'coilCount': coilCount,
    'entries': entries.map((e) => e.toJson()).toList(),
    'statusEntries': statusEntries.map((e) => e.toJson()).toList(),
  };

  factory RegisterList.fromJson(Map<String, dynamic> json) => RegisterList(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'List 1',
    regType: json['regType'] as String? ?? '4xxxx',
    coilType: json['coilType'] as String? ?? '0xxxx',
    addrMode: json['addrMode'] as int? ?? 0,
    autoRefresh: json['autoRefresh'] as bool? ?? true,
    refreshIntervalMs:
        json['refreshIntervalMs'] as int? ?? kDefaultRegisterRefreshIntervalMs,
    coilAutoRefresh: json['coilAutoRefresh'] as bool? ?? true,
    coilRefreshIntervalMs:
        json['coilRefreshIntervalMs'] as int? ??
        kDefaultRegisterRefreshIntervalMs,
    startAddress: json['startAddress'] as int? ?? 1,
    count: json['count'] as int? ?? 20,
    coilStartAddress: json['coilStartAddress'] as int? ?? 0,
    coilCount: json['coilCount'] as int? ?? 20,
    entries: (json['entries'] as List<dynamic>? ?? [])
        .map((e) => RegisterConfig.fromJson(e as Map<String, dynamic>))
        .toList(),
    statusEntries: (json['statusEntries'] as List<dynamic>? ?? [])
        .map((e) => StatusConfig.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
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
