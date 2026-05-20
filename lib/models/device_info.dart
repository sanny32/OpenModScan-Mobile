enum ProtocolType { modbusTcp }

class DeviceInfo {
  final String name;
  final String host;
  final int port;
  final ProtocolType protocol;
  final int unitId;
  final bool connected;

  const DeviceInfo({
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    required this.unitId,
    this.connected = false,
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
);
