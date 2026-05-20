enum ProtocolType { modbusTcp }

class DeviceInfo {
  final String name;
  final String host;
  final int port;
  final ProtocolType protocol;
  final int unitId;
  final bool connected;
  final bool lastUsed;

  const DeviceInfo({
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    required this.unitId,
    this.connected = false,
    this.lastUsed = false,
  });

  String get address => '$host:$port';

  String get protocolName => 'Modbus TCP';
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
  DeviceInfo(name: 'Water Pump Station', host: '192.168.0.20', port: 502, protocol: ProtocolType.modbusTcp, unitId: 1),
  DeviceInfo(name: 'HVAC Controller',    host: '192.168.0.30', port: 502, protocol: ProtocolType.modbusTcp, unitId: 1),
  DeviceInfo(name: 'Energy Meter',       host: '192.168.0.40', port: 502, protocol: ProtocolType.modbusTcp, unitId: 1),
  DeviceInfo(name: 'Boiler Control',     host: '10.0.0.15',    port: 502, protocol: ProtocolType.modbusTcp, unitId: 2),
];
