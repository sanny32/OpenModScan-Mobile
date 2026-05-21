import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';

class DeviceRepository {
  static const _key = 'devices';
  static final DeviceRepository instance = DeviceRepository._();
  DeviceRepository._();

  final ValueNotifier<List<DeviceInfo>> devices = ValueNotifier(const []);

  void updateInMemory(List<DeviceInfo> updated) {
    devices.value = List.of(updated);
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

  Future<void> save(List<DeviceInfo> newDevices) async {
    updateInMemory(newDevices);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(newDevices.map((d) => d.toJson()).toList()));
  }
}
