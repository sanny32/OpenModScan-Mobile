import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/devices/device_form_sheet.dart';
import 'package:omodscan_mobile/features/devices/devices_controller.dart';
import 'package:omodscan_mobile/features/devices/devices_screen.dart';
import 'package:omodscan_mobile/features/devices/saved_devices_screen.dart';
import 'package:omodscan_mobile/features/devices/widgets/device_card.dart';
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
    expect(find.text('Device #2'), findsOneWidget);
    expect(find.text('Device #1'), findsOneWidget);
    expect(scanCenter.dy, lessThan(navTop));
  });

  testWidgets('saved devices never clip behind the scan dock', (tester) async {
    tester.view.physicalSize = const Size(393, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await DeviceRepository.instance.replaceAll([
      for (var i = 1; i <= 7; i++)
        DeviceInfo(
          name: 'Device #$i',
          host: '192.168.0.${100 + i}',
          port: 502,
          protocol: ProtocolType.modbusTcp,
          unitId: 1,
          createdAt: DateTime(2026, 5, 24, 12, i),
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

    // Not all 7 fit, so a footer must offer the rest instead of clipping a card.
    expect(find.text('Show all (7)'), findsOneWidget);

    // No rendered device card may extend below the scan dock (no clipping).
    final scanDockTop = tester
        .getTopLeft(find.widgetWithText(OutlinedButton, 'Scan network'))
        .dy;
    for (final card in find.byType(DeviceCard).evaluate()) {
      final bottom = tester.getBottomLeft(find.byWidget(card.widget)).dy;
      expect(bottom, lessThanOrEqualTo(scanDockTop));
    }
  });

  testWidgets('saved devices fit count adapts to text scale', (tester) async {
    tester.view.physicalSize = const Size(393, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await DeviceRepository.instance.replaceAll([
      for (var i = 1; i <= 7; i++)
        DeviceInfo(
          name: 'Device #$i',
          host: '192.168.0.${100 + i}',
          port: 502,
          protocol: ProtocolType.modbusTcp,
          unitId: 1,
          createdAt: DateTime(2026, 5, 24, 12, i),
        ),
    ]);

    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      _ScanPort(ScannerStateView.idle),
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    Widget appAtScale(double scale) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: DevicesScreen(controller: controller, onOpenDevice: (_) {}),
          ),
        ),
      ),
    );

    await tester.pumpWidget(appAtScale(1.0));
    final cardsAtNormal = find.byType(DeviceCard).evaluate().length;

    // Larger font ⇒ taller cards ⇒ the measured-from-theme math fits fewer.
    await tester.pumpWidget(appAtScale(1.8));
    final cardsAtLarge = find.byType(DeviceCard).evaluate().length;

    expect(cardsAtLarge, greaterThanOrEqualTo(1));
    expect(cardsAtLarge, lessThan(cardsAtNormal));
  });

  testWidgets('devices preview follows stored manual order', (tester) async {
    await DeviceRepository.instance.replaceAll([
      DeviceInfo(
        name: 'First',
        host: '192.168.0.10',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        createdAt: DateTime(2026, 5, 24, 12, 5),
      ),
      DeviceInfo(
        name: 'Second',
        host: '192.168.0.11',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        createdAt: DateTime(2026, 5, 24, 12, 1),
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

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    // Home preview mirrors the stored order: 'First' was inserted before 'Second'.
    expect(
      tester.getTopLeft(find.text('First')).dy,
      lessThan(tester.getTopLeft(find.text('Second')).dy),
    );
  });

  testWidgets('home reorder action opens the full saved list', (tester) async {
    DeviceInfo make(String name) => DeviceInfo(
      name: name,
      host: name.toLowerCase(),
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
    );
    await DeviceRepository.instance.replaceAll([make('Alpha'), make('Beta')]);
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

    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();

    expect(find.byType(SavedDevicesScreen), findsOneWidget);
  });

  testWidgets('device card uses selected marker color for memory icon', (
    tester,
  ) async {
    final device = DeviceInfo(
      name: 'PLC Purple',
      host: '192.168.0.50',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      markerColor: DeviceMarkerColor.purple,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DeviceCard(device: device, connected: false, onTap: () {}),
        ),
      ),
    );

    final memoryIcon = tester.widget<Icon>(find.byIcon(Icons.memory));
    expect(memoryIcon.color, const Color(0xFF7B1FA2));
  });

  testWidgets('device form returns selected marker color', (tester) async {
    DeviceFormResult? result;
    final initial = DeviceInfo(
      id: 'device-color-form',
      name: 'PLC Blue',
      host: '192.168.0.60',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet<DeviceFormResult>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) =>
                      DeviceFormSheet(initial: initial, addMode: true),
                ).then((value) => result = value);
              },
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('device-marker-color-teal')));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(result?.device.markerColor, DeviceMarkerColor.teal);
  });

  testWidgets('saved devices screen lists in manual order and filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    // The list follows the persisted manual (storage) order: 'Created New' was
    // inserted before 'Recently Connected'.
    expect(
      tester.getTopLeft(find.text('Created New')).dy,
      lessThan(tester.getTopLeft(find.text('Recently Connected')).dy),
    );
    // Drag handles are offered for manual reordering.
    expect(find.byIcon(Icons.drag_handle), findsWidgets);

    await tester.enterText(find.byType(TextField).last, '10.0.0');
    await tester.pump();

    expect(find.text('Created Old'), findsOneWidget);
    expect(find.text('Created New'), findsNothing);
    // Reordering is suppressed while a search filter is active.
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    await tester.enterText(find.byType(TextField).last, '');
    await tester.pump();
    expect(find.text('Created New'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsWidgets);
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

  test('manual reorder persists order and is honored by manual sort', () async {
    DeviceInfo make(String name, int createdDay) => DeviceInfo(
      name: name,
      host: name.toLowerCase(),
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      createdAt: DateTime(2026, 1, createdDay),
    );
    await DeviceRepository.instance.replaceAll([
      make('A', 1),
      make('B', 2),
      make('C', 3),
    ]);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      _ScanPort(ScannerStateView.idle),
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    // The saved list mirrors the stored repository order verbatim.
    expect(
      controller.savedDevicesForSearch('').map((device) => device.name),
      ['A', 'B', 'C'],
    );

    // Move A (index 0) to the end; onReorderItem reports the post-removal index.
    await controller.reorderSavedDevices(0, 2);
    expect(
      controller.savedDevicesForSearch('').map((device) => device.name),
      ['B', 'C', 'A'],
    );

    // The new order is persisted and survives a reload from the store.
    final reloaded = await DeviceRepository.instance.load();
    expect(reloaded.map((device) => device.name), ['B', 'C', 'A']);
  });

  test('home preview returns the stored order prefix', () async {
    DeviceInfo make(String name, int day) => DeviceInfo(
      name: name,
      host: name.toLowerCase(),
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      createdAt: DateTime(2026, 1, day),
    );
    await DeviceRepository.instance.replaceAll([
      make('A', 1),
      make('B', 2),
      make('C', 3),
    ]);
    final controller = DevicesController(
      DeviceRepository.instance,
      PollingConnectionRuntime(),
      _ScanPort(ScannerStateView.idle),
      AppSettings.instance,
    );
    addTearDown(controller.dispose);

    // The preview is the storage order, not a created/connection sort.
    expect(
      controller.visibleHomeDevices(3).map((device) => device.name),
      ['A', 'B', 'C'],
    );
    expect(
      controller.visibleHomeDevices(2).map((device) => device.name),
      ['A', 'B'],
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
    AppSettings.instance.scanClearOnStart = false;
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
    expect(
      find.text('192.168.0.101:502'),
      findsWidgets,
    ); // first device visible
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
    AppSettings.instance.scanClearOnStart = false;
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
