import 'package:flutter/foundation.dart';
import '../models/discovered_device.dart';
import '../models/device_info.dart';
import 'discovered_device_list.dart';

enum ScannerState { idle, scanning, done }

class ScanParameters {
  final String subnet;
  final int port;
  final int unitId;
  final Duration timeout;
  final int concurrency;

  const ScanParameters({
    required this.subnet,
    this.port = 502,
    this.unitId = 1,
    this.timeout = const Duration(milliseconds: 500),
    this.concurrency = 20,
  });
}

class DeviceScanner extends ChangeNotifier {
  static final DeviceScanner instance = DeviceScanner._();

  DeviceScanner._() {
    discoveredDevices.addListener(notifyListeners);
  }

  final DiscoveredDeviceList discoveredDevices = DiscoveredDeviceList();

  ScannerState _state = ScannerState.idle;
  int _scanned = 0;
  int _total = 0;
  bool _cancelled = false;

  ScannerState get state => _state;
  int get scannedCount => _scanned;
  int get totalCount => _total;
  double get progress => _total == 0 ? 0.0 : _scanned / _total;

  Future<void> startScan(ScanParameters params) async {
    if (_state == ScannerState.scanning) return;

    _cancelled = false;
    _scanned = 0;
    _total = 254;
    _state = ScannerState.scanning;
    notifyListeners();

    // TODO: replace with real TCP scan once ModbusClient is implemented
    await Future.delayed(const Duration(seconds: 2));

    if (!_cancelled) {
      discoveredDevices.add(DiscoveredDevice(
        host: '${params.subnet}.50',
        port: params.port,
        unitId: params.unitId,
        protocol: ProtocolType.modbusTcp,
      ));
      discoveredDevices.add(DiscoveredDevice(
        host: '${params.subnet}.51',
        port: params.port,
        unitId: params.unitId,
        protocol: ProtocolType.modbusTcp,
      ));
      _scanned = _total;
      _state = ScannerState.done;
    } else {
      _state = ScannerState.idle;
    }

    notifyListeners();
  }

  void stopScan() {
    if (_state != ScannerState.scanning) return;
    _cancelled = true;
  }
}
