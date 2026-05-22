import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/devices/device_screen.dart';
import 'package:omodscan_mobile/features/registers/register_list_dialogs.dart';
import 'package:omodscan_mobile/features/registers/registers_controller.dart';
import 'package:omodscan_mobile/features/registers/registers_screen.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/main.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/register_list.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_fixtures.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_runtime.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:omodscan_mobile/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.resetToDefaults();
    await DeviceRepository.instance.replaceAll(List.of(demoDevices));
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OModScanApp());

    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('Each tab keeps its nested navigation stack', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLC #1').first);
    await tester.pumpAndSettle();
    expect(find.byType(DeviceScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.devices_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(DeviceScreen), findsOneWidget);
  });

  testWidgets('Deleted device snackbar disappears after timeout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();

    await tester.drag(find.text('PLC #1'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Device deleted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Device deleted'), findsNothing);
  });

  testWidgets('New device name is prefilled and required', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final nameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == 'Device #6',
    );
    expect(nameField, findsOneWidget);

    await tester.enterText(nameField, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('Register list dialog closes without disposed controllers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _RegisterListDialogHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Device register list opens registers with its range config', (
    WidgetTester tester,
  ) async {
    await DeviceRepository.instance.replaceAll([
      DeviceInfo(
        id: 'target-device',
        name: 'Target PLC',
        host: '127.0.0.20',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        registerLists: [
          RegisterList(
            id: 'holding-list',
            name: 'Holding List',
            regType: '4xxxx',
            startAddress: 1,
            count: 20,
          ),
          RegisterList(
            id: 'input-list',
            name: 'Input List',
            regType: '3xxxx',
            startAddress: 37,
            count: 8,
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target PLC'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Input List'), 300);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Input List'));
    await tester.pumpAndSettle();

    expect(find.text('Input (3xxxx)'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == '37',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == '8',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceScreen), findsOneWidget);
  });

  testWidgets('Register map auto refresh reads only while visible', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'auto-device',
      name: 'Auto PLC',
      host: '127.0.0.21',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [
        RegisterList(
          id: 'auto-list',
          name: 'Auto List',
          count: 1,
          refreshIntervalMs: 100,
        ),
      ],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final connections = _PollingConnectionRuntime();
    await connections.connect(device);
    final controller = RegistersController(
      DeviceRepository.instance,
      connections,
      const DemoRegisterRuntime(enabled: false),
    );
    final returnDeviceId = ValueNotifier<String?>(null);
    final screenActive = ValueNotifier(true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegistersScreen(
          controller: controller,
          returnDeviceId: returnDeviceId,
          screenActive: screenActive,
          onReturnToDevice: () {},
        ),
      ),
    );
    await tester.pump();

    expect(connections.holdingReadCount, 1);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(connections.holdingReadCount, greaterThan(1));

    screenActive.value = false;
    await tester.pump();
    final hiddenScreenReadCount = connections.holdingReadCount;

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(connections.holdingReadCount, hiddenScreenReadCount);

    screenActive.value = true;
    await tester.pump();
    await tester.pump();

    expect(connections.holdingReadCount, greaterThan(hiddenScreenReadCount));

    await tester.tap(find.text('Status'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final inactiveTabReadCount = connections.holdingReadCount;

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(connections.holdingReadCount, inactiveTabReadCount);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
    screenActive.dispose();
  });

  testWidgets('Status map auto refresh reads connected coils', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'status-device',
      name: 'Status PLC',
      host: '127.0.0.23',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [
        RegisterList(
          id: 'status-list',
          name: 'Status List',
          coilCount: 1,
          coilRefreshIntervalMs: 100,
        ),
      ],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final connections = _PollingConnectionRuntime();
    await connections.connect(device);
    final controller = RegistersController(
      DeviceRepository.instance,
      connections,
      const DemoRegisterRuntime(enabled: false),
    );
    final returnDeviceId = ValueNotifier<String?>(null);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegistersScreen(
          controller: controller,
          returnDeviceId: returnDeviceId,
          onReturnToDevice: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(connections.coilReadCount, 0);

    await tester.tap(find.text('Status'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(connections.coilReadCount, greaterThan(0));
    final firstReadCount = connections.coilReadCount;

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(connections.coilReadCount, greaterThan(firstReadCount));

    final holdingReadsBeforeReturn = connections.holdingReadCount;
    await tester.tap(find.text('Registers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final inactiveStatusReadCount = connections.coilReadCount;

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(connections.holdingReadCount, greaterThan(holdingReadsBeforeReturn));
    expect(connections.coilReadCount, inactiveStatusReadCount);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

  testWidgets('Register detail saves type and comment into the active list', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'edit-device',
      name: 'Edit PLC',
      host: '127.0.0.22',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [
        RegisterList(
          id: 'edit-list',
          name: 'Edit List',
          count: 1,
          autoRefresh: false,
        ),
      ],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final controller = RegistersController(
      DeviceRepository.instance,
      _PollingConnectionRuntime(),
      const DemoRegisterRuntime(enabled: false),
    );
    final returnDeviceId = ValueNotifier<String?>(null);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegistersScreen(
          controller: controller,
          returnDeviceId: returnDeviceId,
          onReturnToDevice: () {},
        ),
      ),
    );

    await tester.tap(find.text('40001'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UInt32 (32 bit)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Comment',
      ),
      'Pressure setpoint',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('UInt32'), findsOneWidget);
    expect(find.text('Pressure setpoint'), findsOneWidget);
    final entry = DeviceRepository.instance
        .findById(device.id)!
        .registerLists
        .single
        .entries
        .single;
    expect(entry.typeName, 'UInt32');
    expect(entry.comment, 'Pressure setpoint');

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
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
}

class _RegisterListDialogHarness extends StatelessWidget {
  const _RegisterListDialogHarness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  showRegisterListDialog(context, defaultName: 'List 1'),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );
  }
}

class _PollingConnectionRuntime implements ConnectionRuntime {
  final _ids = ValueNotifier<Set<String>>(const {});
  var holdingReadCount = 0;
  var coilReadCount = 0;

  @override
  ValueListenable<Set<String>> get connectedDeviceIds => _ids;

  @override
  Future<void> connect(DeviceInfo device) async {
    _ids.value = {..._ids.value, device.id};
  }

  @override
  Future<void> disconnect(DeviceInfo device) async {
    _ids.value = Set.of(_ids.value)..remove(device.id);
  }

  @override
  bool isConnected(DeviceInfo device) => _ids.value.contains(device.id);

  @override
  Future<List<int>> readHoldingRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    holdingReadCount++;
    return List.filled(count, holdingReadCount);
  }

  @override
  Future<List<int>> readInputRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async => List.filled(count, 0);

  @override
  Future<List<bool>> readCoils(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    coilReadCount++;
    return List.filled(count, coilReadCount.isOdd);
  }

  @override
  Future<List<bool>> readDiscreteInputs(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async => List.filled(count, false);
}
