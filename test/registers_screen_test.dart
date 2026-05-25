import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/devices/device_screen.dart';
import 'package:omodscan_mobile/features/registers/register_detail_screen.dart';
import 'package:omodscan_mobile/features/registers/registers_controller.dart';
import 'package:omodscan_mobile/features/registers/registers_screen.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.resetToDefaults();
    await DeviceRepository.instance.replaceAll(List.of(demoDevices));
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

    final connections = PollingConnectionRuntime();
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

    final connections = PollingConnectionRuntime();
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
      PollingConnectionRuntime(),
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
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Pressure setpoint',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save'),
      ),
    );
    await tester.pumpAndSettle();

    expect(savedType, 'UInt32');
    expect(savedComment, 'Pressure setpoint');

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    returnDeviceId.dispose();
  });

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
          coilStartAddress: 0,
          coilCount: 1,
          coilAutoRefresh: false,
          statusEntries: [
            StatusConfig(
              statusType: '0xxxx',
              address: 0,
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
