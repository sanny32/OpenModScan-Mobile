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
    if (!device.protocol.supportsConnection) {
      throw UnsupportedError(device.protocol.unsupportedConnectionMessage);
    }
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

  @override
  Future<List<int>> readHoldingRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) => _clientFor(device).readHoldingRegisters(startAddress, count);

  @override
  Future<List<int>> readInputRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) => _clientFor(device).readInputRegisters(startAddress, count);

  @override
  Future<List<bool>> readCoils(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) => _clientFor(device).readCoils(startAddress, count);

  @override
  Future<List<bool>> readDiscreteInputs(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) => _clientFor(device).readDiscreteInputs(startAddress, count);

  @override
  Future<void> writeHoldingRegister(
    DeviceInfo device, {
    required int address,
    required int value,
  }) => _clientFor(device).writeHoldingRegister(address, value);

  @override
  Future<void> writeCoil(
    DeviceInfo device, {
    required int address,
    required bool value,
  }) => _clientFor(device).writeCoil(address, value);

  ModbusClient _clientFor(DeviceInfo device) {
    final client = clients.value[device.id];
    if (client == null || !client.isConnected) {
      throw StateError('${device.name} is not connected.');
    }
    return client;
  }
}
