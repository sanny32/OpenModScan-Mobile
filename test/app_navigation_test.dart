import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omodscan_mobile/features/devices/device_screen.dart';
import 'package:omodscan_mobile/features/devices/devices_controller.dart';
import 'package:omodscan_mobile/features/registers/register_detail_screen.dart';
import 'package:omodscan_mobile/features/registers/registers_controller.dart';
import 'package:omodscan_mobile/features/settings/settings_controller.dart';
import 'package:omodscan_mobile/features/traffic/traffic_controller.dart';
import 'package:omodscan_mobile/features/traffic/traffic_detail_screen.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/main.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/log_entry.dart';
import 'package:omodscan_mobile/models/register_list.dart';
import 'package:omodscan_mobile/navigation/app_router.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_runtime.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_fixtures.dart';
import 'package:omodscan_mobile/services/discovered_device_list.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:omodscan_mobile/theme/app_theme.dart';
import 'package:omodscan_mobile/utils/modbus_traffic_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

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

  testWidgets('Tapping active Devices tab returns from device screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLC #1').first);
    await tester.pumpAndSettle();
    expect(find.byType(DeviceScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.devices));
    await tester.pumpAndSettle();

    expect(find.byType(DeviceScreen), findsNothing);
    expect(find.text('PLC #1'), findsOneWidget);
  });

  testWidgets('Tapping active Registers tab returns from register detail', (
    WidgetTester tester,
  ) async {
    final routerBundle = _buildRouterBundle([
      DeviceInfo(
        id: 'register-detail-device',
        name: 'Register Detail PLC',
        host: '127.0.0.10',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        registerLists: [
          RegisterList(
            id: 'register-detail-list',
            name: 'List 1',
            count: 1,
            autoRefresh: false,
          ),
        ],
      ),
    ]);
    addTearDown(routerBundle.dispose);

    await tester.pumpWidget(_routerHost(routerBundle.router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_on_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('40000'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterDetailScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_on));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterDetailScreen), findsNothing);
    expect(find.text('40000'), findsOneWidget);
  });

  testWidgets('Tapping active Traffic tab returns from traffic detail', (
    WidgetTester tester,
  ) async {
    final routerBundle = _buildRouterBundle(
      [
        DeviceInfo(
          id: 'traffic-detail-device',
          name: 'Traffic Detail PLC',
          host: '127.0.0.11',
          port: 502,
          protocol: ProtocolType.modbusTcp,
          unitId: 1,
        ),
      ],
      trafficEntries: [_readTrafficResponse()],
    );
    addTearDown(routerBundle.dispose);

    await tester.pumpWidget(_routerHost(routerBundle.router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('03 Read Holding Registers').first);
    await tester.pumpAndSettle();
    expect(find.byType(TrafficDetailScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.list_alt));
    await tester.pumpAndSettle();

    expect(find.byType(TrafficDetailScreen), findsNothing);
    expect(find.text('03 Read Holding Registers'), findsWidgets);
  });

  testWidgets('System back from another tab returns to the devices tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('PLC #1'), findsNothing);

    // Android system back should land back on the devices branch.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('PLC #1'), findsOneWidget);
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

  testWidgets('Device screen app bar uses device name without card duplicate', (
    WidgetTester tester,
  ) async {
    const longName =
        'Boiler Room Main Controller With A Very Long Descriptive Name';
    await DeviceRepository.instance.replaceAll([
      DeviceInfo(
        id: 'long-name-device',
        name: longName,
        host: '192.168.100.123',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 6,
      ),
    ]);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      _IdleScanner(),
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeviceScreen(
          deviceId: 'long-name-device',
          controller: controller,
          onOpenRegisters: (_) {},
          onOpenTraffic: (_) {},
        ),
      ),
    );

    expect(find.byType(DeviceScreen), findsOneWidget);
    expect(find.text(longName), findsOneWidget);
    expect(find.text('192.168.100.123:502'), findsOneWidget);
    expect(find.text('Modbus TCP'), findsOneWidget);
    expect(find.text('Disconnected'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.wifi &&
            widget.color == AppTheme.lightTheme.colorScheme.onSurfaceVariant &&
            widget.semanticLabel == 'Disconnected',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('OpenModScan'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
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

  testWidgets('New device form rejects duplicate name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final nameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == 'Device #6',
    );
    await tester.enterText(nameField, 'PLC #1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name already exists'), findsOneWidget);
  });

  testWidgets('Register list dialog closes without disposed controllers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RegisterListDialogHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Register list dialog rejects duplicate name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const RegisterListDialogHarness(existingNames: ['List 1']),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name already exists'), findsOneWidget);
  });

  testWidgets('Register list dialog prefills count from default read qty', (
    WidgetTester tester,
  ) async {
    await AppSettings.instance.setDefaultReadQty(33);

    await tester.pumpWidget(const RegisterListDialogHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('33'), findsOneWidget);
  });

  testWidgets('Register list dialog clears error when name is changed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const RegisterListDialogHarness(existingNames: ['List 1']),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Name already exists'), findsOneWidget);

    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'List 1',
      ),
      'List 2',
    );
    await tester.pump();

    expect(find.text('Name already exists'), findsNothing);
  });
}

