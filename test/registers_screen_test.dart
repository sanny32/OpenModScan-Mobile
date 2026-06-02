import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/devices/device_screen.dart';
import 'package:omodscan_mobile/features/registers/register_detail_screen.dart';
import 'package:omodscan_mobile/features/registers/registers_controller.dart';
import 'package:omodscan_mobile/features/registers/registers_screen.dart';
import 'package:omodscan_mobile/features/registers/widgets/register_row.dart';
import 'package:omodscan_mobile/features/registers/widgets/status_row.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/main.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/register_list.dart';
import 'package:omodscan_mobile/models/register_entry.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_fixtures.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_runtime.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:omodscan_mobile/theme/app_theme.dart';
import 'package:omodscan_mobile/widgets/app_test_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.resetToDefaults();
    await DeviceRepository.instance.replaceAll(List.of(demoDevices));
  });

  testWidgets('Registers header icon toggles selected device connection', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'menu-toggle-device',
      name: 'Menu Toggle PLC',
      host: '127.0.0.55',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'menu-toggle-list', name: 'List 1')],
    );
    await DeviceRepository.instance.replaceAll([device]);
    final connections = PollingConnectionRuntime();
    final controller = RegistersController(
      DeviceRepository.instance,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
    );
    final returnDeviceId = ValueNotifier<String?>(null);
    addTearDown(controller.dispose);
    addTearDown(returnDeviceId.dispose);

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
    await tester.pump();

    expect(connections.isConnected(device), isFalse);

    await tester.tap(find.byTooltip('Connect'));
    await tester.pumpAndSettle();

    expect(connections.isConnected(device), isTrue);

    await tester.tap(find.byTooltip('Disconnect'));
    await tester.pumpAndSettle();

    expect(connections.isConnected(device), isFalse);
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

    expect(find.text('3xxxx'), findsWidgets);
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

  testWidgets('Register map auto refresh keeps polling regardless of tab', (
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

    final connections = PollingConnectionRuntime();
    await connections.connect(device);
    final controller = RegistersController(
      DeviceRepository.instance,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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
    await tester.pump();

    expect(connections.holdingReadCount, 1);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(connections.holdingReadCount, greaterThan(1));

    // Polling keeps running over time — there is no screen-visibility gate.
    final beforeWait = connections.holdingReadCount;
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(connections.holdingReadCount, greaterThan(beforeWait));

    // Switching to the Status sub-tab still stops register polling.
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

    final connections = PollingConnectionRuntime();
    await connections.connect(device);
    final controller = RegistersController(
      DeviceRepository.instance,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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
      PollingConnectionRuntime(),
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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

    String? savedType;
    String? savedComment;
    const testEntry = RegisterEntry(
      address: 40001,
      value: '1',
      typeName: 'UInt16',
      rawWords: {40001: 1, 40002: 2},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegisterDetailScreen(
          entry: testEntry,
          canWrite: false,
          onSaved: (type, comment) {
            savedType = type;
            savedComment = comment;
          },
        ),
      ),
    );
    await tester.pump();

    // Select UInt32 via the interpretations list row.
    await tester.tap(find.text('UInt32 (32 bit)'));
    await tester.pumpAndSettle();

    expect(savedType, 'UInt32');

    // Open comment editor by tapping the comment card.
    await tester.tap(find.text('Add a comment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(AppTestKeys.registerCommentField),
      'Pressure setpoint',
    );
    await tester.tap(find.byKey(AppTestKeys.registerCommentSaveButton));
    await tester.pumpAndSettle();

    expect(savedType, 'UInt32');
    expect(savedComment, 'Pressure setpoint');

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

  testWidgets(
    'Register detail returns to register table after type selection',
    (WidgetTester tester) async {
      final device = DeviceInfo(
        id: 'type-return-device',
        name: 'Type Return PLC',
        host: '127.0.0.23',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        registerLists: [
          RegisterList(
            id: 'type-return-list',
            name: 'Type Return List',
            count: 1,
            autoRefresh: false,
          ),
        ],
      );
      await DeviceRepository.instance.replaceAll([device]);

      final controller = RegistersController(
        DeviceRepository.instance,
        PollingConnectionRuntime(),
        const DemoRegisterRuntime(enabled: false),
        AppSettings.instance,
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
      await tester.pump();

      await tester.tap(find.text('40000'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterDetailScreen), findsOneWidget);

      await tester.tap(find.text('UInt32 (32 bit)'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterDetailScreen), findsNothing);
      expect(find.byType(RegistersScreen), findsOneWidget);
      expect(
        DeviceRepository.instance
            .findById('type-return-device')!
            .registerLists
            .single
            .entries
            .single
            .typeName,
        'UInt32',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      returnDeviceId.dispose();
    },
  );

  testWidgets('Registers tab shows SegmentedButton with 4xxxx and 3xxxx', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'seg-device',
      name: 'Seg PLC',
      host: '127.0.0.30',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'seg-list', name: 'List 1')],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final controller = RegistersController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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
    await tester.pump();

    expect(find.text('4xxxx'), findsOneWidget);
    expect(find.text('3xxxx'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

  testWidgets('Disconnected register values use unavailable color', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'disconnected-values-device',
      name: 'Disconnected PLC',
      host: '127.0.0.32',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [
        RegisterList(id: 'disconnected-values-list', name: 'List 1', count: 1),
      ],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final controller = RegistersController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == '0' &&
            widget.style?.color == AppColors.light.unavailableValueColor,
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

  testWidgets('Modbus exception register values use exception color', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'exception-values-device',
      name: 'Exception PLC',
      host: '127.0.0.33',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [
        RegisterList(id: 'exception-values-list', name: 'List 1', count: 1),
      ],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final connections = ThrowingRegisterConnectionRuntime();
    await connections.connect(device);
    final controller = RegistersController(
      DeviceRepository.instance,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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
    await tester.pump();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Illegal Data Address' &&
            widget.style?.color == AppColors.light.exceptionValueColor,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == '0' &&
            widget.style?.color == AppColors.light.exceptionValueColor,
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

  testWidgets('Register error value color survives tab switches', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'persistent-error-color-device',
      name: 'Persistent Error PLC',
      host: '127.0.0.34',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [
        RegisterList(
          id: 'persistent-error-color-list',
          name: 'List 1',
          count: 1,
        ),
      ],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final connections = ThrowingRegisterConnectionRuntime();
    await connections.connect(device);
    final controller = RegistersController(
      DeviceRepository.instance,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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
    await tester.pump();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Registers'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == '0' &&
            widget.style?.color == AppColors.light.exceptionValueColor,
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

  testWidgets('Non-Modbus register errors apply to status values', (
    WidgetTester tester,
  ) async {
    final connections = ThrowingRegisterConnectionRuntime(
      error: TimeoutException('Request timed out'),
    );
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.text('Read').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();

    final statusSwitch = tester.widget<Switch>(find.byType(Switch).last);
    expect(statusSwitch.onChanged, isNull);
    expect(
      statusSwitch.thumbColor?.resolve({}),
      AppColors.light.exceptionValueColor,
    );
    expect(find.text('Request timed out'), findsWidgets);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Status tab shows SegmentedButton with 0xxxx and 1xxxx', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'coil-seg-device',
      name: 'Coil PLC',
      host: '127.0.0.31',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'coil-list', name: 'List 1')],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final controller = RegistersController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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
    await tester.pump();
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();

    expect(find.text('0xxxx'), findsOneWidget);
    expect(find.text('1xxxx'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

  testWidgets('Status tab shows one-based display coil address', (
    WidgetTester tester,
  ) async {
    await AppSettings.instance.setAddressBase('1-based');
    final connections = PollingConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(StatusRow), matching: find.text('00001')),
      findsOneWidget,
    );

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Status tab allows zero-based display coil address', (
    WidgetTester tester,
  ) async {
    final connections = PollingConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == '0',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(StatusRow), matching: find.text('00000')),
      findsOneWidget,
    );

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Single tap register value opens write dialog and writes', (
    WidgetTester tester,
  ) async {
    final connections = PollingConnectionRuntime();
    final harness = await _pumpWritableRegistersHarness(tester, connections);

    final valueFinder = find
        .descendant(
          of: find.byType(RegisterRow).first,
          matching: find.text('0'),
        )
        .last;
    await tester.tap(valueFinder);
    await tester.pumpAndSettle();

    expect(find.text('Write Register'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '77');
    await tester.tap(find.widgetWithText(TextButton, 'Write'));
    await tester.pumpAndSettle();

    expect(connections.lastWriteHoldingAddress, 0);
    expect(connections.lastWriteHoldingValue, 77);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Coil switch writes immediately by default', (
    WidgetTester tester,
  ) async {
    final connections = PollingConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(connections.lastWriteCoilAddress, 0);
    expect(connections.lastWriteCoilValue, isTrue);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets(
    'Failed coil switch write shows error without unhandled exception',
    (WidgetTester tester) async {
      final connections = ThrowingStatusWriteConnectionRuntime();
      final harness = await _pumpStatusHarness(tester, connections);

      await tester.tap(find.widgetWithText(Tab, 'Status'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(connections.lastWriteCoilAddress, 0);
      expect(find.textContaining('Coil write failed'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeRegistersHarness(tester, harness);
    },
  );

  testWidgets('Failed detail coil write keeps previous value', (
    WidgetTester tester,
  ) async {
    final connections = ThrowingStatusWriteConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(StatusRow), matching: find.text('00000')),
    );
    await tester.pumpAndSettle();

    expect(find.text('OFF'), findsOneWidget);

    await tester.tap(find.text('Set ON'));
    await tester.pumpAndSettle();

    expect(connections.lastWriteCoilAddress, 0);
    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('ON'), findsNothing);
    expect(find.textContaining('Coil write failed'), findsOneWidget);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Coil confirmation writes only after approval', (
    WidgetTester tester,
  ) async {
    await AppSettings.instance.setConfirmBeforeWrite(true);
    final connections = PollingConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(find.text('Write Coil'), findsOneWidget);
    expect(connections.lastWriteCoilAddress, isNull);

    await tester.tap(find.widgetWithText(TextButton, 'Write'));
    await tester.pumpAndSettle();

    expect(connections.lastWriteCoilAddress, 0);
    expect(connections.lastWriteCoilValue, isTrue);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Write disabled setting disables status switch writes', (
    WidgetTester tester,
  ) async {
    await AppSettings.instance.setWriteEnabled(false);
    final connections = PollingConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch).last).onChanged, isNull);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Status error values use exception switch color', (
    WidgetTester tester,
  ) async {
    final connections = ThrowingStatusConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read').hitTestable());
    await tester.pumpAndSettle();

    final statusSwitch = tester.widget<Switch>(find.byType(Switch).last);
    expect(statusSwitch.onChanged, isNull);
    expect(
      statusSwitch.thumbColor?.resolve({}),
      AppColors.light.exceptionValueColor,
    );
    expect(
      statusSwitch.trackColor?.resolve({}),
      AppColors.light.exceptionValueColor.withAlpha(77),
    );

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Status error switch color survives tab switches', (
    WidgetTester tester,
  ) async {
    final connections = ThrowingStatusConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Registers'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();

    final statusSwitch = tester.widget<Switch>(find.byType(Switch).last);
    expect(
      statusSwitch.thumbColor?.resolve({}),
      AppColors.light.exceptionValueColor,
    );

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Status error disables writable switches', (
    WidgetTester tester,
  ) async {
    final connections = ThrowingStatusConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read').hitTestable());
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch).last).onChanged, isNull);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Successful status read clears error switch state', (
    WidgetTester tester,
  ) async {
    final connections = FlakyStatusConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read').hitTestable());
    await tester.pumpAndSettle();

    var statusSwitch = tester.widget<Switch>(find.byType(Switch).last);
    expect(statusSwitch.onChanged, isNull);
    expect(
      statusSwitch.thumbColor?.resolve({}),
      AppColors.light.exceptionValueColor,
    );

    connections.failReads = false;
    await tester.tap(find.text('Read').hitTestable());
    await tester.pumpAndSettle();

    statusSwitch = tester.widget<Switch>(find.byType(Switch).last);
    expect(statusSwitch.onChanged, isNotNull);
    expect(statusSwitch.thumbColor, isNull);
    expect(statusSwitch.trackColor, isNull);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Non-Modbus status errors apply to register values', (
    WidgetTester tester,
  ) async {
    final connections = ThrowingStatusConnectionRuntime(
      error: TimeoutException('Request timed out'),
    );
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Registers'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == '0' &&
            widget.style?.color == AppColors.light.exceptionValueColor,
      ),
      findsWidgets,
    );
    expect(find.text('Request timed out'), findsWidgets);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Status Modbus exception does not affect register values', (
    WidgetTester tester,
  ) async {
    final connections = ThrowingStatusConnectionRuntime();
    final harness = await _pumpStatusHarness(tester, connections);

    await tester.tap(find.widgetWithText(Tab, 'Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Registers'));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == '0' &&
            widget.style?.color == AppColors.light.exceptionValueColor,
      ),
      findsNothing,
    );

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Shared list dropdown switches between tabs and lists', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'multi-list-device',
      name: 'Multi PLC',
      host: '127.0.0.32',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [
        RegisterList(id: 'list-a', name: 'Alpha'),
        RegisterList(id: 'list-b', name: 'Beta'),
      ],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final controller = RegistersController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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
    await tester.pump();

    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsWidgets);

    await tester.tap(find.text('Beta').last);
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('Registers'));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

  testWidgets('List dropdown always shows New List option', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'single-list-device',
      name: 'Single PLC',
      host: '127.0.0.33',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'only-list', name: 'Only List')],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final controller = RegistersController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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
    await tester.pump();

    await tester.tap(find.text('Only List'));
    await tester.pumpAndSettle();
    expect(find.text('New List'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

  testWidgets(
    'Register row shows address, type below address, comment, value',
    (WidgetTester tester) async {
      final device = DeviceInfo(
        id: 'row-layout-device',
        name: 'Row PLC',
        host: '127.0.0.34',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        registerLists: [
          RegisterList(
            id: 'row-list',
            name: 'Row List',
            startAddress: 1,
            count: 1,
            autoRefresh: false,
            entries: [
              RegisterConfig(
                address: 40001,
                typeName: 'UInt32',
                comment: 'Speed setpoint',
              ),
            ],
          ),
        ],
      );
      await DeviceRepository.instance.replaceAll([device]);

      final controller = RegistersController(
        DeviceRepository.instance,
        PollingConnectionRuntime(),
        const DemoRegisterRuntime(enabled: false),
        AppSettings.instance,
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
      await tester.pump();

      expect(find.text('40001'), findsOneWidget);
      expect(find.text('UInt32'), findsOneWidget);
      expect(find.text('Speed setpoint'), findsOneWidget);

      final addressOffset = tester.getTopLeft(find.text('40001'));
      final typeOffset = tester.getTopLeft(find.text('UInt32'));
      final commentOffset = tester.getTopLeft(find.text('Speed setpoint'));

      expect(typeOffset.dy, greaterThan(addressOffset.dy));
      expect(typeOffset.dx, closeTo(addressOffset.dx, 4));
      expect(commentOffset.dx, greaterThanOrEqualTo(addressOffset.dx + 72));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      returnDeviceId.dispose();
    },
  );

  testWidgets('Registers tab keeps start field unpadded in zero-based mode', (
    WidgetTester tester,
  ) async {
    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'zero-start-list',
        name: 'Zero Start List',
        startAddress: 0,
        count: 1,
        autoRefresh: false,
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == '0',
      ),
      findsOneWidget,
    );
    expect(find.text('40000'), findsOneWidget);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Registers tab ignores configs from another register type', (
    WidgetTester tester,
  ) async {
    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'mixed-type-config-list',
        name: 'Mixed Type Config List',
        startAddress: 0,
        count: 1,
        autoRefresh: false,
        entries: [
          RegisterConfig(address: 30000, comment: 'Input comment'),
          RegisterConfig(address: 40000, comment: 'Holding comment'),
        ],
      ),
    );

    expect(find.text('40000'), findsOneWidget);
    expect(find.text('Holding comment'), findsOneWidget);
    expect(find.text('Input comment'), findsNothing);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Registers tab rebases visible addresses in one-based mode', (
    WidgetTester tester,
  ) async {
    await AppSettings.instance.setAddressBase('1-based');

    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'one-based-start-list',
        name: 'One Based Start List',
        startAddress: 0,
        count: 2,
        autoRefresh: false,
        entries: [
          RegisterConfig(address: 40001, comment: 'Offset one comment'),
        ],
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == '1',
      ),
      findsOneWidget,
    );
    expect(find.text('40001'), findsOneWidget);
    expect(find.text('40002'), findsOneWidget);
    expect(find.text('Offset one comment'), findsOneWidget);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Register list groups UInt32 tail register by default', (
    WidgetTester tester,
  ) async {
    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'group-list',
        name: 'Group List',
        startAddress: 1,
        count: 3,
        autoRefresh: false,
        entries: [RegisterConfig(address: 40001, typeName: 'UInt32')],
      ),
    );

    expect(find.text('40001'), findsOneWidget);
    expect(find.text('40002'), findsNothing);
    expect(find.text('40003'), findsOneWidget);
    expect(find.text('2 regs'), findsOneWidget);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Register group expands and collapses raw UInt16 words', (
    WidgetTester tester,
  ) async {
    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'expand-list',
        name: 'Expand List',
        startAddress: 1,
        count: 2,
        autoRefresh: false,
        entries: [RegisterConfig(address: 40001, typeName: 'UInt32')],
      ),
    );

    expect(find.text('40002'), findsNothing);
    expect(find.text('Raw UInt16'), findsNothing);

    await tester.tap(find.byTooltip('Show raw words for 40001'));
    await tester.pumpAndSettle();
    expect(find.text('40002'), findsOneWidget);
    expect(find.text('Raw UInt16'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Hide raw words for 40001'));
    await tester.pumpAndSettle();
    expect(find.text('40002'), findsNothing);
    expect(find.text('Raw UInt16'), findsNothing);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Register list keeps explicitly configured tail visible', (
    WidgetTester tester,
  ) async {
    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'conflict-list',
        name: 'Conflict List',
        startAddress: 1,
        count: 3,
        autoRefresh: false,
        entries: [
          RegisterConfig(address: 40001, typeName: 'UInt32'),
          RegisterConfig(address: 40002, comment: 'Tail comment'),
        ],
      ),
    );

    expect(find.text('40001'), findsOneWidget);
    expect(find.text('40002'), findsOneWidget);
    expect(find.text('Tail comment'), findsOneWidget);
    expect(find.text('2 regs'), findsNothing);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Register list ignores empty UInt16 tail config when grouping', (
    WidgetTester tester,
  ) async {
    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'default-tail-list',
        name: 'Default Tail List',
        startAddress: 1,
        count: 3,
        autoRefresh: false,
        entries: [
          RegisterConfig(address: 40001, typeName: 'UInt32'),
          RegisterConfig(address: 40002),
        ],
      ),
    );

    expect(find.text('40001'), findsOneWidget);
    expect(find.text('40002'), findsNothing);
    expect(find.text('40003'), findsOneWidget);
    expect(find.text('2 regs'), findsOneWidget);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Register list shows consecutive multi-word starts as groups', (
    WidgetTester tester,
  ) async {
    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'consecutive-groups-list',
        name: 'Consecutive Groups List',
        startAddress: 1,
        count: 4,
        autoRefresh: false,
        entries: [
          RegisterConfig(address: 40001, typeName: 'UInt32'),
          RegisterConfig(address: 40002, typeName: 'UInt32'),
        ],
      ),
    );

    expect(find.text('40001'), findsOneWidget);
    expect(find.text('40002'), findsOneWidget);
    expect(find.text('40003'), findsNothing);
    expect(find.text('40004'), findsOneWidget);
    expect(find.text('2 regs'), findsNWidgets(2));

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Register list groups Float64 across four registers', (
    WidgetTester tester,
  ) async {
    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'float64-list',
        name: 'Float64 List',
        startAddress: 1,
        count: 5,
        autoRefresh: false,
        entries: [RegisterConfig(address: 40001, typeName: 'Float64')],
      ),
    );

    expect(find.text('40001'), findsOneWidget);
    expect(find.text('40002'), findsNothing);
    expect(find.text('40003'), findsNothing);
    expect(find.text('40004'), findsNothing);
    expect(find.text('40005'), findsOneWidget);
    expect(find.text('4 regs'), findsOneWidget);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Register list does not group when span exceeds visible range', (
    WidgetTester tester,
  ) async {
    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'boundary-list',
        name: 'Boundary List',
        startAddress: 1,
        count: 1,
        autoRefresh: false,
        entries: [RegisterConfig(address: 40001, typeName: 'UInt32')],
      ),
    );

    expect(find.text('40001'), findsOneWidget);
    expect(find.text('2 regs'), findsNothing);
    expect(find.byTooltip('Show raw words for 40001'), findsNothing);

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Register list keeps setAllTypes UInt32 rows visible', (
    WidgetTester tester,
  ) async {
    final harness = await _pumpRegistersHarness(
      tester,
      RegisterList(
        id: 'set-all-ui-list',
        name: 'Set All UI List',
        startAddress: 1,
        count: 3,
        autoRefresh: false,
        entries: [
          RegisterConfig(address: 40001, typeName: 'UInt32'),
          RegisterConfig(address: 40002, typeName: 'UInt32'),
          RegisterConfig(address: 40003, typeName: 'UInt32'),
        ],
      ),
    );

    expect(find.text('40001'), findsOneWidget);
    expect(find.text('40002'), findsOneWidget);
    expect(find.text('40003'), findsOneWidget);
    expect(find.text('2 regs'), findsNWidgets(2));

    await _disposeRegistersHarness(tester, harness);
  });

  testWidgets('Status row shows comment left, switch right', (
    WidgetTester tester,
  ) async {
    final device = DeviceInfo(
      id: 'status-row-device',
      name: 'Status Row PLC',
      host: '127.0.0.35',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [
        RegisterList(
          id: 'status-row-list',
          name: 'SR List',
          coilStartAddress: 1,
          coilCount: 1,
          coilAutoRefresh: false,
          statusEntries: [
            StatusConfig(
              statusType: '0xxxx',
              address: 1,
              comment: 'Pump enable',
            ),
          ],
        ),
      ],
    );
    await DeviceRepository.instance.replaceAll([device]);

    final controller = RegistersController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
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
    await tester.pump();
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();

    expect(find.text('Pump enable'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));

    final commentOffset = tester.getCenter(find.text('Pump enable'));
    final rowSwitchOffset = tester.getCenter(find.byType(Switch).last);
    expect(rowSwitchOffset.dx, greaterThan(commentOffset.dx));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

  testWidgets('Register detail shows correct Int32 value from two words', (
    WidgetTester tester,
  ) async {
    // Default register order is MSRF: hi = rawWords[addr], lo = rawWords[addr+1]
    // combined = (1 << 16) | 34964 = 100500
    const entry = RegisterEntry(
      address: 40007,
      value: '1',
      typeName: 'Int32',
      rawWords: {40007: 1, 40008: 34964},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegisterDetailScreen(entry: entry, canWrite: false),
      ),
    );
    await tester.pump();

    expect(find.text('100500'), findsWidgets);
  });

  testWidgets(
    'Register detail interpretations use rawWords for multi-word types',
    (WidgetTester tester) async {
      // MSRF: hi = rawWords[addr]=1, lo = rawWords[addr+1]=2 → UInt32 = (1<<16)|2 = 65538
      const entry = RegisterEntry(
        address: 40001,
        value: '1',
        typeName: 'UInt32',
        rawWords: {40001: 1, 40002: 2},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RegisterDetailScreen(entry: entry, canWrite: false),
        ),
      );
      await tester.pump();

      // UInt32 row in interpretations list and header both show 65538
      expect(find.text('65538'), findsWidgets);
    },
  );

  testWidgets('Register detail shows previous value in selected type', (
    WidgetTester tester,
  ) async {
    // previousValue '258' raw uint16: UInt16 → 258, Hex → 0x0102
    await AppSettings.instance.resetToDefaults();
    AppSettings.instance.showLastValuesNotifier.value = true;
    const entry = RegisterEntry(
      address: 40001,
      value: '1',
      typeName: 'UInt16',
      previousValue: '258',
      rawWords: {40001: 1, 40002: 2},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegisterDetailScreen(entry: entry, canWrite: false),
      ),
    );
    await tester.pump();

    // UInt16: 258 → '258'
    expect(find.text('258'), findsWidgets);

    // Switch to Hex via interpretations list — scroll down to find it, tap last occurrence
    await tester.scrollUntilVisible(find.text('Hex').last, 100);
    await tester.tap(find.text('Hex').last);
    await tester.pumpAndSettle();

    expect(find.text('0x0102'), findsOneWidget);
  });
}

