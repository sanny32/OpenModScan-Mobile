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
    final migratedBase = DateTime.fromMillisecondsSinceEpoch(0);
    return [
      for (var index = 0; index < list.length; index++)
        DeviceInfo.fromJson(
          list[index] as Map<String, dynamic>,
          fallbackCreatedAt: migratedBase.add(Duration(milliseconds: index)),
        ),
    ];
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
