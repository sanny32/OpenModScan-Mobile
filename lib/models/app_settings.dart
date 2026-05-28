import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_info.dart';
import 'modbus_scan.dart';

class AppSettings {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  static const _themeModeKey = 'themeMode';
  static const _localeKey = 'locale';
  static const _connectionTypeKey = 'connectionType';
  static const _timeoutKey = 'timeout';
  static const _reconnectDelayKey = 'reconnectDelay';
  static const _readFailureAttemptsKey = 'readFailureAttempts';
  static const _defaultUnitIdKey = 'defaultUnitId';
  static const _defaultReadQtyKey = 'defaultReadQty';
  static const _addressBaseKey = 'addressBase';
  static const _registerOrderKey = 'registerOrder';
  static const _byteOrderKey = 'byteOrder';
  static const _writeEnabledKey = 'writeEnabled';
  static const _confirmBeforeWriteKey = 'confirmBeforeWrite';
  static const _showLastValuesKey = 'showLastValues';
  static const _showTypeBadgesKey = 'showTypeBadges';
  static const _saveLogToFileKey = 'saveLogToFile';
  static const _clearLogOnDisconnectKey = 'clearLogOnDisconnect';
  static const _maxLogEntriesKey = 'maxLogEntries';
  static const _scanProtocolKey = 'scanProtocol';
  static const _scanSubnetPrefixKey = 'scanSubnetPrefix';
  static const _scanPortStartKey = 'scanPortStart';
  static const _scanPortEndKey = 'scanPortEnd';
  static const _scanUnitIdStartKey = 'scanUnitIdStart';
  static const _scanUnitIdEndKey = 'scanUnitIdEnd';
  static const _scanRequestTypeKey = 'scanRequestType';
  static const _scanRequestAddressKey = 'scanRequestAddress';
  static const _savedDevicesSortModeKey = 'savedDevicesSortMode';
  static const _scanClearOnStartKey = 'scanClearOnStart';
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
  bool writeEnabled = true;
  bool confirmBeforeWrite = false;
  bool saveLogToFile = false;
  bool clearLogOnDisconnect = false;
  int maxLogEntries = 1000;
  ProtocolType scanProtocol = ProtocolType.modbusTcp;
  int scanSubnetPrefix = 24;
  int scanPortStart = 502;
  int scanPortEnd = 502;
  int scanUnitIdStart = 1;
  int scanUnitIdEnd = 10;
  ModbusScanRequestType scanRequestType =
      ModbusScanRequestType.holdingRegisters;
  int scanRequestAddress = 0;
  DeviceSortMode savedDevicesSortMode = DeviceSortMode.lastConnected;
  bool scanClearOnStart = true;

  final showLastValuesNotifier = ValueNotifier<bool>(true);
  final showTypeBadgesNotifier = ValueNotifier<bool>(false);
  final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
  final localeNotifier = ValueNotifier<Locale?>(null);

  bool get showLastValues => showLastValuesNotifier.value;
  set showLastValues(bool v) => showLastValuesNotifier.value = v;

  bool get showTypeBadges => showTypeBadgesNotifier.value;
  set showTypeBadges(bool v) => showTypeBadgesNotifier.value = v;

  bool get usesZeroBasedAddresses => addressBase == addressBases.first;

  int get addressBaseStart => usesZeroBasedAddresses ? 0 : 1;