typedef _RegistersHarness = ({
  RegistersController controller,
  ValueNotifier<String?> returnDeviceId,
});

Future<_RegistersHarness> _pumpRegistersHarness(
  WidgetTester tester,
  RegisterList registerList,
) async {
  final device = DeviceInfo(
    id: '${registerList.id}-device',
    name: '${registerList.name} PLC',
    host: '127.0.0.40',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
    registerLists: [registerList],
  );
  await DeviceRepository.instance.replaceAll([device]);

  final controller = RegistersController(
    DeviceRepository.instance,
    PollingConnectionRuntime(),
    const DemoRegisterRuntime(enabled: false),
    AppSettings.instance,
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
  await tester.pump();

  return (controller: controller, returnDeviceId: returnDeviceId);
}

Future<_RegistersHarness> _pumpWritableRegistersHarness(
  WidgetTester tester,
  PollingConnectionRuntime connections,
) async {
  final device = DeviceInfo(
    id: 'write-register-device',
    name: 'Write Register PLC',
    host: '127.0.0.42',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
    registerLists: [
      RegisterList(
        id: 'write-register-list',
        name: 'Write Register List',
        autoRefresh: false,
        count: 1,
      ),
    ],
  );
  await DeviceRepository.instance.replaceAll([device]);
  await connections.connect(device);

  final controller = RegistersController(
    DeviceRepository.instance,
    connections,
    const DemoRegisterRuntime(enabled: false),
    AppSettings.instance,
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
  await tester.pump();

  return (controller: controller, returnDeviceId: returnDeviceId);
}

Future<_RegistersHarness> _pumpStatusHarness(
  WidgetTester tester,
  PollingConnectionRuntime connections,
) async {
  final device = DeviceInfo(
    id: 'status-error-device',
    name: 'Status Error PLC',
    host: '127.0.0.41',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
    registerLists: [
      RegisterList(
        id: 'status-error-list',
        name: 'Status Error List',
        autoRefresh: false,
        coilAutoRefresh: false,
        coilCount: 1,
      ),
    ],
  );
  await DeviceRepository.instance.replaceAll([device]);
  await connections.connect(device);

  final controller = RegistersController(
    DeviceRepository.instance,
    connections,
    const DemoRegisterRuntime(enabled: false),
    AppSettings.instance,
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
  await tester.pump();

  return (controller: controller, returnDeviceId: returnDeviceId);
}

Future<void> _disposeRegistersHarness(
  WidgetTester tester,
  _RegistersHarness harness,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  harness.controller.dispose();
  harness.returnDeviceId.dispose();
}
