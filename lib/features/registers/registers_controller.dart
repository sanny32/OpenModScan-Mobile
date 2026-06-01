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
import '../../utils/modbus_format.dart';
import 'register_runtime_value.dart';

class RegistersController extends ChangeNotifier {
  final DeviceRepositoryPort _repository;
  final ConnectionRuntime _connectionRuntime;
  final RegisterRuntime _registerRuntime;
  final AppSettings _settings;

  String? _selectedDeviceId;
  String? _selectedListId;
  final Map<int, RegisterRuntimeValue> _runtimeValues = {};
  final Map<(String, int), StatusRuntimeValue> _runtimeStatusValues = {};

  RegistersController(
    this._repository,
    this._connectionRuntime,
    this._registerRuntime,
    this._settings,
  ) {
    _repository.devices.addListener(_onRepositoryChanged);
    _connectionRuntime.connectedDeviceIds.addListener(_forwardChange);
    _settings.addressBaseNotifier.addListener(_onAddressBaseChanged);
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

  Map<int, RegisterRuntimeValue> get runtimeValues =>
      Map.unmodifiable(_runtimeValues);

  Map<(String, int), StatusRuntimeValue> get runtimeStatusValues =>
      Map.unmodifiable(_runtimeStatusValues);

  DateTime? get lastRegisterReadAt =>
      _latestReadAt(_runtimeValues.values.map((value) => value.readAt));

  DateTime? get lastStatusReadAt =>
      _latestReadAt(_runtimeStatusValues.values.map((value) => value.readAt));

  bool isConnected(DeviceInfo device) => _connectionRuntime.isConnected(device);

  List<DeviceInfo> get connectedDevices =>
      devices.where(_connectionRuntime.isConnected).toList();

  Future<void> toggleConnection(DeviceInfo device) async {
    if (_connectionRuntime.isConnected(device)) {
      await _connectionRuntime.disconnect(device);
      return;
    }
    await _connectionRuntime.connect(device);
    await _repository.update(device.copyWith(lastConnectedAt: DateTime.now()));
  }

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
    final addressType = RegisterAddressType.fromCode(list.regType);
    final canonicalAddress = addressType.toCanonicalAddress(
      address,
      addressBase: _settings.addressBaseStart,
    );
    await _repository.upsertRegisterConfig(
      device.id,
      list.id,
      RegisterConfig(
        address: canonicalAddress,
        typeName: typeName,
        comment: comment,
      ),
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
    final addressType = RegisterAddressType.fromCode(
      statusType,
      fallback: RegisterAddressType.coils,
    );
    final canonicalAddress = addressType.toCanonicalAddress(
      address,
      addressBase: _settings.addressBaseStart,
    );
    await _repository.upsertStatusConfig(
      device.id,
      list.id,
      StatusConfig(
        statusType: statusType,
        address: canonicalAddress,
        comment: comment,
      ),
    );
  }

  Future<String?> writeValue(int address, String value, String typeName) async {
    final device = selectedDevice;
    if (device == null) return null;
    if (!_settings.writeEnabled) return null;
    if (!_connectionRuntime.isConnected(device)) {
      throw StateError('${device.name} is not connected.');
    }
    final List<int> words;
    try {
      words = encodeRegisterValue(
        typeName,
        value,
        registerOrder: _settings.registerOrder,
        byteOrder: _settings.byteOrder,
      );
    } catch (_) {
      throw ArgumentError.value(value, 'value');
    }
    final modbusAddress = RegisterAddressType.holdingRegisters.toModbusAddress(
      address,
      addressBase: _settings.addressBaseStart,
    );
    if (words.length == 1) {
      await _connectionRuntime.writeHoldingRegister(
        device,
        address: modbusAddress,
        value: words.first,
      );
    } else {
      await _connectionRuntime.writeHoldingRegisters(
        device,
        startAddress: modbusAddress,
        values: words,
      );
    }
    // Read the value back from the device so the UI reflects its actual state
    // after the write, regardless of the auto-refresh setting.
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
    } catch (_) {
      // The write succeeded; keep the written words if the read-back fails.
    }
    final rawMap = {
      for (var i = 0; i < readBackWords.length; i++)
        address + i: readBackWords[i],
    };
    final newValue = computeDisplayValue(
      address,
      typeName,
      rawMap,
      registerOrder: _settings.registerOrder,
      byteOrder: _settings.byteOrder,
    );
    final readAt = DateTime.now();
    for (var i = 0; i < readBackWords.length; i++) {
      final wordAddress = address + i;
      final previous = _runtimeValues[wordAddress]?.value;
      _runtimeValues[wordAddress] = (
        value: readBackWords[i].toString(),
        previous: previous,
        readAt: readAt,
      );
    }
    notifyListeners();
    return newValue;
  }

  Future<bool?> writeStatusValue({
    required String statusType,
    required int address,
    required bool value,
  }) async {
    final device = selectedDevice;
    if (device == null) return null;
    if (!_settings.writeEnabled) return null;
    if (!_connectionRuntime.isConnected(device)) {
      throw StateError('${device.name} is not connected.');
    }

    final addressType = RegisterAddressType.tryParse(statusType);
    if (addressType == null || addressType != RegisterAddressType.coils) {
      throw UnsupportedError('Writing $statusType is not implemented.');
    }
    final modbusAddress = addressType.toModbusAddress(
      address,
      addressBase: _settings.addressBaseStart,
    );

    final key = (statusType, address);
    final previous = _runtimeStatusValues[key]?.value;
    await _connectionRuntime.writeCoil(
      device,
      address: modbusAddress,
      value: value,
    );
    // Read the value back from the device so the UI reflects its actual state
    // after the write, regardless of the auto-refresh setting.
    var newValue = value;
    try {
      final readBack = await _connectionRuntime.readCoils(
        device,
        startAddress: modbusAddress,
        count: 1,
      );
      if (readBack.isNotEmpty) newValue = readBack.first;
    } catch (_) {
      // The write succeeded; keep the written value if the read-back fails.
    }
    _runtimeStatusValues[key] = (
      value: newValue,
      previous: previous,
      readAt: DateTime.now(),
    );
    notifyListeners();
    return newValue;
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
      addressBase: _settings.addressBaseStart,
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
      final previous = _runtimeValues[address]?.value;
      _runtimeValues[address] = (
        value: values[index].toString(),
        previous: previous,
        readAt: readAt,
      );
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
      addressBase: _settings.addressBaseStart,
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
      final previous = _runtimeStatusValues[key]?.value;
      _runtimeStatusValues[key] = (
        value: values[index],
        previous: previous,
        readAt: readAt,
      );
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

  void _onAddressBaseChanged() {
    _runtimeValues.clear();
    _runtimeStatusValues.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.devices.removeListener(_onRepositoryChanged);
    _connectionRuntime.connectedDeviceIds.removeListener(_forwardChange);
    _settings.addressBaseNotifier.removeListener(_onAddressBaseChanged);
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
