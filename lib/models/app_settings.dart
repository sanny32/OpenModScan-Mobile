import 'package:flutter/material.dart';

import '../services/settings_store.dart';
import 'device_info.dart';
import 'modbus_scan.dart';

class AppSettings {
  static final AppSettings instance = AppSettings._();

  final SettingsStore _store;

  AppSettings._() : _store = SharedPreferencesSettingsStore();

  /// Test seam: build a settings instance over an injected [SettingsStore].
  @visibleForTesting
  AppSettings.withStore(this._store);

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
  static const _scanConnectTimeoutKey = 'scanConnectTimeout';
  static const _scanConcurrencyKey = 'scanConcurrency';
  static const _scanClearOnStartKey = 'scanClearOnStart';
  static const registerOrders = ['MSRF', 'LSRF'];
  static const byteOrders = ['Direct', 'Swapped'];
  static const addressBases = ['0-based', '1-based'];
  static const readFailureAttemptOptions = [1, 2, 3, 5, 10];
  static const themeOptions = ['System', 'Light', 'Dark'];
  static const languageOptions = ['System', 'English', 'Russian'];

  ProtocolType connectionType = ProtocolType.modbusTcp;
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
  int scanConnectTimeout = 300;
  int scanConcurrency = 32;
  bool scanClearOnStart = true;

  final showLastValuesNotifier = ValueNotifier<bool>(true);
  final showTypeBadgesNotifier = ValueNotifier<bool>(false);
  final addressBaseNotifier = ValueNotifier<String>(addressBases.first);
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
    await _store.load();
    connectionType = _protocolFromValue(_store.getString(_connectionTypeKey));
    timeout = _store.getInt(_timeoutKey) ?? 1000;
    reconnectDelay = _store.getInt(_reconnectDelayKey) ?? 3000;
    readFailureAttempts = _store.getInt(_readFailureAttemptsKey) ?? 3;
    defaultUnitId = _store.getInt(_defaultUnitIdKey) ?? 1;
    defaultReadQty = _store.getInt(_defaultReadQtyKey) ?? 20;
    _setAddressBaseValue(_store.getString(_addressBaseKey));
    registerOrder = _store.getString(_registerOrderKey) ?? registerOrders.first;
    byteOrder = _store.getString(_byteOrderKey) ?? byteOrders.first;
    writeEnabled = _store.getBool(_writeEnabledKey) ?? true;
    confirmBeforeWrite = _store.getBool(_confirmBeforeWriteKey) ?? false;
    showLastValuesNotifier.value = _store.getBool(_showLastValuesKey) ?? true;
    showTypeBadgesNotifier.value = _store.getBool(_showTypeBadgesKey) ?? false;
    saveLogToFile = _store.getBool(_saveLogToFileKey) ?? false;
    clearLogOnDisconnect = _store.getBool(_clearLogOnDisconnectKey) ?? false;
    maxLogEntries = _clampInt(
      _store.getInt(_maxLogEntriesKey) ?? 1000,
      50,
      100000,
    );
    scanProtocol = _protocolFromValue(_store.getString(_scanProtocolKey));
    scanSubnetPrefix = _clampInt(
      _store.getInt(_scanSubnetPrefixKey) ?? 24,
      16,
      30,
    );
    scanPortStart = _clampInt(
      _store.getInt(_scanPortStartKey) ?? 502,
      1,
      65535,
    );
    scanPortEnd = _clampInt(_store.getInt(_scanPortEndKey) ?? 502, 1, 65535);
    scanUnitIdStart = _clampInt(
      _store.getInt(_scanUnitIdStartKey) ?? 1,
      1,
      247,
    );
    scanUnitIdEnd = _clampInt(_store.getInt(_scanUnitIdEndKey) ?? 10, 1, 247);
    _normalizeScanRanges();
    scanRequestType = ModbusScanRequestTypeX.fromName(
      _store.getString(_scanRequestTypeKey),
    );
    scanRequestAddress = _clampInt(
      _store.getInt(_scanRequestAddressKey) ?? 0,
      0,
      0xffff,
    );
    scanConnectTimeout = _clampInt(
      _store.getInt(_scanConnectTimeoutKey) ?? 300,
      50,
      10000,
    );
    scanConcurrency = _clampInt(
      _store.getInt(_scanConcurrencyKey) ?? 32,
      1,
      256,
    );
    scanClearOnStart = _store.getBool(_scanClearOnStartKey) ?? true;
    themeModeNotifier.value = _themeModeFromValue(
      _store.getString(_themeModeKey),
    );
    localeNotifier.value = _localeFromValue(_store.getString(_localeKey));
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

  Future<void> setConnectionType(ProtocolType value) async {
    connectionType = value;
    await _saveEditableValues();
  }

  Future<void> setTimeout(int value) async {
    timeout = _clampInt(value, 100, 60000);
    await _saveEditableValues();
  }

