import 'register_list.dart';

enum ProtocolType { modbusTcp, modbusRtuIp }

class DeviceInfo {
  final String name;
  final String host;
  final int port;
  final ProtocolType protocol;
  final int unitId;
  final int timeout;
  final int reconnectDelay;
  final String notes;
  final List<RegisterList> registerLists;

  DeviceInfo({
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    required this.unitId,
    this.timeout = 1000,
    this.reconnectDelay = 3000,
    this.notes = '',
    List<RegisterList>? registerLists,
  }) : registerLists = registerLists ?? [];

  DeviceInfo copyWith({
    String? name,
    String? host,
    int? port,
    ProtocolType? protocol,
    int? unitId,
    int? timeout,
    int? reconnectDelay,
    String? notes,
    List<RegisterList>? registerLists,
  }) {
    return DeviceInfo(
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      unitId: unitId ?? this.unitId,
      timeout: timeout ?? this.timeout,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      notes: notes ?? this.notes,
      registerLists: registerLists ?? List.of(this.registerLists),
    );
  }

  String get address => '$host:$port';

  String get protocolName => 'Modbus TCP';

  Map<String, dynamic> toJson() => {
        'name': name,
        'host': host,
        'port': port,
        'protocol': protocol.name,
        'unitId': unitId,
        'timeout': timeout,
        'reconnectDelay': reconnectDelay,
        'notes': notes,
        'registerLists': registerLists.map((l) => l.toJson()).toList(),
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        name: json['name'] as String,
        host: json['host'] as String,
        port: json['port'] as int,
        protocol: ProtocolType.values.firstWhere(
            (e) => e.name == json['protocol'],
            orElse: () => ProtocolType.modbusTcp),
        unitId: json['unitId'] as int,
        timeout: json['timeout'] as int,
        reconnectDelay: json['reconnectDelay'] as int,
        notes: (json['notes'] as String?) ?? '',
        registerLists: (json['registerLists'] as List<dynamic>? ?? [])
            .map((e) => RegisterList.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
