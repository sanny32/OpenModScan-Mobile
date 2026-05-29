import 'package:flutter/foundation.dart';

import '../models/device_info.dart';
import '../models/register_list.dart';
import 'device_store.dart';

/// Storage-agnostic contract the controllers depend on, mirroring the
/// [ConnectionRuntime]/[DeviceScannerPort] ports. Keeps controllers decoupled
/// from the concrete [DeviceRepository] implementation for testability.
abstract interface class DeviceRepositoryPort {
  ValueListenable<List<DeviceInfo>> get devices;

  List<DeviceInfo> get snapshot;

  DeviceInfo? findById(String id);

  Future<void> replaceAll(List<DeviceInfo> newDevices);

  Future<void> add(DeviceInfo device);

  Future<void> insert(int index, DeviceInfo device);

  Future<void> update(DeviceInfo device);

  Future<DeviceInfo?> remove(String deviceId);

  Future<void> addRegisterList(String deviceId, RegisterList list);

  Future<void> removeRegisterList(String deviceId, String listId);

  Future<void> updateRegisterList(String deviceId, RegisterList registerList);

  Future<void> upsertRegisterConfig(
    String deviceId,
    String listId,
    RegisterConfig config,
  );

  Future<void> upsertStatusConfig(
    String deviceId,
    String listId,
    StatusConfig config,
  );
}

class DeviceRepository implements DeviceRepositoryPort {
  static final DeviceRepository instance = DeviceRepository(
    const SharedPreferencesDeviceStore(),
  );

  final DeviceStore _store;

  DeviceRepository(this._store);

  @override
  final ValueNotifier<List<DeviceInfo>> devices = ValueNotifier(const []);
  bool _initialized = false;

  @override
  List<DeviceInfo> get snapshot => List.unmodifiable(devices.value);

  @override
  DeviceInfo? findById(String id) {
    for (final device in devices.value) {
      if (device.id == id) return device;
    }
    return null;
  }

  Future<void> initialize({Iterable<DeviceInfo> seedDevices = const []}) async {
    if (_initialized) return;
    final loaded = await load();
    devices.value = loaded.isEmpty ? List.of(seedDevices) : loaded;
    _initialized = true;
  }

  Future<List<DeviceInfo>> load() => _store.load();

  @override
  Future<void> replaceAll(List<DeviceInfo> newDevices) async {
    devices.value = List.of(newDevices);
    await _store.save(newDevices);
  }

  @override
  Future<void> add(DeviceInfo device) async {
    await replaceAll([...devices.value, device]);
  }

  @override
  Future<void> insert(int index, DeviceInfo device) async {
    final updated = List.of(devices.value);
    updated.insert(index.clamp(0, updated.length), device);
    await replaceAll(updated);
  }

  @override
  Future<void> update(DeviceInfo device) async {
    final updated = List.of(devices.value);
    final index = updated.indexWhere((item) => item.id == device.id);
    if (index == -1) return;
    updated[index] = device;
    await replaceAll(updated);
  }

  @override
  Future<DeviceInfo?> remove(String deviceId) async {
    final updated = List.of(devices.value);
    final index = updated.indexWhere((item) => item.id == deviceId);
    if (index == -1) return null;
    final removed = updated.removeAt(index);
    await replaceAll(updated);
    return removed;
  }

  @override
  Future<void> addRegisterList(String deviceId, RegisterList list) async {
    final device = findById(deviceId);
    if (device == null) return;
    await update(
      device.copyWith(registerLists: [...device.registerLists, list]),
    );
  }

  @override
  Future<void> removeRegisterList(String deviceId, String listId) async {
    final device = findById(deviceId);
    if (device == null) return;
    await update(
      device.copyWith(
        registerLists: device.registerLists
            .where((list) => list.id != listId)
            .toList(),
      ),
    );
  }

  @override
  Future<void> updateRegisterList(
    String deviceId,
    RegisterList registerList,
  ) async {
    final device = findById(deviceId);
    if (device == null) return;
    final updated = List.of(device.registerLists);
    final index = updated.indexWhere((list) => list.id == registerList.id);
    if (index == -1) return;
    updated[index] = registerList;
    await update(device.copyWith(registerLists: updated));
  }

  @override
  Future<void> upsertRegisterConfig(
    String deviceId,
    String listId,
    RegisterConfig config,
  ) async {
    final device = findById(deviceId);
    if (device == null) return;
    final indexOfList = device.registerLists.indexWhere(
      (item) => item.id == listId,
    );
    if (indexOfList == -1) return;
    final list = device.registerLists[indexOfList];
    final entries = List.of(list.entries);
    final index = entries.indexWhere((item) => item.address == config.address);
    if (index == -1) {
      entries.add(config);
    } else {
      entries[index] = config;
    }
    await updateRegisterList(deviceId, list.copyWith(entries: entries));
  }

  @override
  Future<void> upsertStatusConfig(
    String deviceId,
    String listId,
    StatusConfig config,
  ) async {
    final device = findById(deviceId);
    if (device == null) return;
    final indexOfList = device.registerLists.indexWhere(
      (item) => item.id == listId,
    );
    if (indexOfList == -1) return;
    final list = device.registerLists[indexOfList];
    final entries = List.of(list.statusEntries);
    final index = entries.indexWhere(
      (item) =>
          item.statusType == config.statusType &&
          item.address == config.address,
    );
    if (index == -1) {
      entries.add(config);
    } else {
      entries[index] = config;
    }
    await updateRegisterList(deviceId, list.copyWith(statusEntries: entries));
  }
}
