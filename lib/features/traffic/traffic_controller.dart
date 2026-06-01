import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';
import '../../models/device_info.dart';
import '../../models/log_entry.dart';
import '../../navigation/navigation_targets.dart';
import '../../runtime/runtime_ports.dart';
import '../../services/device_repository.dart';

enum TrafficFilter { all, tx, rx, errors }

class TrafficController extends ChangeNotifier {
  final DeviceRepositoryPort _repository;
  final ConnectionRuntime _connectionRuntime;
  final TrafficLogSource _logs;

  String? _selectedDeviceId;
  TrafficFilter _filter = TrafficFilter.all;
  bool _autoScroll = true;
  bool _clearOnDisconnect = AppSettings.instance.clearLogOnDisconnect;
  Set<String> _connectedSnapshot = const {};

  TrafficController(this._repository, this._connectionRuntime, this._logs) {
    _repository.devices.addListener(_onRepositoryChanged);
    _connectionRuntime.connectedDeviceIds.addListener(_onConnectionChanged);
    _logs.addListener(_forwardChange);
    _connectedSnapshot = Set.of(_connectionRuntime.connectedDeviceIds.value);
    _selectedDeviceId = _repository.snapshot.isEmpty
        ? null
        : _repository.snapshot.first.id;
  }

  DeviceInfo? get selectedDevice => _selectedDeviceId == null
      ? null
      : _repository.findById(_selectedDeviceId!);

  List<DeviceInfo> get devices => _repository.snapshot;

  List<DeviceInfo> get connectedDevices =>
      _repository.snapshot.where(_connectionRuntime.isConnected).toList();

  TrafficFilter get filter => _filter;
  bool get autoScroll => _autoScroll;
  bool get clearOnDisconnect => _clearOnDisconnect;

  bool isConnected(DeviceInfo device) => _connectionRuntime.isConnected(device);

  Future<void> toggleConnection(DeviceInfo device) async {
    if (_connectionRuntime.isConnected(device)) {
      await _connectionRuntime.disconnect(device);
      return;
    }
    await _connectionRuntime.connect(device);
    await _repository.update(device.copyWith(lastConnectedAt: DateTime.now()));
  }

  List<LogEntry> get entries {
    final all = _logs.entriesFor(_selectedDeviceId);
    return switch (_filter) {
      TrafficFilter.all => all,
      TrafficFilter.tx =>
        all.where((entry) => entry.direction == LogDirection.tx).toList(),
      TrafficFilter.rx =>
        all.where((entry) => entry.direction == LogDirection.rx).toList(),
      TrafficFilter.errors =>
        all.where((entry) => entry.type == LogEntryType.error).toList(),
    };
  }

  void clearTraffic() => _logs.clear(_selectedDeviceId);

  void selectTarget(TrafficRouteArgs target) {
    _selectedDeviceId = target.deviceId;
    notifyListeners();
  }

  void selectDevice(String deviceId) {
    if (_selectedDeviceId == deviceId) return;
    _selectedDeviceId = deviceId;
    notifyListeners();
  }

  void setFilter(TrafficFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  void setAutoScroll(bool value) {
    _autoScroll = value;
    notifyListeners();
  }

  void setClearOnDisconnect(bool value) {
    if (_clearOnDisconnect == value) return;
    _clearOnDisconnect = value;
    AppSettings.instance.setClearLogOnDisconnect(value);
    notifyListeners();
  }

  void _onConnectionChanged() {
    final current = _connectionRuntime.connectedDeviceIds.value;
    if (_clearOnDisconnect) {
      for (final id in _connectedSnapshot) {
        if (!current.contains(id)) _logs.clear(id);
      }
    }
    _connectedSnapshot = Set.of(current);
    notifyListeners();
  }

  void _onRepositoryChanged() {
    if (selectedDevice == null) {
      _selectedDeviceId = _repository.snapshot.isEmpty
          ? null
          : _repository.snapshot.first.id;
    }
    notifyListeners();
  }

  void _forwardChange() => notifyListeners();

  @override
  void dispose() {
    _repository.devices.removeListener(_onRepositoryChanged);
    _connectionRuntime.connectedDeviceIds.removeListener(_onConnectionChanged);
    _logs.removeListener(_forwardChange);
    super.dispose();
  }
}
