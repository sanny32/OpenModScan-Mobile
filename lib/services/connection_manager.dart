import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../runtime/runtime_ports.dart';
import 'modbus_client.dart';

class ConnectionManager implements ConnectionRuntime {
  static final ConnectionManager instance = ConnectionManager._();
  ConnectionManager._();

  // keyed by stable device id
  final ValueNotifier<Map<String, ModbusClient>> clients = ValueNotifier(
    const {},
  );
  final ValueNotifier<Set<String>> _connectedDeviceIds = ValueNotifier(
    const {},
  );

  @override
  ValueListenable<Set<String>> get connectedDeviceIds => _connectedDeviceIds;

  @override
  bool isConnected(DeviceInfo device) =>
      clients.value[device.id]?.isConnected ?? false;

  @override
  Future<void> connect(DeviceInfo device) async {
    final client = ModbusClient(device);
    await client.connect();
    clients.value = {...clients.value, device.id: client};
    _connectedDeviceIds.value = clients.value.keys.toSet();
  }

  @override
  Future<void> disconnect(DeviceInfo device) async {
    await clients.value[device.id]?.disconnect();
    clients.value = Map.of(clients.value)..remove(device.id);
    _connectedDeviceIds.value = clients.value.keys.toSet();
  }
}
