import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';

class DeviceRepository {
  static const _key = 'devices';
  static final DeviceRepository instance = DeviceRepository._();
  DeviceRepository._();

  Future<List<DeviceInfo>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<DeviceInfo> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(devices.map((d) => d.toJson()).toList()));
  }
}
