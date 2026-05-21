import 'device_info.dart';

class DiscoveredDevice {
  final String host;
  final int port;
  final int unitId;
  final ProtocolType protocol;

  const DiscoveredDevice({
    required this.host,
    required this.port,
    required this.unitId,
    required this.protocol,
  });

  String get address => '$host:$port';

  String get protocolName => switch (protocol) {
        ProtocolType.modbusTcp => 'Modbus TCP',
        ProtocolType.modbusRtuIp => 'Modbus RTU/IP',
      };
}
