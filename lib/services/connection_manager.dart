import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import 'modbus_client.dart';

class ConnectionManager {
  static final ConnectionManager instance = ConnectionManager._();
  ConnectionManager._();

  // keyed by device.address (host:port)
  final ValueNotifier<Map<String, ModbusClient>> clients =
      ValueNotifier(const {});

  bool isConnected(DeviceInfo device) =>
      clients.value[device.address]?.isConnected ?? false;

  Future<void> connect(DeviceInfo device) async {
    final client = ModbusClient(device);
    await client.connect();
    clients.value = {...clients.value, device.address: client};
  }

  Future<void> disconnect(DeviceInfo device) async {
    await clients.value[device.address]?.disconnect();
    clients.value = Map.of(clients.value)..remove(device.address);
  }
}
