import 'package:shared_preferences/shared_preferences.dart';

/// Typed key/value persistence for [AppSettings], mirroring [DeviceStore].
/// Keeps the settings model free of any `SharedPreferences` dependency so it
/// can be unit-tested against an in-memory fake.
abstract interface class SettingsStore {
  /// Hydrates the backing store. Must be awaited before any synchronous getter.
  Future<void> load();

  String? getString(String key);

  int? getInt(String key);

  bool? getBool(String key);

  Future<void> setString(String key, String value);

  Future<void> setInt(String key, int value);

  Future<void> setBool(String key, bool value);
}

class SharedPreferencesSettingsStore implements SettingsStore {
  SharedPreferences? _prefs;

  SharedPreferences get _require {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('SettingsStore.load() must be called before reading.');
    }
    return prefs;
  }

  @override
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  String? getString(String key) {
    final value = _require.get(key);
    return value is String ? value : null;
  }

  @override
  int? getInt(String key) => _require.getInt(key);

  @override
  bool? getBool(String key) => _require.getBool(key);

  @override
  Future<void> setString(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<void> setInt(String key, int value) async =>
      (await SharedPreferences.getInstance()).setInt(key, value);

  @override
  Future<void> setBool(String key, bool value) async =>
      (await SharedPreferences.getInstance()).setBool(key, value);
}
