import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/devices/devices_controller.dart';
import 'package:omodscan_mobile/features/devices/devices_screen.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/models/discovered_device.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:omodscan_mobile/services/discovered_device_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DeviceRepository.instance.replaceAll(const []);
  });

  testWidgets('scan card shows live scan details and stops on tap', (
    tester,
  ) async {
    final scanner = _ScanPort(
      ScannerStateView.scanning,
      discovered: const [
        DiscoveredDevice(
          host: '192.168.88.104',
          port: 502,
          unitId: 1,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.88.105',
          port: 502,
          unitId: 2,
          protocol: ProtocolType.modbusTcp,
        ),
      ],
    );
    final runtime = PollingConnectionRuntime();
    final controller = DevicesController(
      DeviceRepository.instance,
      runtime,
      scanner,
    );
    String? openedDeviceId;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(
          controller: controller,
          onOpenDevice: (id) => openedDeviceId = id,
        ),
      ),
    );

    expect(find.text('Network scan'), findsOneWidget);
    expect(find.text('Scanning...'), findsOneWidget);
    expect(find.text('Scanning network'), findsNothing);
    expect(find.text('Searching for Modbus TCP devices'), findsOneWidget);
    expect(find.text('Modbus TCP'), findsNothing);
    expect(find.text('192.168.88.0/24'), findsOneWidget);
    expect(find.text('48%'), findsOneWidget);
    expect(find.textContaining('Elapsed:'), findsOneWidget);
    expect(find.text('Found: 2'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
    expect(find.text('192.168.88.104:502'), findsOneWidget);
    expect(find.text('192.168.88.105:502'), findsOneWidget);
    expect(find.text('Modbus TCP • ID: 1'), findsOneWidget);
    expect(find.text('Modbus TCP • ID: 2'), findsOneWidget);
    expect(find.text('Connect'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Connect').first);
    await tester.pumpAndSettle();

    final device = controller.devices.single;
    expect(scanner.stopCalled, isTrue);
    expect(runtime.isConnected(device), isTrue);
    expect(openedDeviceId, device.id);

    await tester.tap(find.text('Stop scanning'));
    await tester.pump();

    expect(scanner.stopCalled, isTrue);
  });

  testWidgets('empty scan panel starts scanning', (tester) async {
    final scanner = _ScanPort(ScannerStateView.idle);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      scanner,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    expect(find.text('No scans yet'), findsOneWidget);
    await tester.tap(find.text('Start scanning'));
    await tester.pump();

    expect(scanner.startCalled, isTrue);
  });

  testWidgets('completed scan panel shows completion details', (tester) async {
    final scanner = _ScanPort(
      ScannerStateView.done,
      discovered: const [
        DiscoveredDevice(
          host: '192.168.88.104',
          port: 502,
          unitId: 1,
          protocol: ProtocolType.modbusTcp,
        ),
      ],
    );
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      scanner,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    expect(find.text('Network scan'), findsOneWidget);
    expect(find.text('Scan completed'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.textContaining('Duration:'), findsOneWidget);
    expect(find.text('Found: 1'), findsOneWidget);
    expect(find.text('Scan network'), findsOneWidget);

    await tester.tap(find.text('Scan network'));
    await tester.pump();

    expect(scanner.startCalled, isTrue);
  });

  testWidgets('connect discovered device saves and connects immediately', (
    tester,
  ) async {
    final scanner = _ScanPort(
      ScannerStateView.done,
      discovered: const [
        DiscoveredDevice(
          host: '192.168.88.104',
          port: 502,
          unitId: 1,
          protocol: ProtocolType.modbusTcp,
        ),
      ],
    );
    final runtime = PollingConnectionRuntime();
    final controller = DevicesController(
      DeviceRepository.instance,
      runtime,
      scanner,
    );
    String? openedDeviceId;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(
          controller: controller,
          onOpenDevice: (id) => openedDeviceId = id,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Connect'));
    await tester.pumpAndSettle();

    final device = controller.devices.single;
    expect(device.name, 'Device #1');
    expect(device.host, '192.168.88.104');
    expect(device.port, 502);
    expect(device.protocol, ProtocolType.modbusTcp);
    expect(device.unitId, 1);
    expect(runtime.isConnected(device), isTrue);
    expect(openedDeviceId, device.id);
    expect(scanner.discoveredDevices.isEmpty, isTrue);
    expect(find.text('Device #1'), findsOneWidget);
    expect(find.text('Connect to Device'), findsNothing);
  });

  testWidgets('clearing discovered devices resets scan panel', (tester) async {
    final scanner = _ScanPort(
      ScannerStateView.done,
      discovered: const [
        DiscoveredDevice(
          host: '192.168.88.104',
          port: 502,
          unitId: 1,
          protocol: ProtocolType.modbusTcp,
        ),
      ],
    );
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      scanner,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(scanner.clearCalled, isTrue);
    expect(find.text('No scans yet'), findsOneWidget);
    expect(find.text('Start scanning'), findsOneWidget);
  });
}

class _ScanPort extends ChangeNotifier implements DeviceScannerPort {
  ScannerStateView _state;

  _ScanPort(this._state, {List<DiscoveredDevice> discovered = const []}) {
    discoveredDevices.addListener(notifyListeners);
    for (final device in discovered) {
      discoveredDevices.add(device);
    }
  }

  @override
  final discoveredDevices = DiscoveredDeviceList();

  var stopCalled = false;
  var startCalled = false;
  var clearCalled = false;

  @override
  ScannerStateView get state => _state;

  @override
  int get scannedCount => 48;

  @override
  int get totalCount => 100;

  @override
  double get progress => 0.48;

  @override
  String? get scanCidr => '192.168.88.0/24';

  @override
  DateTime? get scanStartedAt => DateTime(2026, 5, 24, 23, 8, 12);

  @override
  ProtocolType? get scanProtocol => ProtocolType.modbusTcp;

  @override
  Future<void> startScan(DeviceScanRequest request) async {
    startCalled = true;
    notifyListeners();
  }

  @override
  void stopScan() {
    stopCalled = true;
    notifyListeners();
  }

  @override
  void clearResults() {
    clearCalled = true;
    _state = ScannerStateView.idle;
    discoveredDevices.clear();
    notifyListeners();
  }
}
