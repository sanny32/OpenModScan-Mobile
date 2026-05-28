import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';
import '../../models/device_info.dart';
import '../../models/discovered_device.dart';
import '../../models/register_list.dart';
import '../../runtime/runtime_ports.dart';
import '../../services/device_repository.dart';

class DevicesController extends ChangeNotifier {
  final DeviceRepository _repository;
  final ConnectionRuntime _connectionRuntime;
  final DeviceScannerPort _scanner;
  final AppSettings _settings;

  String _search = '';

  DevicesController(
    this._repository,
    this._connectionRuntime,
    this._scanner,
    this._settings,
  ) {
    _repository.devices.addListener(_forwardChange);
    _connectionRuntime.connectedDeviceIds.addListener(_forwardChange);
    _scanner.addListener(_forwardChange);
  }

  List<DeviceInfo> get devices => _repository.snapshot;

  List<DeviceInfo> get savedDevicesSortedNewestFirst =>
      _sortByCreatedNewestFirst(devices);

  List<DeviceInfo> visibleHomeDevices([int limit = 3]) {
    final filtered = filteredDevices;
    final favorites = filtered.where((d) => d.isFavorite).toList();
    final sortedFavs = _sortByCreatedNewestFirst(favorites);
    if (favorites.isEmpty) {
      return _sortByCreatedNewestFirst(filtered).take(limit).toList();
    }
    if (sortedFavs.length >= limit) {
      return sortedFavs.take(limit).toList();
    }
    final sortedNonFavs = _sortByCreatedNewestFirst(
      filtered.where((d) => !d.isFavorite).toList(),
    );
    return [
      ...sortedFavs,
      ...sortedNonFavs.take(limit - sortedFavs.length),
    ];
  }

  List<DeviceInfo> get filteredDevices =>
      devices.where((device) => _matchesSearch(device, _search)).toList();

  DeviceSortMode get savedDevicesSortMode => _settings.savedDevicesSortMode;

  List<DiscoveredDevice> get discoveredDevices =>
      _scanner.discoveredDevices.devices;

  bool get hasDiscoveredDevices => !_scanner.discoveredDevices.isEmpty;

  ScannerStateView get scannerState => _scanner.state;

  int get scannerScannedCount => _scanner.scannedCount;

  int get scannerTotalCount => _scanner.totalCount;

  double get scannerProgress => _scanner.progress;

  String? get scannerCidr => _scanner.scanCidr;

  DateTime? get scannerStartedAt => _scanner.scanStartedAt;

  ProtocolType? get scannerProtocol => _scanner.scanProtocol;

  DeviceInfo? deviceById(String id) => _repository.findById(id);

  bool isConnected(DeviceInfo device) => _connectionRuntime.isConnected(device);

