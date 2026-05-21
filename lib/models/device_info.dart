enum ProtocolType { modbusTcp, modbusRtuIp }

class DeviceInfo {
  final String name;
  final String host;
  final int port;
  final ProtocolType protocol;
  final int unitId;
  final int timeout;
  final int reconnectDelay;
  final bool connected;
  final bool lastUsed;
  final String notes;

  const DeviceInfo({
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    required this.unitId,
    this.timeout = 1000,
    this.reconnectDelay = 3000,
    this.connected = false,
    this.lastUsed = false,
    this.notes = '',
  });

  DeviceInfo copyWith({
    String? name,
    String? host,
    int? port,
    ProtocolType? protocol,
    int? unitId,
    int? timeout,
    int? reconnectDelay,
    bool? connected,
    bool? lastUsed,
    String? notes,
  }) {
    return DeviceInfo(
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      unitId: unitId ?? this.unitId,
      timeout: timeout ?? this.timeout,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      connected: connected ?? this.connected,
      lastUsed: lastUsed ?? this.lastUsed,
      notes: notes ?? this.notes,
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
      );
}

const mockDevice = DeviceInfo(
  name: 'PLC #1',
  host: '192.168.0.10',
  port: 502,
  protocol: ProtocolType.modbusTcp,
  unitId: 1,
  connected: true,
  lastUsed: true,
);

const mockDevices = [
  mockDevice,
  DeviceInfo(
    name: 'Water Pump Station',
    host: '192.168.0.20',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
  ),
  DeviceInfo(
    name: 'HVAC Controller',
    host: '192.168.0.30',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
  ),
  DeviceInfo(
    name: 'Energy Meter',
    host: '192.168.0.40',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
  ),
  DeviceInfo(
    name: 'Boiler Control',
    host: '10.0.0.15',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 2,
  ),
];
