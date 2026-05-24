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

abstract interface class TrafficLogSource {
  List<LogEntry> entriesFor(String? deviceId);
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
}

enum ScannerStateView { idle, scanning, done }

class DeviceScanRequest {
  final ProtocolType protocol;
  final int subnetPrefix;
  final int portStart;
  final int portEnd;
  final int unitIdStart;
  final int unitIdEnd;
  final ModbusScanRequestType requestType;
  final int requestAddress;
  final Duration timeout;
  final int concurrency;

  const DeviceScanRequest({
    this.protocol = ProtocolType.modbusTcp,
    this.subnetPrefix = 24,
    this.portStart = 502,
    this.portEnd = 502,
    this.unitIdStart = 1,
    this.unitIdEnd = 10,
    this.requestType = ModbusScanRequestType.holdingRegisters,
    this.requestAddress = 0,
    this.timeout = const Duration(milliseconds: 500),
    this.concurrency = 20,
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