  Future<void> toggleConnection(DeviceInfo device) async {
    if (isConnected(device)) {
      await _connectionRuntime.disconnect(device);
      return;
    }
    await _connectionRuntime.connect(device);
    await updateDevice(device.copyWith(lastConnectedAt: DateTime.now()));
  }

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    notifyListeners();
  }

  Future<void> addDevice(DeviceInfo device) => _repository.add(device);

  Future<void> toggleFavorite(DeviceInfo device) =>
      updateDevice(device.copyWith(isFavorite: !device.isFavorite));

  Future<void> setSavedDevicesSortMode(DeviceSortMode value) async {
    await _settings.setSavedDevicesSortMode(value);
    notifyListeners();
  }

  List<DeviceInfo> devicesForSearchAndSort(
    String query,
    DeviceSortMode sortMode,
  ) {
    final filtered = devices.where((device) => _matchesSearch(device, query));
    return switch (sortMode) {
      DeviceSortMode.created => _sortByCreatedNewestFirst(filtered),
      DeviceSortMode.lastConnected => _sortByLastConnectedNewestFirst(filtered),
    };
  }

  Future<DeviceInfo> connectDiscoveredDevice(
    DiscoveredDevice discovered,
  ) async {
    if (!discovered.protocol.supportsConnection) {
      throw UnsupportedError(discovered.protocol.unsupportedConnectionMessage);
    }
    final existing = _findDiscoveredDevice(discovered);
    final device = existing ?? _deviceFromDiscovered(discovered);
    if (existing == null) {
      await _repository.add(device);
    }
    _scanner.discoveredDevices.remove(discovered);
    if (!_connectionRuntime.isConnected(device)) {
      await _connectionRuntime.connect(device);
    }
    final connectedDevice = device.copyWith(lastConnectedAt: DateTime.now());
    await _repository.update(connectedDevice);
    return connectedDevice;
  }

  Future<void> updateDevice(DeviceInfo device) => _repository.update(device);

  Future<int?> removeDevice(String deviceId) async {
    final index = devices.indexWhere((device) => device.id == deviceId);
    if (index == -1) return null;
    final device = devices[index];
    if (isConnected(device)) {
      await _connectionRuntime.disconnect(device);
    }
    await _repository.remove(deviceId);
    return index;
  }

  Future<void> restoreDevice(int index, DeviceInfo device) =>
      _repository.insert(index, device);

  Future<void> addRegisterList(String deviceId, RegisterList registerList) =>
      _repository.addRegisterList(deviceId, registerList);

  Future<void> removeRegisterList(String deviceId, String listId) =>
      _repository.removeRegisterList(deviceId, listId);

  Future<void> startScan() {
    if (_settings.scanClearOnStart) {
      _scanner.clearResults();
    }
    return _scanner.startScan(
      DeviceScanRequest(
        protocol: _settings.scanProtocol,
        subnetPrefix: _settings.scanSubnetPrefix,
        portStart: _settings.scanPortStart,
        portEnd: _settings.scanPortEnd,
        unitIdStart: _settings.scanUnitIdStart,
        unitIdEnd: _settings.scanUnitIdEnd,
        requestType: _settings.scanRequestType,
        requestAddress: _settings.scanRequestAddress,
        timeout: Duration(milliseconds: _settings.timeout),
      ),
    );
  }

  void stopScan() => _scanner.stopScan();

  void clearDiscoveredDevices() => _scanner.clearResults();

  void _forwardChange() => notifyListeners();

  bool _matchesSearch(DeviceInfo device, String query) {
    final normalized = query.toLowerCase();
    return normalized.isEmpty ||
        device.name.toLowerCase().contains(normalized) ||
        device.address.toLowerCase().contains(normalized);
  }

  List<DeviceInfo> _sortByCreatedNewestFirst(Iterable<DeviceInfo> devices) {
    return List.of(devices)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<DeviceInfo> _sortByLastConnectedNewestFirst(
    Iterable<DeviceInfo> devices,
  ) {
    return List.of(devices)..sort((a, b) {
      final aConnected = a.lastConnectedAt;
      final bConnected = b.lastConnectedAt;
      if (aConnected != null && bConnected != null) {
        final connectedCompare = bConnected.compareTo(aConnected);
        if (connectedCompare != 0) return connectedCompare;
      } else if (aConnected != null) {
        return -1;
      } else if (bConnected != null) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  DeviceInfo? _findDiscoveredDevice(DiscoveredDevice discovered) {
    for (final device in devices) {
      if (_matchesDiscovered(device, discovered)) return device;
    }
    return null;
  }

  bool _matchesDiscovered(DeviceInfo device, DiscoveredDevice discovered) {
    return device.host == discovered.host &&
        device.port == discovered.port &&
        device.protocol == discovered.protocol &&
        device.unitId == discovered.unitId;
  }

  DeviceInfo _deviceFromDiscovered(DiscoveredDevice discovered) {
    return DeviceInfo(
      name: _nextDeviceName(),
      host: discovered.host,
      port: discovered.port,
      protocol: discovered.protocol,
      unitId: discovered.unitId,
      timeout: _settings.timeout,
      reconnectDelay: _settings.reconnectDelay,
    );
  }

  String _nextDeviceName() {
    final names = devices.map((device) => device.name).toSet();
    var index = devices.length + 1;
    var name = 'Device #$index';
    while (names.contains(name)) {
      index++;
      name = 'Device #$index';
    }
    return name;
  }

  @override
  void dispose() {
    _repository.devices.removeListener(_forwardChange);
    _connectionRuntime.connectedDeviceIds.removeListener(_forwardChange);
    _scanner.removeListener(_forwardChange);
    super.dispose();
  }
}
