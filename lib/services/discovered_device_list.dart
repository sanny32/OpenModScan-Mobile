import 'package:flutter/foundation.dart';
import '../models/discovered_device.dart';

class DiscoveredDeviceList extends ChangeNotifier {
  final List<DiscoveredDevice> _devices = [];

  List<DiscoveredDevice> get devices => List.unmodifiable(_devices);

  bool get isEmpty => _devices.isEmpty;

  void add(DiscoveredDevice device) {
    final duplicate = _devices.any(
      (d) => d.host == device.host && d.port == device.port,
    );
    if (duplicate) return;
    _devices.add(device);
    notifyListeners();
  }

  void clear() {
    if (_devices.isEmpty) return;
    _devices.clear();
    notifyListeners();
  }
}
