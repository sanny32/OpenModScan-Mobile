import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/devices/device_screen.dart';
import 'package:omodscan_mobile/features/devices/device_write_screen.dart';
import 'package:omodscan_mobile/features/devices/devices_controller.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/services/discovered_device_list.dart';
import 'package:omodscan_mobile/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  late DeviceInfo device;
  late FakeDeviceRepository repository;
  late PollingConnectionRuntime connections;
  late DevicesController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.resetToDefaults();
    device = DeviceInfo(
      id: 'device-1',
      name: 'PLC',
      host: '127.0.0.1',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
    );
    repository = FakeDeviceRepository([device]);
    connections = PollingConnectionRuntime();
    controller = DevicesController(
      repository,
      connections,
      _IdleScanner(),
      AppSettings.instance,
    );
    await connections.connect(device);
  });

  tearDown(() => controller.dispose());

  testWidgets('device write card opens write flow', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _host(
        DeviceScreen(
          deviceId: device.id,
          controller: controller,
          onOpenRegisters: (_) {},
          onOpenTraffic: (_) {},
          onOpenWrite: () => opened = true,
        ),
      ),
    );

    await tester.tap(find.text('Write Value'));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('write screen confirms and writes typed register value', (
    tester,
  ) async {
    _useTallScreen(tester);
    await tester.pumpWidget(
      _host(DeviceWriteScreen(deviceId: device.id, controller: controller)),
    );

    await tester.tap(find.text('UInt16'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UInt32').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '65538');
    await tester.pump();

    expect(find.textContaining('0x0001, 0x0002'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Write'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm write'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Write').last);
    await tester.pumpAndSettle();

    expect(connections.lastWriteHoldingStartAddress, 0);
    expect(connections.lastWriteHoldingValues, [1, 2]);
    expect(find.text('Write complete'), findsOneWidget);
    expect(find.text('RESULT'), findsOneWidget);
  });

  testWidgets('write screen blocks invalid typed value', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(
      _host(DeviceWriteScreen(deviceId: device.id, controller: controller)),
    );

    await tester.enterText(find.byType(TextField).at(1), '999999');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Write'),
    );
    expect(button.onPressed, isNull);
  });
}

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
