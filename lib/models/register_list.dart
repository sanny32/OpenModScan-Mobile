class RegisterConfig {
  int address;
  String typeName;
  String? comment;

  RegisterConfig({
    required this.address,
    this.typeName = 'UInt16',
    this.comment,
  });

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

class RegisterList {
  String id;
  String name;
  String regType;
  String coilType;
  int addrMode;
  bool autoRefresh;
  bool coilAutoRefresh;
  int startAddress;
  int count;
  int coilStartAddress;
  int coilCount;
  List<RegisterConfig> entries;

  RegisterList({
    String? id,
    required this.name,
    this.regType = '4xxxx',
    this.coilType = '0xxxx',
    this.addrMode = 0,
    this.autoRefresh = true,
    this.coilAutoRefresh = true,
    this.startAddress = 1,
    this.count = 20,
    this.coilStartAddress = 0,
    this.coilCount = 20,
    List<RegisterConfig>? entries,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        entries = entries ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'regType': regType,
        'coilType': coilType,
        'addrMode': addrMode,
        'autoRefresh': autoRefresh,
        'coilAutoRefresh': coilAutoRefresh,
        'startAddress': startAddress,
        'count': count,
        'coilStartAddress': coilStartAddress,
        'coilCount': coilCount,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory RegisterList.fromJson(Map<String, dynamic> json) => RegisterList(
        id: json['id'] as String?,
        name: json['name'] as String? ?? 'List 1',
        regType: json['regType'] as String? ?? '4xxxx',
        coilType: json['coilType'] as String? ?? '0xxxx',
        addrMode: json['addrMode'] as int? ?? 0,
        autoRefresh: json['autoRefresh'] as bool? ?? true,
        coilAutoRefresh: json['coilAutoRefresh'] as bool? ?? true,
        startAddress: json['startAddress'] as int? ?? 1,
        count: json['count'] as int? ?? 20,
        coilStartAddress: json['coilStartAddress'] as int? ?? 0,
        coilCount: json['coilCount'] as int? ?? 20,
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => RegisterConfig.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
