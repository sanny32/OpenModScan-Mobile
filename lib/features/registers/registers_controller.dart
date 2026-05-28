import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';
import '../../models/device_info.dart';
import '../../models/register_address_type.dart';
import '../../models/register_entry.dart';
import '../../models/register_list.dart';
import '../../models/status_entry.dart';
import '../../navigation/navigation_targets.dart';
import '../../runtime/runtime_ports.dart';
import '../../services/device_repository.dart';

class RegistersController extends ChangeNotifier {
  final DeviceRepository _repository;
  final ConnectionRuntime _connectionRuntime;
  final RegisterRuntime _registerRuntime;

  String? _selectedDeviceId;
  String? _selectedListId;
  final Map<int, (String, String?, DateTime?)> _runtimeValues = {};
  final Map<(String, int), (bool, bool?, DateTime?)> _runtimeStatusValues = {};

  RegistersController(
    this._repository,
    this._connectionRuntime,
    this._registerRuntime,
  ) {
    _repository.devices.addListener(_onRepositoryChanged);
    _connectionRuntime.connectedDeviceIds.addListener(_forwardChange);
    _selectFallbackDevice();
  }

  List<DeviceInfo> get devices => _repository.snapshot;

  DeviceInfo? get selectedDevice => _selectedDeviceId == null
      ? null
      : _repository.findById(_selectedDeviceId!);

  String? get selectedDeviceId => selectedDevice?.id;

  List<RegisterList> get lists => selectedDevice?.registerLists ?? const [];

  int get activeListIndex {
    final index = lists.indexWhere((list) => list.id == _selectedListId);
    return index < 0 ? 0 : index;
  }

  RegisterList? get activeList =>
      lists.isEmpty ? null : lists[activeListIndex.clamp(0, lists.length - 1)];

  Map<int, (String, String?, DateTime?)> get runtimeValues =>
      Map.unmodifiable(_runtimeValues);

  Map<(String, int), (bool, bool?, DateTime?)> get runtimeStatusValues =>
      Map.unmodifiable(_runtimeStatusValues);

  DateTime? get lastRegisterReadAt =>
      _latestReadAt(_runtimeValues.values.map((value) => value.$3));

  DateTime? get lastStatusReadAt =>
      _latestReadAt(_runtimeStatusValues.values.map((value) => value.$3));

  bool isConnected(DeviceInfo device) => _connectionRuntime.isConnected(device);

  List<DeviceInfo> get connectedDevices =>
      devices.where(_connectionRuntime.isConnected).toList();

  List<RegisterEntry> referenceRegisters(int startAddress, int count) =>
      _registerRuntime.registersForRange(startAddress, count);

  List<StatusEntry> referenceStatuses(int startAddress, int count) =>
      _registerRuntime.statusesForRange(startAddress, count);

  Future<void> selectTarget(RegistersRouteArgs target) async {
    if (_selectedDeviceId != target.deviceId) {
      _runtimeValues.clear();
      _runtimeStatusValues.clear();
    }
    _selectedDeviceId = target.deviceId;
    _selectedListId = target.registerListId;
    await ensureSelectedList();
    notifyListeners();
  }

  Future<void> selectDevice(String deviceId) async {
    if (_selectedDeviceId == deviceId) return;
    _runtimeValues.clear();
    _runtimeStatusValues.clear();
    _selectedDeviceId = deviceId;
    _selectedListId = null;
    await ensureSelectedList();
    notifyListeners();
  }

  void selectList(String listId) {
    if (_selectedListId == listId) return;
    _selectedListId = listId;
    notifyListeners();
  }

  Future<void> ensureSelectedList() async {
    final device = selectedDevice;
    if (device == null) return;
    if (device.registerLists.isEmpty) {
      final list = RegisterList(name: 'List 1');
      await _repository.addRegisterList(device.id, list);
      _selectedListId = list.id;
      return;
    }
    if (!device.registerLists.any((list) => list.id == _selectedListId)) {
      _selectedListId = device.registerLists.first.id;
    }
  }

