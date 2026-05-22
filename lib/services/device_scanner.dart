import 'package:flutter/foundation.dart';
import '../runtime/runtime_ports.dart';
import 'discovered_device_list.dart';

class DeviceScanner extends ChangeNotifier implements DeviceScannerPort {
  static final DeviceScanner instance = DeviceScanner._();

  DeviceScanner._() {
    discoveredDevices.addListener(notifyListeners);
  }

  @override
  final DiscoveredDeviceList discoveredDevices = DiscoveredDeviceList();

  ScannerStateView _state = ScannerStateView.idle;
  int _scanned = 0;
  int _total = 0;
  bool _cancelled = false;

  @override
  ScannerStateView get state => _state;
  int get scannedCount => _scanned;
  int get totalCount => _total;
  double get progress => _total == 0 ? 0.0 : _scanned / _total;

  @override
  Future<void> startScan(DeviceScanRequest params) async {
    if (_state == ScannerStateView.scanning) return;

    _cancelled = false;
    _scanned = 0;
    _total = 254;
    _state = ScannerStateView.scanning;
    notifyListeners();

    // TODO: replace with real TCP scan once ModbusClient is implemented
    await Future.delayed(const Duration(seconds: 2));

    if (!_cancelled) {
      discoveredDevices.add(params.discoveredDevice('${params.subnet}.50'));
      discoveredDevices.add(params.discoveredDevice('${params.subnet}.51'));
      _scanned = _total;
      _state = ScannerStateView.done;
    } else {
      _state = ScannerStateView.idle;
    }

    notifyListeners();
  }

  @override
  void stopScan() {
    if (_state != ScannerStateView.scanning) return;
    _cancelled = true;
  }
}
