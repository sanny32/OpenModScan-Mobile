import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
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
  }) => _withRetry(
    device,
    () => _clientFor(device).readHoldingRegisters(startAddress, count),
  );

  @override
  Future<List<int>> readInputRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) => _withRetry(
    device,
    () => _clientFor(device).readInputRegisters(startAddress, count),
  );

  @override
  Future<List<bool>> readCoils(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) => _withRetry(
    device,
    () => _clientFor(device).readCoils(startAddress, count),
  );

  @override
  Future<List<bool>> readDiscreteInputs(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) => _withRetry(
    device,
    () => _clientFor(device).readDiscreteInputs(startAddress, count),
  );

  @override
  Future<void> writeHoldingRegister(
    DeviceInfo device, {
    required int address,
    required int value,
  }) => _clientFor(device).writeHoldingRegister(address, value);

  @override
  Future<bool> writeHoldingRegisters(
    DeviceInfo device, {
    required int startAddress,
    required List<int> values,
  }) => _clientFor(device).writeHoldingRegisters(startAddress, values);

  @override
  Future<void> writeCoil(
    DeviceInfo device, {
    required int address,
    required bool value,
  }) => _clientFor(device).writeCoil(address, value);

  /// Runs a read [op], retrying up to `readFailureAttempts` times. Between
  /// failed attempts it waits the device's `reconnectDelay` and makes a
  /// best-effort reconnect, so transient drops recover transparently.
  Future<T> _withRetry<T>(DeviceInfo device, Future<T> Function() op) {
    return runReadWithRetry(
      attempts: AppSettings.instance.readFailureAttempts,
      reconnectDelay: Duration(milliseconds: device.reconnectDelay),
      read: op,
      reconnect: () async {
        final client = clients.value[device.id];
        await client?.disconnect();
        await client?.connect();
      },
    );
  }

  ModbusClient _clientFor(DeviceInfo device) {
    final client = clients.value[device.id];
    if (client == null || !client.isConnected) {
      throw StateError('${device.name} is not connected.');
    }
    return client;
  }
}

/// Attempts [read] up to [attempts] times (at least once). After a failed
/// attempt — except the final one — it waits [reconnectDelay] and runs the
/// best-effort [reconnect] before retrying. The last failure is rethrown.
///
/// Extracted as a top-level function so the retry policy can be unit-tested
/// without a live Modbus connection.
@visibleForTesting
Future<T> runReadWithRetry<T>({
  required int attempts,
  required Duration reconnectDelay,
  required Future<T> Function() read,
  required Future<void> Function() reconnect,
}) async {
  final maxAttempts = attempts.clamp(1, 100);
  for (var attempt = 1; ; attempt++) {
    try {
      return await read();
    } catch (_) {
      if (attempt >= maxAttempts) rethrow;
      await Future<void>.delayed(reconnectDelay);
      try {
        await reconnect();
      } catch (_) {
        // Reconnect failed; the next attempt will retry or rethrow.
      }
    }
  }
}