  Future<void> addList(RegisterList list) async {
    final device = selectedDevice;
    if (device == null) return;
    await _repository.addRegisterList(device.id, list);
    _selectedListId = list.id;
    notifyListeners();
  }

  Future<void> removeActiveList() async {
    final device = selectedDevice;
    final list = activeList;
    if (device == null || list == null || device.registerLists.length <= 1) {
      return;
    }
    await _repository.removeRegisterList(device.id, list.id);
    _selectedListId = null;
    await ensureSelectedList();
    notifyListeners();
  }

  Future<void> updateList(RegisterList list) async {
    final device = selectedDevice;
    if (device == null) return;
    await _repository.updateRegisterList(device.id, list);
  }

  Future<void> updateEntry(
    int address,
    String typeName,
    String? comment,
  ) async {
    final device = selectedDevice;
    final list = activeList;
    if (device == null || list == null) return;
    await _repository.upsertRegisterConfig(
      device.id,
      list.id,
      RegisterConfig(address: address, typeName: typeName, comment: comment),
    );
  }

  Future<void> setAllTypes(String typeName) async {
    final list = activeList;
    if (list == null) return;
    final offset = RegisterAddressType.fromCode(list.regType).displayOffset;
    final startAddress = offset + list.startAddress;
    final entries = List.of(list.entries);

    for (var i = 0; i < list.count; i++) {
      final address = startAddress + i;
      final index = entries.indexWhere((entry) => entry.address == address);
      if (index == -1) {
        entries.add(RegisterConfig(address: address, typeName: typeName));
      } else {
        entries[index] = entries[index].copyWith(typeName: typeName);
      }
    }

    await updateList(list.copyWith(entries: entries));
  }

  Future<void> updateStatusEntry(
    String statusType,
    int address,
    String? comment,
  ) async {
    final device = selectedDevice;
    final list = activeList;
    if (device == null || list == null) return;
    await _repository.upsertStatusConfig(
      device.id,
      list.id,
      StatusConfig(statusType: statusType, address: address, comment: comment),
    );
  }

  Future<void> writeValue(int address, String value) async {
    final device = selectedDevice;
    if (device == null) return;
    if (!AppSettings.instance.writeEnabled) return;
    if (!_connectionRuntime.isConnected(device)) {
      throw StateError('${device.name} is not connected.');
    }
    final raw = int.tryParse(value);
    if (raw == null || raw < 0 || raw > 0xffff) {
      throw ArgumentError.value(value, 'value');
    }
    final modbusAddress = RegisterAddressType.holdingRegisters.toModbusAddress(
      address,
      addressBase: AppSettings.instance.addressBaseStart,
    );
    final runtimeValue = _runtimeValues[address];
    final previous = runtimeValue?.$1;
    await _connectionRuntime.writeHoldingRegister(
      device,
      address: modbusAddress,
      value: raw,
    );
    _runtimeValues[address] = (value, previous, DateTime.now());
    notifyListeners();
  }

  Future<void> writeStatusValue({
    required String statusType,
    required int address,
    required bool value,
  }) async {
    final device = selectedDevice;
    if (device == null) return;
    if (!AppSettings.instance.writeEnabled) return;
    if (!_connectionRuntime.isConnected(device)) {
      throw StateError('${device.name} is not connected.');
    }

    final addressType = RegisterAddressType.tryParse(statusType);
    if (addressType == null || addressType != RegisterAddressType.coils) {
      throw UnsupportedError('Writing $statusType is not implemented.');
    }
    final modbusAddress = addressType.toModbusAddress(
      address,
      addressBase: AppSettings.instance.addressBaseStart,
    );

    final key = (statusType, address);
    final runtimeValue = _runtimeStatusValues[key];
    final previous = runtimeValue?.$1;
    await _connectionRuntime.writeCoil(
      device,
      address: modbusAddress,
      value: value,
    );
    _runtimeStatusValues[key] = (value, previous, DateTime.now());
    notifyListeners();
  }