Widget _routerHost(GoRouter router) => MaterialApp.router(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);

_RouterBundle _buildRouterBundle(
  List<DeviceInfo> devices, {
  List<LogEntry> trafficEntries = const [],
}) {
  final repository = FakeDeviceRepository(devices);
  final connections = PollingConnectionRuntime();
  final registersReturnDeviceId = ValueNotifier<String?>(null);
  final devicesController = DevicesController(
    repository,
    connections,
    _IdleScanner(),
    AppSettings.instance,
  );
  final registersController = RegistersController(
    repository,
    connections,
    const DemoRegisterRuntime(enabled: false),
    AppSettings.instance,
  );
  final trafficController = TrafficController(
    repository,
    connections,
    _FakeTrafficLogs(trafficEntries),
  );
  final settingsController = SettingsController(AppSettings.instance);
  final router = createAppRouter(
    devicesController: devicesController,
    registersController: registersController,
    trafficController: trafficController,
    settingsController: settingsController,
    registersReturnDeviceId: registersReturnDeviceId,
  );
  return _RouterBundle(
    router: router,
    registersReturnDeviceId: registersReturnDeviceId,
    devicesController: devicesController,
    registersController: registersController,
    trafficController: trafficController,
    settingsController: settingsController,
  );
}

LogEntry _readTrafficResponse() => buildTrafficLogEntry(
  frame: Uint8List.fromList(const [
    0x00,
    0x07,
    0x00,
    0x00,
    0x00,
    0x07,
    0x01,
    0x03,
    0x04,
    0x00,
    0x7B,
    0x00,
    0x2D,
  ]),
  direction: LogDirection.rx,
  time: DateTime(2026, 5, 30, 7, 11, 19, 868),
);

class _RouterBundle {
  final GoRouter router;
  final ValueNotifier<String?> registersReturnDeviceId;
  final DevicesController devicesController;
  final RegistersController registersController;
  final TrafficController trafficController;
  final SettingsController settingsController;

  const _RouterBundle({
    required this.router,
    required this.registersReturnDeviceId,
    required this.devicesController,
    required this.registersController,
    required this.trafficController,
    required this.settingsController,
  });

  void dispose() {
    router.dispose();
    registersReturnDeviceId.dispose();
    devicesController.dispose();
    registersController.dispose();
    trafficController.dispose();
    settingsController.dispose();
  }
}

class _FakeTrafficLogs extends ChangeNotifier implements TrafficLogSource {
  final List<LogEntry> entries;

  _FakeTrafficLogs(this.entries);

  @override
  List<LogEntry> entriesFor(String? deviceId) => entries;

  @override
  void clear(String? deviceId) {}
}

class _IdleScanner extends ChangeNotifier implements DeviceScannerPort {
  @override
  final discoveredDevices = DiscoveredDeviceList();

  @override
  ScannerStateView get state => ScannerStateView.idle;

  @override
  int get scannedCount => 0;

  @override
  int get totalCount => 0;

  @override
  double get progress => 0;

  @override
  String? get scanCidr => null;

  @override
  DateTime? get scanStartedAt => null;

  @override
  ProtocolType? get scanProtocol => null;

  @override
  Future<void> startScan(DeviceScanRequest request) async {}

  @override
  void stopScan() {}

  @override
  void clearResults() {}
}
