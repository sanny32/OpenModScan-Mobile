import 'register_list.dart';

enum ProtocolType { modbusTcp, modbusRtuIp }

enum DeviceMarkerColor { blue, green, amber, red, purple, teal, gray }

extension ProtocolTypeX on ProtocolType {
  bool get supportsConnection => switch (this) {
    ProtocolType.modbusTcp => true,
    ProtocolType.modbusRtuIp => false,
  };

  String get unsupportedConnectionMessage => switch (this) {
    ProtocolType.modbusTcp => '',
    ProtocolType.modbusRtuIp =>
      'Modbus RTU/IP connections are not implemented yet.',
  };
}

class DeviceInfo {
  static int _idSequence = 0;

  final String id;
  final String name;
  final String host;
  final int port;
  final ProtocolType protocol;
  final int unitId;
  final int timeout;
  final int reconnectDelay;
  final String notes;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;
  final DeviceMarkerColor markerColor;
  final List<RegisterList> registerLists;

  DeviceInfo({
    String? id,
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    required this.unitId,
    this.timeout = 1000,
    this.reconnectDelay = 3000,
    this.notes = '',
    DateTime? createdAt,
    this.lastConnectedAt,
    this.markerColor = DeviceMarkerColor.blue,
    List<RegisterList>? registerLists,
  }) : id = id ?? _nextId(),
       createdAt = createdAt ?? DateTime.now(),
       registerLists = registerLists ?? [];

  static String _nextId() =>
      'device-${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';

  DeviceInfo copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    ProtocolType? protocol,
    int? unitId,
    int? timeout,
    int? reconnectDelay,
    String? notes,
    DateTime? createdAt,
    DateTime? lastConnectedAt,
    bool clearLastConnectedAt = false,
    DeviceMarkerColor? markerColor,
    List<RegisterList>? registerLists,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      unitId: unitId ?? this.unitId,
      timeout: timeout ?? this.timeout,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastConnectedAt: clearLastConnectedAt
          ? null
          : lastConnectedAt ?? this.lastConnectedAt,
      markerColor: markerColor ?? this.markerColor,
      registerLists: registerLists ?? List.of(this.registerLists),
    );
  }

  String get address => '$host:$port';

  String get protocolName => switch (protocol) {
    ProtocolType.modbusTcp => 'Modbus TCP',
    ProtocolType.modbusRtuIp => 'Modbus RTU/IP',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'protocol': protocol.name,
    'unitId': unitId,
    'timeout': timeout,
    'reconnectDelay': reconnectDelay,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    'markerColor': markerColor.name,
    'registerLists': registerLists.map((l) => l.toJson()).toList(),
  };

  factory DeviceInfo.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackCreatedAt,
  }) => DeviceInfo(
    id: json['id'] as String?,
    name: json['name'] as String,
    host: json['host'] as String,
    port: json['port'] as int,
    protocol: ProtocolType.values.firstWhere(
      (e) => e.name == json['protocol'],
      orElse: () => ProtocolType.modbusTcp,
    ),
    unitId: json['unitId'] as int,
    timeout: json['timeout'] as int,
    reconnectDelay: json['reconnectDelay'] as int,
    notes: (json['notes'] as String?) ?? '',
    createdAt: _dateTimeFromJson(json['createdAt']) ?? fallbackCreatedAt,
    lastConnectedAt: _dateTimeFromJson(json['lastConnectedAt']),
    markerColor: _markerColorFromJson(json['markerColor']),
    registerLists: (json['registerLists'] as List<dynamic>? ?? [])
        .map((e) => RegisterList.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

DeviceMarkerColor _markerColorFromJson(Object? value) {
  if (value is! String) return DeviceMarkerColor.blue;
  return DeviceMarkerColor.values.firstWhere(
    (color) => color.name == value,
    orElse: () => DeviceMarkerColor.blue,
  );
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
