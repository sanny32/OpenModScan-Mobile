import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';
import '../models/register_list.dart';

class DeviceRepository {
  static const _key = 'devicesV2';
  static final DeviceRepository instance = DeviceRepository._();
  DeviceRepository._();

  final ValueNotifier<List<DeviceInfo>> devices = ValueNotifier(const []);
  bool _initialized = false;

  List<DeviceInfo> get snapshot => List.unmodifiable(devices.value);

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

  Future<List<DeviceInfo>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> replaceAll(List<DeviceInfo> newDevices) async {
    devices.value = List.of(newDevices);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(newDevices.map((d) => d.toJson()).toList()),
    );
  }

  Future<void> add(DeviceInfo device) async {
    await replaceAll([...devices.value, device]);
  }

  Future<void> insert(int index, DeviceInfo device) async {
    final updated = List.of(devices.value);
    updated.insert(index.clamp(0, updated.length), device);
    await replaceAll(updated);
  }

  Future<void> update(DeviceInfo device) async {
    final updated = List.of(devices.value);
    final index = updated.indexWhere((item) => item.id == device.id);
    if (index == -1) return;
    updated[index] = device;
    await replaceAll(updated);
  }

  Future<DeviceInfo?> remove(String deviceId) async {
    final updated = List.of(devices.value);
    final index = updated.indexWhere((item) => item.id == deviceId);
    if (index == -1) return null;
    final removed = updated.removeAt(index);
    await replaceAll(updated);
    return removed;
  }

  Future<void> addRegisterList(String deviceId, RegisterList list) async {
    final device = findById(deviceId);
    if (device == null) return;
    await update(
      device.copyWith(registerLists: [...device.registerLists, list]),
    );
  }

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
