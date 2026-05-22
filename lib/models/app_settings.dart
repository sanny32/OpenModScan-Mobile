import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  static const _themeModeKey = 'themeMode';
  static const _localeKey = 'locale';
  static const registerOrders = ['MSRF', 'LSRF'];
  static const byteOrders = ['Direct', 'Swapped'];
  static const addressBases = ['0-based', '1-based'];
  static const readFailureAttemptOptions = [1, 2, 3, 5, 10];
  static const themeOptions = ['System', 'Light', 'Dark'];
  static const languageOptions = ['System', 'English', 'Russian'];

  String connectionType = 'Modbus TCP';
  int timeout = 1000;
  int reconnectDelay = 3000;
  int readFailureAttempts = 3;
  int defaultUnitId = 1;
  int defaultReadQty = 20;
  String addressBase = addressBases.first;
  String registerOrder = registerOrders.first;
  String byteOrder = byteOrders.first;
  bool confirmBeforeWrite = true;
  bool showLastValues = true;
  bool saveLogToFile = false;
  bool clearLogOnDisconnect = false;
  int maxLogEntries = 1000;

  final showTypeBadgesNotifier = ValueNotifier<bool>(false);
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
  final localeNotifier = ValueNotifier<Locale?>(null);

  bool get showTypeBadges => showTypeBadgesNotifier.value;
  set showTypeBadges(bool v) => showTypeBadgesNotifier.value = v;

  ThemeMode get themeMode => themeModeNotifier.value;
  String get theme => _themeLabel(themeMode);
  Locale? get locale => localeNotifier.value;
  String get language => _languageLabel(locale);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeModeNotifier.value = _themeModeFromValue(
      prefs.getString(_themeModeKey),
    );
    localeNotifier.value = _localeFromValue(prefs.getString(_localeKey));
  }

  Future<void> setTheme(String value) async {
    await _setThemeMode(_themeModeFromValue(value));
  }

  Future<void> setLanguage(String value) async {
    await _setLocale(_localeFromValue(value));
  }

  Future<void> resetToDefaults() async {
    connectionType = 'Modbus TCP';
    timeout = 1000;
    reconnectDelay = 3000;
    readFailureAttempts = 3;
    defaultUnitId = 1;
    defaultReadQty = 20;
    addressBase = addressBases.first;
    registerOrder = registerOrders.first;
    byteOrder = byteOrders.first;
    confirmBeforeWrite = true;
    showLastValues = true;
    showTypeBadges = false;
    saveLogToFile = false;
    clearLogOnDisconnect = false;
    maxLogEntries = 1000;
    await _setThemeMode(ThemeMode.system);
    await _setLocale(null);
  }

  Future<void> _setThemeMode(ThemeMode value) async {
    themeModeNotifier.value = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value.name);
  }

  Future<void> _setLocale(Locale? value) async {
    localeNotifier.value = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, value?.languageCode ?? 'system');
  }

  ThemeMode _themeModeFromValue(String? value) {
    switch (value) {
      case 'light':
      case 'Light':
        return ThemeMode.light;
      case 'dark':
      case 'Dark':
        return ThemeMode.dark;
      case 'system':
      case 'System':
      default:
        return ThemeMode.system;
    }
  }

  String _themeLabel(ThemeMode value) {
    switch (value) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Locale? _localeFromValue(String? value) {
    switch (value) {
      case 'en':
      case 'English':
        return const Locale('en');
      case 'ru':
      case 'Russian':
        return const Locale('ru');
      case 'system':
      case 'System':
      default:
        return null;
    }
  }

  String _languageLabel(Locale? value) {
    switch (value?.languageCode) {
      case 'en':
        return 'English';
      case 'ru':
        return 'Russian';
      default:
        return 'System';
    }
  }
}
