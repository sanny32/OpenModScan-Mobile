import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/modbus_scan.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await settings.setSavedDevicesSortMode(DeviceSortMode.created);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('addressBase'), '1-based');
    expect(prefs.getString('byteOrder'), 'Swapped');
    expect(prefs.getInt('readFailureAttempts'), 5);
    expect(prefs.getBool('saveLogToFile'), isTrue);
    expect(prefs.getBool('showTypeBadges'), isTrue);
    expect(prefs.getString('savedDevicesSortMode'), 'created');

    await settings.setSavedDevicesSortMode(DeviceSortMode.lastConnected);
    await settings.load();
    expect(settings.savedDevicesSortMode, DeviceSortMode.lastConnected);
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
  });
}
