import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_info.dart';

abstract interface class DeviceStore {
  Future<List<DeviceInfo>> load();

  Future<void> save(List<DeviceInfo> devices);
}

class SharedPreferencesDeviceStore implements DeviceStore {
  static const key = 'devicesV2';

  const SharedPreferencesDeviceStore();

  @override
  Future<List<DeviceInfo>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> save(List<DeviceInfo> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(devices.map((device) => device.toJson()).toList()),
    );
  }
}
