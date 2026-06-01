import 'package:flutter/foundation.dart';

import '../models/status_entry.dart';
import '../models/device_info.dart';
import '../models/discovered_device.dart';
import '../models/log_entry.dart';
import '../models/modbus_scan.dart';
import '../models/register_entry.dart';
import '../services/discovered_device_list.dart';

abstract interface class ConnectionRuntime {
  ValueListenable<Set<String>> get connectedDeviceIds;

  bool isConnected(DeviceInfo device);

  Future<void> connect(DeviceInfo device);

  Future<void> disconnect(DeviceInfo device);

  Future<List<int>> readHoldingRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  });

  Future<List<int>> readInputRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  });

  Future<List<bool>> readCoils(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  });

  Future<List<bool>> readDiscreteInputs(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  });

  Future<void> writeHoldingRegister(
    DeviceInfo device, {
    required int address,
    required int value,
  });

  /// Writes consecutive Holding registers.
  ///
  /// Returns `true` when the runtime had to fall back from a multiple-register
  /// write to sequential single-register writes.
  Future<bool> writeHoldingRegisters(
    DeviceInfo device, {
    required int startAddress,
    required List<int> values,
  });

  Future<void> writeCoil(
    DeviceInfo device, {
    required int address,
    required bool value,
  });
}

abstract interface class RegisterRuntime {
  List<RegisterEntry> registersForRange(int startAddress, int count);

  List<StatusEntry> statusesForRange(int startAddress, int count);

  Future<void> writeRegister({
    required String deviceId,
    required int address,
    required String value,
  });
}

abstract interface class TrafficLogSource implements Listenable {
  List<LogEntry> entriesFor(String? deviceId);

  void clear(String? deviceId);
}

abstract interface class DeviceScannerPort implements Listenable {
  DiscoveredDeviceList get discoveredDevices;

  ScannerStateView get state;

  int get scannedCount;

  int get totalCount;

  double get progress;

  String? get scanCidr;

  DateTime? get scanStartedAt;

  ProtocolType? get scanProtocol;

  Future<void> startScan(DeviceScanRequest request);

  void stopScan();

  void clearResults();
}

enum ScannerStateView { idle, scanning, done }

class DeviceScanRequest {
  final ProtocolType protocol;
  final String? subnetCidr;
  final int subnetPrefix;
  final int portStart;
  final int portEnd;
  final int unitIdStart;
  final int unitIdEnd;
  final ModbusScanRequestType requestType;
  final int requestAddress;

  /// Per-unit-id response timeout once an endpoint is connected.
  final Duration timeout;

  /// Bound for the initial TCP connect to an endpoint. Kept short so dead
  /// addresses are skipped quickly without waiting out the full [timeout].
  final Duration connectTimeout;

  final int concurrency;

  const DeviceScanRequest({
    this.protocol = ProtocolType.modbusTcp,
    this.subnetCidr,
    this.subnetPrefix = 24,
    this.portStart = 502,
    this.portEnd = 502,
    this.unitIdStart = 1,
    this.unitIdEnd = 10,
    this.requestType = ModbusScanRequestType.holdingRegisters,
    this.requestAddress = 0,
    this.timeout = const Duration(milliseconds: 500),
    this.connectTimeout = const Duration(milliseconds: 300),
    this.concurrency = 32,
  });

  Iterable<int> get ports sync* {
    for (var port = portStart; port <= portEnd; port++) {
      yield port;
    }
  }

  Iterable<int> get unitIds sync* {
    for (var unitId = unitIdStart; unitId <= unitIdEnd; unitId++) {
      yield unitId;
    }
  }

  DiscoveredDevice discoveredDevice(String host, int port, int unitId) =>
      DiscoveredDevice(
        host: host,
        port: port,
        unitId: unitId,
        protocol: protocol,
      );
}