  Future<void> readRegisters({
    required String regType,
    required int startAddress,
    required int count,
  }) async {
    final device = selectedDevice;
    if (device == null) {
      throw StateError('Select a device before reading registers.');
    }
    if (!_connectionRuntime.isConnected(device)) {
      throw StateError('${device.name} is not connected.');
    }

    final addressType = RegisterAddressType.tryParse(regType);
    if (addressType == null || !addressType.supportsRegisterRead) {
      throw UnsupportedError('Reading $regType is not implemented.');
    }
    final modbusStartAddress = addressType.toModbusAddress(
      startAddress,
      addressBase: AppSettings.instance.addressBaseStart,
    );
    final values = switch (addressType) {
      RegisterAddressType.holdingRegisters =>
        await _connectionRuntime.readHoldingRegisters(
          device,
          startAddress: modbusStartAddress,
          count: count,
        ),
      RegisterAddressType.inputRegisters =>
        await _connectionRuntime.readInputRegisters(
          device,
          startAddress: modbusStartAddress,
          count: count,
        ),
      _ => throw UnsupportedError('Reading $regType is not implemented.'),
    };

    final readAt = DateTime.now();
    for (var index = 0; index < values.length; index++) {
      final address = startAddress + index;
      final previous = _runtimeValues[address]?.$1;
      _runtimeValues[address] = (values[index].toString(), previous, readAt);
    }
    notifyListeners();
  }

  Future<void> readStatuses({
    required String statusType,
    required int startAddress,
    required int count,
  }) async {
    final device = selectedDevice;
    if (device == null) {
      throw StateError('Select a device before reading status values.');
    }
    if (!_connectionRuntime.isConnected(device)) {
      throw StateError('${device.name} is not connected.');
    }

    final addressType = RegisterAddressType.tryParse(statusType);
    if (addressType == null || !addressType.supportsStatusRead) {
      throw UnsupportedError('Reading $statusType is not implemented.');
    }
    final modbusStartAddress = addressType.toModbusAddress(
      startAddress,
      addressBase: AppSettings.instance.addressBaseStart,
    );
    final values = switch (addressType) {
      RegisterAddressType.coils => await _connectionRuntime.readCoils(
        device,
        startAddress: modbusStartAddress,
        count: count,
      ),
      RegisterAddressType.discreteInputs =>
        await _connectionRuntime.readDiscreteInputs(
          device,
          startAddress: modbusStartAddress,
          count: count,
        ),
      _ => throw UnsupportedError('Reading $statusType is not implemented.'),
    };

    final readAt = DateTime.now();
    for (var index = 0; index < values.length; index++) {
      final address = startAddress + index;
      final key = (statusType, address);
      final previous = _runtimeStatusValues[key]?.$1;
      _runtimeStatusValues[key] = (values[index], previous, readAt);
    }
    notifyListeners();
  }

  void _selectFallbackDevice() {
    if (_selectedDeviceId != null || devices.isEmpty) return;
    _selectedDeviceId = devices.first.id;
    _selectedListId = devices.first.registerLists.isEmpty
        ? null
        : devices.first.registerLists.first.id;
  }

  void _onRepositoryChanged() {
    _selectFallbackDevice();
    if (selectedDevice == null) {
      _selectedDeviceId = devices.isEmpty ? null : devices.first.id;
      final firstLists = devices.isEmpty
          ? const <RegisterList>[]
          : devices.first.registerLists;
      _selectedListId = firstLists.isEmpty ? null : firstLists.first.id;
    }
    notifyListeners();
  }

  void _forwardChange() => notifyListeners();

  @override
  void dispose() {
    _repository.devices.removeListener(_onRepositoryChanged);
    _connectionRuntime.connectedDeviceIds.removeListener(_forwardChange);
    super.dispose();
  }
}

DateTime? _latestReadAt(Iterable<DateTime?> timestamps) {
  DateTime? latest;
  for (final timestamp in timestamps) {
    if (timestamp != null && (latest == null || timestamp.isAfter(latest))) {
      latest = timestamp;
    }
  }
  return latest;
}
