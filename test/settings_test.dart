import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/main.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_fixtures.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.resetToDefaults();
    await DeviceRepository.instance.replaceAll(List.of(demoDevices));
  });

  testWidgets('Theme setting updates app theme', (WidgetTester tester) async {
    await tester.pumpWidget(const OModScanApp());

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.light_mode_outlined),
      300,
    );
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final prefs = await SharedPreferences.getInstance();

    expect(app.themeMode, ThemeMode.dark);
    expect(prefs.getString('themeMode'), 'dark');
  });

  testWidgets('Language setting updates app locale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byIcon(Icons.language), 300);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Russian'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final prefs = await SharedPreferences.getInstance();

    expect(app.locale, const Locale('ru'));
    expect(prefs.getString('locale'), 'ru');
    expect(find.text('Системная'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
  });

  testWidgets('Network scan protocol setting persists', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);
    await tester.tap(find.text('Scan Protocol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RTU over TCP/IP'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('scanProtocol'), 'modbusRtuIp');
    expect(find.text('RTU over TCP/IP'), findsOneWidget);
  });

  testWidgets('Choice settings update and persist from settings screen', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);

    await _selectSettingOption(tester, 'Read failure attempts', '5');
    await _selectSettingOption(
      tester,
      'Modbus request',
      'Read Input Registers',
    );
    await _selectSettingOption(tester, 'AddressBase', '1-based');
    await _selectSettingOption(tester, 'Register Order', 'LSRF');
    await _selectSettingOption(tester, 'Byte Order', 'Swapped');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('readFailureAttempts'), 5);
    expect(prefs.getString('scanRequestType'), 'inputRegisters');
    expect(prefs.getString('addressBase'), '1-based');
    expect(prefs.getString('registerOrder'), 'LSRF');
    expect(prefs.getString('byteOrder'), 'Swapped');
  });

  testWidgets('Network scan numeric settings update and persist', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);

    await _enterNumberSetting(tester, 'Current subnet mask', '20');
    await _enterRangeSetting(tester, 'Port range', start: '503', end: '505');
    await _enterRangeSetting(tester, 'Unit ID range', start: '3', end: '7');
    await _enterNumberSetting(tester, 'Request address', '42');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('scanSubnetPrefix'), 20);
    expect(prefs.getInt('scanPortStart'), 503);
    expect(prefs.getInt('scanPortEnd'), 505);
    expect(prefs.getInt('scanUnitIdStart'), 3);
    expect(prefs.getInt('scanUnitIdEnd'), 7);
    expect(prefs.getInt('scanRequestAddress'), 42);
  });

  testWidgets('Toggle settings update and persist from settings screen', (
    WidgetTester tester,
  ) async {
    await _pumpSettings(tester);

    await _toggleSetting(tester, 'Clear results on new scan');
    await _toggleSetting(tester, 'Allow writes');
    await _toggleSetting(tester, 'Confirm coil writes');
    await _toggleSetting(tester, 'Show last values after read');
    await _toggleSetting(tester, 'Show type badges');
    await _toggleSetting(tester, 'Save traffic to file');
    await _toggleSetting(tester, 'Clear traffic on disconnect');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('scanClearOnStart'), isFalse);
    expect(prefs.getBool('writeEnabled'), isFalse);
    expect(prefs.getBool('confirmBeforeWrite'), isTrue);
    expect(prefs.getBool('showLastValues'), isFalse);
    expect(prefs.getBool('showTypeBadges'), isTrue);
    expect(prefs.getBool('saveLogToFile'), isTrue);
    expect(prefs.getBool('clearLogOnDisconnect'), isTrue);
  });

  testWidgets('Reset to defaults restores editable settings from screen', (
    WidgetTester tester,
  ) async {
    await AppSettings.instance.setAddressBase('1-based');
    await AppSettings.instance.setScanSubnetPrefix(20);
    await AppSettings.instance.setWriteEnabled(false);
    await AppSettings.instance.setSaveLogToFile(true);

    await _pumpSettings(tester);
    await _tapSetting(tester, 'Reset to defaults');
    await tester.tap(find.text('Reset to defaults').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(AppSettings.instance.addressBase, '0-based');
    expect(AppSettings.instance.scanSubnetPrefix, 24);
    expect(AppSettings.instance.writeEnabled, isTrue);
    expect(AppSettings.instance.saveLogToFile, isFalse);
    expect(prefs.getString('addressBase'), '0-based');
    expect(prefs.getInt('scanSubnetPrefix'), 24);
    expect(prefs.getBool('writeEnabled'), isTrue);
    expect(prefs.getBool('saveLogToFile'), isFalse);
  });
}

Future<void> _pumpSettings(WidgetTester tester) async {
  await tester.pumpWidget(const OModScanApp());
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

Future<void> _tapSetting(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  await tester.scrollUntilVisible(
    labelFinder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(labelFinder);
  await tester.pumpAndSettle();

  final switchTile = find.widgetWithText(SwitchListTile, label);
  final tile = switchTile.evaluate().isNotEmpty
      ? switchTile
      : find.widgetWithText(ListTile, label);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _selectSettingOption(
  WidgetTester tester,
  String label,
  String option,
) async {
  await _tapSetting(tester, label);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _enterNumberSetting(
  WidgetTester tester,
  String label,
  String value,
) async {
  await _tapSetting(tester, label);
  await tester.enterText(find.byType(TextField).last, value);
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

Future<void> _enterRangeSetting(
  WidgetTester tester,
  String label, {
  required String start,
  required String end,
}) async {
  await _tapSetting(tester, label);
  await tester.enterText(find.byType(TextField).first, start);
  await tester.enterText(find.byType(TextField).last, end);
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

Future<void> _toggleSetting(WidgetTester tester, String label) async {
  await _tapSetting(tester, label);
}
