import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/modbus_scan.dart';
import 'package:omodscan_mobile/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [SettingsStore] used to verify [AppSettings] persists purely
/// through the store abstraction rather than touching SharedPreferences.
class FakeSettingsStore implements SettingsStore {
  final Map<String, Object?> values = {};
  bool loaded = false;

  @override
  Future<void> load() async => loaded = true;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  int? getInt(String key) => values[key] as int?;

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('editable settings write through to preferences', () async {
    final settings = AppSettings.instance;
    await settings.resetToDefaults();

    await settings.setAddressBase('1-based');
    await settings.setByteOrder('Swapped');
    await settings.setReadFailureAttempts(5);
    await settings.setSaveLogToFile(true);
    await settings.setShowTypeBadges(true);
    await settings.setWriteEnabled(false);
    await settings.setConfirmBeforeWrite(true);
    await settings.setSavedDevicesSortMode(DeviceSortMode.created);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('addressBase'), '1-based');
    expect(prefs.getString('byteOrder'), 'Swapped');
    expect(prefs.getInt('readFailureAttempts'), 5);
    expect(prefs.getBool('saveLogToFile'), isTrue);
    expect(prefs.getBool('showTypeBadges'), isTrue);
    expect(prefs.getBool('writeEnabled'), isFalse);
    expect(prefs.getBool('confirmBeforeWrite'), isTrue);
    expect(prefs.getString('savedDevicesSortMode'), 'created');

    await settings.setSavedDevicesSortMode(DeviceSortMode.lastConnected);
    await settings.load();
    expect(settings.savedDevicesSortMode, DeviceSortMode.lastConnected);
    expect(settings.writeEnabled, isFalse);
    expect(settings.confirmBeforeWrite, isTrue);
  });

  test('network scan settings persist and reset to defaults', () async {
    final settings = AppSettings.instance;
    await settings.resetToDefaults();

    expect(settings.scanProtocol, ProtocolType.modbusTcp);
    expect(settings.scanSubnetPrefix, 24);
    expect(settings.scanPortStart, 502);
    expect(settings.scanPortEnd, 502);
    expect(settings.scanUnitIdStart, 1);
    expect(settings.scanUnitIdEnd, 10);
    expect(settings.scanRequestType, ModbusScanRequestType.holdingRegisters);
    expect(settings.scanRequestAddress, 0);
    expect(settings.savedDevicesSortMode, DeviceSortMode.lastConnected);
    expect(settings.writeEnabled, isTrue);
    expect(settings.confirmBeforeWrite, isFalse);

    await settings.setScanProtocol(ProtocolType.modbusRtuIp);
    await settings.setScanSubnetPrefix(20);
    await settings.setScanPortRange(503, 502);
    await settings.setScanUnitIdRange(12, 3);
    await settings.setScanRequestType(ModbusScanRequestType.inputRegisters);
    await settings.setScanRequestAddress(42);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('scanProtocol'), 'modbusRtuIp');
    expect(prefs.getInt('scanSubnetPrefix'), 20);
    expect(prefs.getInt('scanPortStart'), 502);
    expect(prefs.getInt('scanPortEnd'), 503);
    expect(prefs.getInt('scanUnitIdStart'), 3);
    expect(prefs.getInt('scanUnitIdEnd'), 12);
    expect(prefs.getString('scanRequestType'), 'inputRegisters');
    expect(prefs.getInt('scanRequestAddress'), 42);

    await settings.resetToDefaults();
    expect(settings.scanProtocol, ProtocolType.modbusTcp);
    expect(settings.scanPortStart, 502);
    expect(settings.scanPortEnd, 502);
    expect(settings.scanUnitIdStart, 1);
    expect(settings.scanUnitIdEnd, 10);
    expect(settings.writeEnabled, isTrue);
    expect(settings.confirmBeforeWrite, isFalse);
  });

  test('connection defaults persist and clamp out-of-range values', () async {
    final settings = AppSettings.instance;
    await settings.resetToDefaults();

    await settings.setConnectionType(ProtocolType.modbusRtuIp);
    await settings.setTimeout(50); // below min → clamped to 100
    await settings.setReconnectDelay(99999); // above max → clamped to 60000
    await settings.setDefaultUnitId(500); // above max → clamped to 247
    await settings.setDefaultReadQty(0); // below min → clamped to 1

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('connectionType'), 'modbusRtuIp');
    expect(prefs.getInt('timeout'), 100);
    expect(prefs.getInt('reconnectDelay'), 60000);
    expect(prefs.getInt('defaultUnitId'), 247);
    expect(prefs.getInt('defaultReadQty'), 1);

    await settings.load();
    expect(settings.connectionType, ProtocolType.modbusRtuIp);
    expect(settings.timeout, 100);
    expect(settings.reconnectDelay, 60000);
    expect(settings.defaultUnitId, 247);
    expect(settings.defaultReadQty, 1);

    await settings.resetToDefaults();
    expect(settings.connectionType, ProtocolType.modbusTcp);
    expect(settings.timeout, 1000);
    expect(settings.reconnectDelay, 3000);
    expect(settings.defaultUnitId, 1);
    expect(settings.defaultReadQty, 20);
  });

  test('toJson/applyJson round-trips every setting', () async {
    final source = AppSettings.withStore(FakeSettingsStore());
    await source.setConnectionType(ProtocolType.modbusRtuIp);
    await source.setTimeout(2500);
    await source.setReconnectDelay(7000);
    await source.setDefaultUnitId(9);
    await source.setDefaultReadQty(64);
    await source.setReadFailureAttempts(5);
    await source.setAddressBase('1-based');
    await source.setRegisterOrder('LSRF');
    await source.setByteOrder('Swapped');
    await source.setWriteEnabled(false);
    await source.setConfirmBeforeWrite(true);
    await source.setShowTypeBadges(true);
    await source.setScanSubnetPrefix(20);
    await source.setScanPortRange(100, 200);
    await source.setScanUnitIdRange(2, 8);
    await source.setScanRequestType(ModbusScanRequestType.coils);
    await source.setScanRequestAddress(42);
    await source.setSavedDevicesSortMode(DeviceSortMode.created);
    await source.setTheme('Dark');
    await source.setLanguage('Russian');

    final backup = source.toJson();

    final target = AppSettings.withStore(FakeSettingsStore());
    await target.applyJson(backup);

    expect(target.connectionType, ProtocolType.modbusRtuIp);
    expect(target.timeout, 2500);
    expect(target.reconnectDelay, 7000);
    expect(target.defaultUnitId, 9);
    expect(target.defaultReadQty, 64);
    expect(target.readFailureAttempts, 5);
    expect(target.addressBase, '1-based');
    expect(target.registerOrder, 'LSRF');
    expect(target.byteOrder, 'Swapped');
    expect(target.writeEnabled, isFalse);
    expect(target.confirmBeforeWrite, isTrue);
    expect(target.showTypeBadges, isTrue);
    expect(target.scanSubnetPrefix, 20);
    expect(target.scanPortStart, 100);
    expect(target.scanPortEnd, 200);
    expect(target.scanUnitIdStart, 2);
    expect(target.scanUnitIdEnd, 8);
    expect(target.scanRequestType, ModbusScanRequestType.coils);
    expect(target.scanRequestAddress, 42);
    expect(target.savedDevicesSortMode, DeviceSortMode.created);
    expect(target.themeMode, ThemeMode.dark);
    expect(target.locale?.languageCode, 'ru');
  });

  test('delegates persistence to the injected SettingsStore', () async {
    final store = FakeSettingsStore();
    final settings = AppSettings.withStore(store);

    await settings.setWriteEnabled(false);
    await settings.setScanSubnetPrefix(20);
    await settings.setByteOrder('Swapped');

    // Values land in the store, not in SharedPreferences.
    expect(store.values['writeEnabled'], isFalse);
    expect(store.values['scanSubnetPrefix'], 20);
    expect(store.values['byteOrder'], 'Swapped');

    // load() hydrates the model straight from the store.
    final reloaded = AppSettings.withStore(store);
    await reloaded.load();
    expect(store.loaded, isTrue);
    expect(reloaded.writeEnabled, isFalse);
    expect(reloaded.scanSubnetPrefix, 20);
    expect(reloaded.byteOrder, 'Swapped');
  });
}