  ThemeMode get themeMode => themeModeNotifier.value;
  String get theme => _themeLabel(themeMode);
  Locale? get locale => localeNotifier.value;
  String get language => _languageLabel(locale);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    connectionType = _getString(prefs, _connectionTypeKey) ?? 'Modbus TCP';
    timeout = prefs.getInt(_timeoutKey) ?? 1000;
    reconnectDelay = prefs.getInt(_reconnectDelayKey) ?? 3000;
    readFailureAttempts = prefs.getInt(_readFailureAttemptsKey) ?? 3;
    defaultUnitId = prefs.getInt(_defaultUnitIdKey) ?? 1;
    defaultReadQty = prefs.getInt(_defaultReadQtyKey) ?? 20;
    addressBase = _getString(prefs, _addressBaseKey) ?? addressBases.first;
    registerOrder =
        _getString(prefs, _registerOrderKey) ?? registerOrders.first;
    byteOrder = _getString(prefs, _byteOrderKey) ?? byteOrders.first;
    writeEnabled = prefs.getBool(_writeEnabledKey) ?? true;
    confirmBeforeWrite = prefs.getBool(_confirmBeforeWriteKey) ?? false;
    showLastValuesNotifier.value = prefs.getBool(_showLastValuesKey) ?? true;
    showTypeBadgesNotifier.value = prefs.getBool(_showTypeBadgesKey) ?? false;
    saveLogToFile = prefs.getBool(_saveLogToFileKey) ?? false;
    clearLogOnDisconnect = prefs.getBool(_clearLogOnDisconnectKey) ?? false;
    maxLogEntries = prefs.getInt(_maxLogEntriesKey) ?? 1000;
    scanProtocol = _protocolFromValue(_getString(prefs, _scanProtocolKey));
    scanSubnetPrefix = _clampInt(
      prefs.getInt(_scanSubnetPrefixKey) ?? 24,
      16,
      30,
    );
    scanPortStart = _clampInt(prefs.getInt(_scanPortStartKey) ?? 502, 1, 65535);
    scanPortEnd = _clampInt(prefs.getInt(_scanPortEndKey) ?? 502, 1, 65535);
    scanUnitIdStart = _clampInt(prefs.getInt(_scanUnitIdStartKey) ?? 1, 1, 247);
    scanUnitIdEnd = _clampInt(prefs.getInt(_scanUnitIdEndKey) ?? 10, 1, 247);
    _normalizeScanRanges();
    scanRequestType = ModbusScanRequestTypeX.fromName(
      _getString(prefs, _scanRequestTypeKey),
    );
    scanRequestAddress = _clampInt(
      prefs.getInt(_scanRequestAddressKey) ?? 0,
      0,
      0xffff,
    );
    savedDevicesSortMode = _deviceSortModeFromValue(
      _getString(prefs, _savedDevicesSortModeKey),
    );
    scanClearOnStart = prefs.getBool(_scanClearOnStartKey) ?? true;
    themeModeNotifier.value = _themeModeFromValue(
      _getString(prefs, _themeModeKey),
    );
    localeNotifier.value = _localeFromValue(_getString(prefs, _localeKey));
  }

  // Guards against keys that were previously stored as a different type.
  String? _getString(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    if (value is String) return value;
    return null;
  }

  Future<void> setTheme(String value) async {
    await _setThemeMode(_themeModeFromValue(value));
  }

  Future<void> setLanguage(String value) async {
    await _setLocale(_localeFromValue(value));
  }

  Future<void> setReadFailureAttempts(int value) async {
    readFailureAttempts = value;
    await _saveEditableValues();
  }

  Future<void> setAddressBase(String value) async {
    addressBase = value;
    await _saveEditableValues();
  }

  Future<void> setRegisterOrder(String value) async {
    registerOrder = value;
    await _saveEditableValues();
  }

  Future<void> setByteOrder(String value) async {
    byteOrder = value;
    await _saveEditableValues();
  }

  Future<void> setWriteEnabled(bool value) async {
    writeEnabled = value;
    await _saveEditableValues();
  }

  Future<void> setConfirmBeforeWrite(bool value) async {
    confirmBeforeWrite = value;
    await _saveEditableValues();
  }

  Future<void> setShowLastValues(bool value) async {
    showLastValues = value;
    await _saveEditableValues();
  }

  Future<void> setShowTypeBadges(bool value) async {
    showTypeBadges = value;
    await _saveEditableValues();
  }

  Future<void> setSaveLogToFile(bool value) async {
    saveLogToFile = value;
    await _saveEditableValues();
  }

  Future<void> setClearLogOnDisconnect(bool value) async {
    clearLogOnDisconnect = value;
    await _saveEditableValues();
  }

  Future<void> setScanProtocol(ProtocolType value) async {
    scanProtocol = value;
    await _saveEditableValues();
  }

  Future<void> setScanSubnetPrefix(int value) async {
    scanSubnetPrefix = _clampInt(value, 16, 30);
    await _saveEditableValues();
  }

  Future<void> setScanPortRange(int start, int end) async {
    scanPortStart = _clampInt(start, 1, 65535);
    scanPortEnd = _clampInt(end, 1, 65535);
    _normalizeScanRanges();
    await _saveEditableValues();
  }

  Future<void> setScanUnitIdRange(int start, int end) async {
    scanUnitIdStart = _clampInt(start, 1, 247);
    scanUnitIdEnd = _clampInt(end, 1, 247);
    _normalizeScanRanges();
    await _saveEditableValues();
  }

  Future<void> setScanRequestType(ModbusScanRequestType value) async {
    scanRequestType = value;
    await _saveEditableValues();
  }

  Future<void> setScanRequestAddress(int value) async {
    scanRequestAddress = _clampInt(value, 0, 0xffff);
    await _saveEditableValues();
  }

  Future<void> setSavedDevicesSortMode(DeviceSortMode value) async {
    savedDevicesSortMode = value;
    await _saveEditableValues();
  }

  Future<void> setScanClearOnStart(bool value) async {
    scanClearOnStart = value;
    await _saveEditableValues();
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
    writeEnabled = true;
    confirmBeforeWrite = false;
    showLastValues = true;
    showTypeBadges = false;
    saveLogToFile = false;
    clearLogOnDisconnect = false;
    maxLogEntries = 1000;
    scanProtocol = ProtocolType.modbusTcp;
    scanSubnetPrefix = 24;
    scanPortStart = 502;
    scanPortEnd = 502;
    scanUnitIdStart = 1;
    scanUnitIdEnd = 10;
    scanRequestType = ModbusScanRequestType.holdingRegisters;
    scanRequestAddress = 0;
    savedDevicesSortMode = DeviceSortMode.lastConnected;
    scanClearOnStart = true;
    await _saveEditableValues();
    await _setThemeMode(ThemeMode.system);
    await _setLocale(null);
  }

  Future<void> _saveEditableValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_connectionTypeKey, connectionType);
    await prefs.setInt(_timeoutKey, timeout);
    await prefs.setInt(_reconnectDelayKey, reconnectDelay);
    await prefs.setInt(_readFailureAttemptsKey, readFailureAttempts);
    await prefs.setInt(_defaultUnitIdKey, defaultUnitId);
    await prefs.setInt(_defaultReadQtyKey, defaultReadQty);
    await prefs.setString(_addressBaseKey, addressBase);
    await prefs.setString(_registerOrderKey, registerOrder);
    await prefs.setString(_byteOrderKey, byteOrder);
    await prefs.setBool(_writeEnabledKey, writeEnabled);
    await prefs.setBool(_confirmBeforeWriteKey, confirmBeforeWrite);
    await prefs.setBool(_showLastValuesKey, showLastValues);
    await prefs.setBool(_showTypeBadgesKey, showTypeBadges);
    await prefs.setBool(_saveLogToFileKey, saveLogToFile);
    await prefs.setBool(_clearLogOnDisconnectKey, clearLogOnDisconnect);
    await prefs.setInt(_maxLogEntriesKey, maxLogEntries);
    await prefs.setString(_scanProtocolKey, scanProtocol.name);
    await prefs.setInt(_scanSubnetPrefixKey, scanSubnetPrefix);
    await prefs.setInt(_scanPortStartKey, scanPortStart);
    await prefs.setInt(_scanPortEndKey, scanPortEnd);
    await prefs.setInt(_scanUnitIdStartKey, scanUnitIdStart);
    await prefs.setInt(_scanUnitIdEndKey, scanUnitIdEnd);
    await prefs.setString(_scanRequestTypeKey, scanRequestType.name);
    await prefs.setInt(_scanRequestAddressKey, scanRequestAddress);
    await prefs.setString(_savedDevicesSortModeKey, savedDevicesSortMode.name);
    await prefs.setBool(_scanClearOnStartKey, scanClearOnStart);
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

  ProtocolType _protocolFromValue(String? value) {
    return ProtocolType.values.firstWhere(
      (protocol) => protocol.name == value,
      orElse: () => ProtocolType.modbusTcp,
    );
  }

  DeviceSortMode _deviceSortModeFromValue(String? value) {
    return DeviceSortMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => DeviceSortMode.lastConnected,
    );
  }

  static int _clampInt(int value, int min, int max) =>
      value.clamp(min, max).toInt();

  void _normalizeScanRanges() {
    if (scanPortStart > scanPortEnd) {
      final tmp = scanPortStart;
      scanPortStart = scanPortEnd;
      scanPortEnd = tmp;
    }
    if (scanUnitIdStart > scanUnitIdEnd) {
      final tmp = scanUnitIdStart;
      scanUnitIdStart = scanUnitIdEnd;
      scanUnitIdEnd = tmp;
    }
  }
}
