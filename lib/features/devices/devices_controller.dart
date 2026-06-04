import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';
import '../../models/device_info.dart';
import '../../models/discovered_device.dart';
import '../../models/register_address_type.dart';
import '../../models/register_list.dart';
import '../../runtime/runtime_ports.dart';
import '../../services/device_repository.dart';
import '../../utils/modbus_format.dart';

class RegisterWriteResult {
  final int address;
  final String typeName;
  final List<int> writtenWords;
  final List<int> readBackWords;
  final String displayValue;
  final bool usedFallback;

  const RegisterWriteResult({
    required this.address,
    required this.typeName,
    required this.writtenWords,
    required this.readBackWords,
    required this.displayValue,
    required this.usedFallback,
  });
}

class CoilWriteResult {
  final int address;
  final bool value;

  const CoilWriteResult({required this.address, required this.value});
}

class DevicesController extends ChangeNotifier {
  final DeviceRepositoryPort _repository;
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

  ProtocolType get defaultConnectionType => _settings.connectionType;

  /// Saved devices are ordered by the user's manual drag order, which is the
  /// persisted repository order. The home preview shows the first [limit].
  List<DeviceInfo> visibleHomeDevices([int limit = 3]) =>
      filteredDevices.take(limit).toList();

  List<DeviceInfo> get filteredDevices =>
      devices.where((device) => _matchesSearch(device, _search)).toList();

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

  /// Saved devices matching [query], in the persisted manual order.
  List<DeviceInfo> savedDevicesForSearch(String query) =>
      devices.where((device) => _matchesSearch(device, query)).toList();

  /// Moves a saved device within the persisted manual order. Indices are into
  /// the unfiltered saved-device list (manual reordering is only offered when
  /// no search filter is active, so display indices map 1:1 to storage).
  ///
  /// [newIndex] follows the `onReorderItem` convention: it is the destination
  /// index *after* the dragged item has been removed, so no extra adjustment is
  /// needed here.
  Future<void> reorderSavedDevices(int oldIndex, int newIndex) async {
    final list = List.of(devices);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), moved);
    await _repository.replaceAll(list);
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

  Future<RegisterWriteResult> writeRegisterValue(
    DeviceInfo device, {
    required int address,
    required String typeName,
    required String value,
    required String registerOrder,
    required String byteOrder,
  }) async {
    if (!_settings.writeEnabled) {
      throw StateError('Writes are disabled.');
    }
    if (!_connectionRuntime.isConnected(device)) {
      throw StateError('${device.name} is not connected.');
    }

    final words = encodeRegisterValue(
      typeName,
      value,
      registerOrder: registerOrder,
      byteOrder: byteOrder,
    );
    final modbusAddress = RegisterAddressType.holdingRegisters.toModbusAddress(
      address,
      addressBase: _settings.addressBaseStart,
    );

    final usedFallback = await _connectionRuntime.writeHoldingRegisters(
      device,
      startAddress: modbusAddress,
      values: words,
    );

    var readBackWords = words;
    try {
      final readBack = await _connectionRuntime.readHoldingRegisters(
        device,
        startAddress: modbusAddress,
        count: words.length,
      );
      if (readBack.length == words.length) {
        readBackWords = readBack;
      }
    } catch (_) {}

    final rawMap = {
      for (var i = 0; i < readBackWords.length; i++)
        address + i: readBackWords[i],
    };
    return RegisterWriteResult(
      address: address,
      typeName: typeName,
      writtenWords: words,
      readBackWords: readBackWords,
      displayValue: computeDisplayValue(
        address,
        typeName,
        rawMap,
        registerOrder: registerOrder,
        byteOrder: byteOrder,
      ),
      usedFallback: usedFallback,
    );
  }

  Future<CoilWriteResult> writeCoilValue(
    DeviceInfo device, {
    required int address,
    required bool value,
  }) async {
    if (!_settings.writeEnabled) {
      throw StateError('Writes are disabled.');
    }
    if (!_connectionRuntime.isConnected(device)) {
      throw StateError('${device.name} is not connected.');
    }

    final modbusAddress = RegisterAddressType.coils.toModbusAddress(
      address,
      addressBase: _settings.addressBaseStart,
    );
    await _connectionRuntime.writeCoil(
      device,
      address: modbusAddress,
      value: value,
    );
    var readBackValue = value;
    try {
      final readBack = await _connectionRuntime.readCoils(
        device,
        startAddress: modbusAddress,
        count: 1,
      );
      if (readBack.isNotEmpty) readBackValue = readBack.first;
    } catch (_) {}
    return CoilWriteResult(address: address, value: readBackValue);
  }

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
        subnetCidr: _settings.scanSubnetCidr.isEmpty
            ? null
            : _settings.scanSubnetCidr,
        subnetPrefix: _settings.scanSubnetPrefix,
        portStart: _settings.scanPortStart,
        portEnd: _settings.scanPortEnd,
        unitIdStart: _settings.scanUnitIdStart,
        unitIdEnd: _settings.scanUnitIdEnd,
        requestType: _settings.scanRequestType,
        requestAddress: _settings.scanRequestAddress,
        timeout: Duration(milliseconds: _settings.timeout),
        connectTimeout: Duration(milliseconds: _settings.scanConnectTimeout),
        concurrency: _settings.scanConcurrency,
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
