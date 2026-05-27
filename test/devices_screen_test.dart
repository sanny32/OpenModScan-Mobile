import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/devices/devices_controller.dart';
import 'package:omodscan_mobile/features/devices/devices_screen.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
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
    await AppSettings.instance.resetToDefaults();
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
      AppSettings.instance,
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

    expect(find.text('Discovered devices'), findsOneWidget);
    expect(find.text('Scanning...'), findsOneWidget);
    expect(find.text('Network scanner'), findsNothing);
    expect(find.text('192.168.88.104:502'), findsOneWidget);
    expect(find.text('192.168.88.105:502'), findsNothing);
    expect(find.text('+ 1 more'), findsOneWidget);

    await tester.tap(find.text('Scanning...'));
    await tester.pumpAndSettle();

    expect(find.text('Network scanner'), findsOneWidget);
    expect(find.text('Scanning network'), findsNothing);
    expect(find.text('Searching for Modbus TCP devices'), findsOneWidget);
    expect(find.text('Modbus TCP'), findsNothing);
    expect(find.text('192.168.88.0/24'), findsOneWidget);
    expect(find.text('48%'), findsOneWidget);
    expect(find.textContaining('Elapsed:'), findsOneWidget);
    expect(find.text('Found: 2'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
    expect(find.text('192.168.88.104:502'), findsWidgets);
    expect(find.text('192.168.88.105:502'), findsOneWidget);
    expect(find.text('Modbus TCP • ID: 1'), findsWidgets);
    expect(find.text('Modbus TCP • ID: 2'), findsOneWidget);
    expect(find.text('Connect'), findsAtLeastNWidgets(2));

    await tester.tap(find.text('Stop scanning'));
    await tester.pump();

    expect(scanner.stopCalled, isTrue);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Connect').last);
    await tester.pumpAndSettle();

    final device = controller.devices.single;
    expect(runtime.isConnected(device), isTrue);
    expect(openedDeviceId, device.id);
  });

  testWidgets('discovered show all opens full-screen results list only', (
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
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      scanner,
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    await tester.tap(find.text('Show all (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Discovered devices'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Network scanner'), findsNothing);
    expect(find.text('Searching for Modbus TCP devices'), findsNothing);
    expect(find.text('48%'), findsNothing);
    expect(find.text('Found: 2'), findsNothing);
    expect(find.text('Stop scanning'), findsNothing);
    expect(find.text('192.168.88.104:502'), findsWidgets);
    expect(find.text('192.168.88.105:502'), findsOneWidget);
    expect(find.text('Modbus TCP • ID: 1'), findsWidgets);
    expect(find.text('Modbus TCP • ID: 2'), findsOneWidget);
    expect(find.text('Connect'), findsAtLeastNWidgets(2));
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('empty scan panel starts scanning', (tester) async {
    final scanner = _ScanPort(ScannerStateView.idle);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      scanner,
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    expect(find.text('Scan network'), findsOneWidget);
    await tester.tap(find.text('Scan network'));
    await tester.pump();

    expect(scanner.startCalled, isTrue);
    expect(find.text('Network scanner'), findsOneWidget);
  });

  testWidgets('saved devices preview keeps scan button visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await DeviceRepository.instance.replaceAll([
      for (var i = 1; i <= 5; i++)
        DeviceInfo(
          name: 'Device #$i',
          host: '192.168.0.${100 + i}',
          port: 502,
          protocol: ProtocolType.modbusTcp,
          unitId: 1,
          createdAt: DateTime(2026, 5, 24, 12, i),
        ),
    ]);

    final scanner = _ScanPort(ScannerStateView.idle);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      scanner,
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.devices_outlined),
                label: 'Devices',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_on_outlined),
                label: 'Registers',
              ),
            ],
          ),
        ),
      ),
    );

    final savedTop = tester.getTopLeft(find.text('Saved connections')).dy;
    final scanCenter = tester.getCenter(find.text('Scan network'));
    final navTop = tester.getTopLeft(find.byType(BottomNavigationBar)).dy;

    expect(savedTop, lessThan(scanCenter.dy));
    expect(find.text('Device #5'), findsOneWidget);
    expect(find.text('Device #3'), findsOneWidget);
    expect(find.text('Device #2'), findsNothing);
    expect(find.text('+ 2 more'), findsOneWidget);
    expect(find.text('Show all (5)'), findsOneWidget);
    expect(scanCenter.dy, lessThan(navTop));

    await tester.tap(find.text('Show all (5)'));
    await tester.pumpAndSettle();

    expect(find.text('Saved connections'), findsWidgets);
    expect(find.text('Device #5'), findsOneWidget);
    expect(find.text('Device #1'), findsOneWidget);
    expect(find.text('Last connected'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
  });

  testWidgets('favorites are preferred on devices preview', (tester) async {
    await DeviceRepository.instance.replaceAll([
      DeviceInfo(
        name: 'Newest',
        host: '192.168.0.10',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        createdAt: DateTime(2026, 5, 24, 12, 5),
      ),
      DeviceInfo(
        name: 'Favorite Old',
        host: '192.168.0.11',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        createdAt: DateTime(2026, 5, 24, 12, 1),
        isFavorite: true,
      ),
    ]);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      _ScanPort(ScannerStateView.idle),
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    expect(find.text('Favorite Old'), findsOneWidget);
    expect(find.text('Newest'), findsNothing);
  });

  testWidgets('saved devices screen searches and persists sort mode', (
    tester,
  ) async {
    await DeviceRepository.instance.replaceAll([
      DeviceInfo(
        name: 'Created New',
        host: '192.168.0.10',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        createdAt: DateTime(2026, 5, 24, 12, 3),
      ),
      DeviceInfo(
        name: 'Recently Connected',
        host: '192.168.0.20',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        createdAt: DateTime(2026, 5, 24, 12, 1),
        lastConnectedAt: DateTime(2026, 5, 24, 13),
      ),
      DeviceInfo(
        name: 'Created Old',
        host: '10.0.0.30',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        createdAt: DateTime(2026, 5, 24, 12, 2),
      ),
      DeviceInfo(
        name: 'Created Oldest',
        host: '10.0.0.40',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        createdAt: DateTime(2026, 5, 24, 12),
      ),
    ]);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      _ScanPort(ScannerStateView.idle),
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    await tester.tap(find.text('Show all (4)'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Recently Connected')).dy,
      lessThan(tester.getTopLeft(find.text('Created New')).dy),
    );

    await tester.enterText(find.byType(TextField).last, '10.0.0');
    await tester.pump();

    expect(find.text('Created Old'), findsOneWidget);
    expect(find.text('Created New'), findsNothing);

    await tester.enterText(find.byType(TextField).last, '');
    await tester.pump();
    await tester.tap(find.text('Created'));
    await tester.pumpAndSettle();

    expect(AppSettings.instance.savedDevicesSortMode, DeviceSortMode.created);
    expect(
      tester.getTopLeft(find.text('Created New')).dy,
      lessThan(tester.getTopLeft(find.text('Recently Connected')).dy),
    );
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
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    expect(find.text('Discovered devices'), findsOneWidget);
    expect(find.text('192.168.88.104:502'), findsOneWidget);
    expect(find.text('Scan completed'), findsNothing);
    expect(find.text('Scan network'), findsOneWidget);

    await tester.tap(find.text('Scan network'));
    await tester.pump();

    expect(scanner.startCalled, isTrue);
    expect(find.text('Network scanner'), findsOneWidget);
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
      AppSettings.instance,
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
    expect(device.lastConnectedAt, isNotNull);
    expect(runtime.isConnected(device), isTrue);
    expect(openedDeviceId, device.id);
    expect(scanner.discoveredDevices.isEmpty, isTrue);
    expect(find.text('Device #1'), findsOneWidget);
    expect(find.text('Connect to Device'), findsNothing);
  });

  test('unsupported discovered protocol is not saved or removed', () async {
    final discovered = DiscoveredDevice(
      host: '192.168.88.104',
      port: 502,
      unitId: 1,
      protocol: ProtocolType.modbusRtuIp,
    );
    final scanner = _ScanPort(ScannerStateView.done, discovered: [discovered]);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      scanner,
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await expectLater(
      controller.connectDiscoveredDevice(discovered),
      throwsUnsupportedError,
    );
    expect(controller.devices, isEmpty);
    expect(scanner.discoveredDevices.devices, [discovered]);
  });

  test('connecting saved device updates last connected timestamp', () async {
    final device = DeviceInfo(
      name: 'PLC',
      host: '127.0.0.1',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      createdAt: DateTime(2026, 5, 24, 12),
    );
    await DeviceRepository.instance.replaceAll([device]);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      _ScanPort(ScannerStateView.idle),
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await controller.toggleConnection(device);
    final connectedAt = controller.devices.single.lastConnectedAt;
    await controller.toggleConnection(controller.devices.single);

    expect(connectedAt, isNotNull);
    expect(controller.devices.single.lastConnectedAt, connectedAt);
  });

  test('device sort helpers order by last connection and creation', () async {
    final neverConnectedNew = DeviceInfo(
      name: 'Never Connected New',
      host: '127.0.0.1',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      createdAt: DateTime(2026, 5, 24, 12, 3),
    );
    final connectedOld = DeviceInfo(
      name: 'Connected Old',
      host: '127.0.0.2',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      createdAt: DateTime(2026, 5, 24, 12, 1),
      lastConnectedAt: DateTime(2026, 5, 24, 13),
    );
    final neverConnectedOld = DeviceInfo(
      name: 'Never Connected Old',
      host: '127.0.0.3',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      createdAt: DateTime(2026, 5, 24, 12, 2),
    );
    await DeviceRepository.instance.replaceAll([
      neverConnectedNew,
      connectedOld,
      neverConnectedOld,
    ]);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      _ScanPort(ScannerStateView.idle),
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    expect(
      controller
          .devicesForSearchAndSort('', DeviceSortMode.lastConnected)
          .map((device) => device.name),
      ['Connected Old', 'Never Connected New', 'Never Connected Old'],
    );
    expect(
      controller
          .devicesForSearchAndSort('', DeviceSortMode.created)
          .map((device) => device.name),
      ['Never Connected New', 'Never Connected Old', 'Connected Old'],
    );
  });

  testWidgets('scan sheet action button stays visible with many devices', (
    tester,
  ) async {
    // Width > 420 avoids overflow in _ScanTimeLabels (Row vs Column layout threshold).
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scanner = _ScanPort(
      ScannerStateView.done,
      discovered: const [
        DiscoveredDevice(
          host: '192.168.0.101',
          port: 502,
          unitId: 1,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.102',
          port: 502,
          unitId: 2,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.103',
          port: 502,
          unitId: 3,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.104',
          port: 502,
          unitId: 4,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.105',
          port: 502,
          unitId: 5,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.106',
          port: 502,
          unitId: 6,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.107',
          port: 502,
          unitId: 7,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.108',
          port: 502,
          unitId: 8,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.109',
          port: 502,
          unitId: 9,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.110',
          port: 502,
          unitId: 10,
          protocol: ProtocolType.modbusTcp,
        ),
      ],
    );
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      scanner,
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    await tester.tap(find.text('Scan network'));
    await tester.pumpAndSettle();

    expect(find.text('Network scanner'), findsOneWidget);
    expect(find.text('Scan completed'), findsOneWidget);

    // Not all 10 devices fit — later entries are hidden.
    expect(find.text('192.168.0.101:502'), findsWidgets); // first device visible
    expect(find.text('192.168.0.110:502'), findsNothing); // last device hidden

    // Action button is rendered within the visible screen area.
    final actionButton = find
        .widgetWithText(OutlinedButton, 'Scan network')
        .last;
    final buttonBottom = tester.getRect(actionButton).bottom;
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(buttonBottom, lessThanOrEqualTo(screenHeight));
  });

  testWidgets('scan sheet footer navigates to discovered devices screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scanner = _ScanPort(
      ScannerStateView.done,
      discovered: const [
        DiscoveredDevice(
          host: '192.168.0.101',
          port: 502,
          unitId: 1,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.102',
          port: 502,
          unitId: 2,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.103',
          port: 502,
          unitId: 3,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.104',
          port: 502,
          unitId: 4,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.105',
          port: 502,
          unitId: 5,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.106',
          port: 502,
          unitId: 6,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.107',
          port: 502,
          unitId: 7,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.108',
          port: 502,
          unitId: 8,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.109',
          port: 502,
          unitId: 9,
          protocol: ProtocolType.modbusTcp,
        ),
        DiscoveredDevice(
          host: '192.168.0.110',
          port: 502,
          unitId: 10,
          protocol: ProtocolType.modbusTcp,
        ),
      ],
    );
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      scanner,
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    await tester.tap(find.text('Scan network'));
    await tester.pumpAndSettle();

    expect(find.text('Network scanner'), findsOneWidget);

    // Footer is visible because not all devices fit.
    // Use .last because the home screen's DiscoveredDevicesPreview also has a
    // "Show all" footer behind the modal.
    // ensureVisible scrolls the sheet's ListView so the footer is in the viewport
    // (not hidden behind the pinned action button).
    final showAllFinder = find.textContaining('Show all').last;
    await tester.ensureVisible(showAllFinder);
    await tester.pumpAndSettle();
    await tester.tap(showAllFinder);
    await tester.pumpAndSettle();

    // Sheet is gone, DiscoveredDevicesScreen is shown with all devices.
    expect(find.text('Network scanner'), findsNothing);
    expect(find.text('Discovered devices'), findsOneWidget);
    expect(find.text('192.168.0.110:502'), findsOneWidget);
  });

  testWidgets('clear button in completed scan sheet clears results and closes', (
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
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      scanner,
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
      ),
    );

    await tester.tap(find.text('Scan network'));
    await tester.pumpAndSettle();

    expect(find.text('Network scanner'), findsOneWidget);
    // Two "Clear" buttons exist: one in DevicesScreen header, one in scan sheet header.
    // Use .last since the modal sheet renders on top (later in widget tree).
    final clearInSheet = find.text('Clear').last;
    expect(clearInSheet, findsOneWidget);

    await tester.tap(clearInSheet);
    await tester.pumpAndSettle();

    // Sheet is closed and results are gone.
    expect(find.text('Network scanner'), findsNothing);
    expect(find.text('192.168.88.104:502'), findsNothing);
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
      AppSettings.instance,
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
    expect(find.text('Scan network'), findsOneWidget);
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
