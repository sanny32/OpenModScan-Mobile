import 'package:flutter/foundation.dart';

import '../models/status_entry.dart';
import '../models/device_info.dart';
import '../models/discovered_device.dart';
import '../models/log_entry.dart';
import '../models/register_entry.dart';
import '../services/discovered_device_list.dart';

abstract interface class ConnectionRuntime {
  ValueListenable<Set<String>> get connectedDeviceIds;

  bool isConnected(DeviceInfo device);

  Future<void> connect(DeviceInfo device);

  Future<void> disconnect(DeviceInfo device);
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

  Future<void> startScan(DeviceScanRequest request);

  void stopScan();
}

enum ScannerStateView { idle, scanning, done }

class DeviceScanRequest {
  final String subnet;
  final int port;
  final int unitId;
  final Duration timeout;
  final int concurrency;

  const DeviceScanRequest({
    required this.subnet,
    this.port = 502,
    this.unitId = 1,
    this.timeout = const Duration(milliseconds: 500),
    this.concurrency = 20,
  });

  DiscoveredDevice discoveredDevice(String host) => DiscoveredDevice(
    host: host,
    port: port,
    unitId: unitId,
    protocol: ProtocolType.modbusTcp,
  );
}