  Future<void> setReconnectDelay(int value) async {
    reconnectDelay = _clampInt(value, 500, 60000);
    await _saveEditableValues();
  }

  Future<void> setDefaultUnitId(int value) async {
    defaultUnitId = _clampInt(value, 1, 247);
    await _saveEditableValues();
  }

  Future<void> setDefaultReadQty(int value) async {
    defaultReadQty = _clampInt(value, 1, 125);
    await _saveEditableValues();
  }

  Future<void> setAddressBase(String value) async {
    _setAddressBaseValue(value);
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

  Future<void> setMaxLogEntries(int value) async {
    maxLogEntries = _clampInt(value, 50, 100000);
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
    scanUnitIdStart = _clampInt(start, 1, 255);
    scanUnitIdEnd = _clampInt(end, 1, 255);
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

  Future<void> setScanConnectTimeout(int value) async {
    scanConnectTimeout = _clampInt(value, 50, 10000);
    await _saveEditableValues();
  }

  Future<void> setScanConcurrency(int value) async {
    scanConcurrency = _clampInt(value, 1, 256);
    await _saveEditableValues();
  }

  Future<void> setScanClearOnStart(bool value) async {
    scanClearOnStart = value;
    await _saveEditableValues();
  }

  Future<void> resetToDefaults() async {
    connectionType = ProtocolType.modbusTcp;
    timeout = 1000;
    reconnectDelay = 3000;
    readFailureAttempts = 3;
    defaultUnitId = 1;
    defaultReadQty = 20;
    _setAddressBaseValue(addressBases.first);
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
    scanConnectTimeout = 300;
    scanConcurrency = 32;
    scanClearOnStart = true;
    await _saveEditableValues();
    await _setThemeMode(ThemeMode.system);
    await _setLocale(null);
  }

  /// Serializes every persisted setting into a JSON-friendly map for backup.
  Map<String, dynamic> toJson() => {
    _connectionTypeKey: connectionType.name,
    _timeoutKey: timeout,
    _reconnectDelayKey: reconnectDelay,
    _readFailureAttemptsKey: readFailureAttempts,
    _defaultUnitIdKey: defaultUnitId,
    _defaultReadQtyKey: defaultReadQty,
    _addressBaseKey: addressBase,
    _registerOrderKey: registerOrder,
    _byteOrderKey: byteOrder,
    _writeEnabledKey: writeEnabled,
    _confirmBeforeWriteKey: confirmBeforeWrite,
    _showLastValuesKey: showLastValues,
    _showTypeBadgesKey: showTypeBadges,
    _saveLogToFileKey: saveLogToFile,
    _clearLogOnDisconnectKey: clearLogOnDisconnect,
    _maxLogEntriesKey: maxLogEntries,
    _scanProtocolKey: scanProtocol.name,
    _scanSubnetPrefixKey: scanSubnetPrefix,
    _scanPortStartKey: scanPortStart,
    _scanPortEndKey: scanPortEnd,
    _scanUnitIdStartKey: scanUnitIdStart,
    _scanUnitIdEndKey: scanUnitIdEnd,
    _scanRequestTypeKey: scanRequestType.name,
    _scanRequestAddressKey: scanRequestAddress,
    _scanConnectTimeoutKey: scanConnectTimeout,
    _scanConcurrencyKey: scanConcurrency,
    _scanClearOnStartKey: scanClearOnStart,
    _themeModeKey: themeMode.name,
    _localeKey: locale?.languageCode ?? 'system',
  };

  /// Restores settings from a backup map produced by [toJson]. Unknown or
  /// missing entries keep the current value; numeric values are clamped and
  /// scan ranges normalized exactly as during [load].
  Future<void> applyJson(Map<String, dynamic> json) async {
    T? read<T>(String key) {
      final value = json[key];
      return value is T ? value : null;
    }

    connectionType = _protocolFromValue(read<String>(_connectionTypeKey));
    timeout = _clampInt(read<int>(_timeoutKey) ?? timeout, 100, 60000);
    reconnectDelay = _clampInt(
      read<int>(_reconnectDelayKey) ?? reconnectDelay,
      500,
      60000,
    );
    readFailureAttempts =
        read<int>(_readFailureAttemptsKey) ?? readFailureAttempts;
    defaultUnitId = _clampInt(
      read<int>(_defaultUnitIdKey) ?? defaultUnitId,
      1,
      247,
    );
    defaultReadQty = _clampInt(
      read<int>(_defaultReadQtyKey) ?? defaultReadQty,
      1,
      125,
    );
    _setAddressBaseValue(read<String>(_addressBaseKey) ?? addressBase);
    registerOrder = read<String>(_registerOrderKey) ?? registerOrder;
    byteOrder = read<String>(_byteOrderKey) ?? byteOrder;
    writeEnabled = read<bool>(_writeEnabledKey) ?? writeEnabled;
    confirmBeforeWrite =
        read<bool>(_confirmBeforeWriteKey) ?? confirmBeforeWrite;
    showLastValues = read<bool>(_showLastValuesKey) ?? showLastValues;
    showTypeBadges = read<bool>(_showTypeBadgesKey) ?? showTypeBadges;
    saveLogToFile = read<bool>(_saveLogToFileKey) ?? saveLogToFile;
    clearLogOnDisconnect =
        read<bool>(_clearLogOnDisconnectKey) ?? clearLogOnDisconnect;
    maxLogEntries = _clampInt(
      read<int>(_maxLogEntriesKey) ?? maxLogEntries,
      50,
      100000,
    );
    scanProtocol = _protocolFromValue(read<String>(_scanProtocolKey));
    scanSubnetPrefix = _clampInt(
      read<int>(_scanSubnetPrefixKey) ?? scanSubnetPrefix,
      16,
      30,
    );
    scanPortStart = _clampInt(
      read<int>(_scanPortStartKey) ?? scanPortStart,
      1,
      65535,
    );
    scanPortEnd = _clampInt(
      read<int>(_scanPortEndKey) ?? scanPortEnd,
      1,
      65535,
    );
    scanUnitIdStart = _clampInt(
      read<int>(_scanUnitIdStartKey) ?? scanUnitIdStart,
      1,
      247,
    );
    scanUnitIdEnd = _clampInt(
      read<int>(_scanUnitIdEndKey) ?? scanUnitIdEnd,
      1,
      247,
    );
    _normalizeScanRanges();
    scanRequestType = ModbusScanRequestTypeX.fromName(
      read<String>(_scanRequestTypeKey),
    );
    scanRequestAddress = _clampInt(
      read<int>(_scanRequestAddressKey) ?? scanRequestAddress,
      0,
      0xffff,
    );
    scanConnectTimeout = _clampInt(
      read<int>(_scanConnectTimeoutKey) ?? scanConnectTimeout,
      50,
      10000,
    );
    scanConcurrency = _clampInt(
      read<int>(_scanConcurrencyKey) ?? scanConcurrency,
      1,
      256,
    );
    scanClearOnStart = read<bool>(_scanClearOnStartKey) ?? scanClearOnStart;
    await _saveEditableValues();
    await _setThemeMode(_themeModeFromValue(read<String>(_themeModeKey)));
    await _setLocale(_localeFromValue(read<String>(_localeKey)));
  }

  void _setAddressBaseValue(String? value) {
    addressBase = addressBases.contains(value) ? value! : addressBases.first;
    addressBaseNotifier.value = addressBase;
  }

  Future<void> _saveEditableValues() async {
    await _store.setString(_connectionTypeKey, connectionType.name);
    await _store.setInt(_timeoutKey, timeout);
    await _store.setInt(_reconnectDelayKey, reconnectDelay);
    await _store.setInt(_readFailureAttemptsKey, readFailureAttempts);
    await _store.setInt(_defaultUnitIdKey, defaultUnitId);
    await _store.setInt(_defaultReadQtyKey, defaultReadQty);
    await _store.setString(_addressBaseKey, addressBase);
    await _store.setString(_registerOrderKey, registerOrder);
    await _store.setString(_byteOrderKey, byteOrder);
    await _store.setBool(_writeEnabledKey, writeEnabled);
    await _store.setBool(_confirmBeforeWriteKey, confirmBeforeWrite);
    await _store.setBool(_showLastValuesKey, showLastValues);
    await _store.setBool(_showTypeBadgesKey, showTypeBadges);
    await _store.setBool(_saveLogToFileKey, saveLogToFile);
    await _store.setBool(_clearLogOnDisconnectKey, clearLogOnDisconnect);
    await _store.setInt(_maxLogEntriesKey, maxLogEntries);
    await _store.setString(_scanProtocolKey, scanProtocol.name);
    await _store.setInt(_scanSubnetPrefixKey, scanSubnetPrefix);
    await _store.setInt(_scanPortStartKey, scanPortStart);
    await _store.setInt(_scanPortEndKey, scanPortEnd);
    await _store.setInt(_scanUnitIdStartKey, scanUnitIdStart);
    await _store.setInt(_scanUnitIdEndKey, scanUnitIdEnd);
    await _store.setString(_scanRequestTypeKey, scanRequestType.name);
    await _store.setInt(_scanRequestAddressKey, scanRequestAddress);
    await _store.setInt(_scanConnectTimeoutKey, scanConnectTimeout);
    await _store.setInt(_scanConcurrencyKey, scanConcurrency);
    await _store.setBool(_scanClearOnStartKey, scanClearOnStart);
  }

  Future<void> _setThemeMode(ThemeMode value) async {
    themeModeNotifier.value = value;
    await _store.setString(_themeModeKey, value.name);
  }

  Future<void> _setLocale(Locale? value) async {
    localeNotifier.value = value;
    await _store.setString(_localeKey, value?.languageCode ?? 'system');
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
