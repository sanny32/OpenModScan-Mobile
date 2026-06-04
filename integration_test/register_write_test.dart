// Drives the write-value screen through the full app in demo mode.
//
// The demo build wires the real ConnectionManager, and the Write Value entry on
// the device screen is gated on an active connection. So the test first points
// the demo device at a local loopback socket and connects it (ModbusClientTcp
// only opens a TCP socket on connect — no handshake), which makes the Write
// Value card reachable. It then verifies the value-composition UI and that the
// submit button is enabled once connected.
// REQUIRES --dart-define=OMODSCAN_DEMO_DATA=true (see scripts/integration_test.sh).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_fixtures.dart';
import 'package:omodscan_mobile/services/connection_manager.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:omodscan_mobile/widgets/app_test_keys.dart';

import 'support/integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('write screen composes value with an active connection', (
    tester,
  ) async {
    await launchDemoApp(tester);

    // Stand up a loopback TCP server and connect the first demo device to it so
    // the connection-gated Write Value card becomes reachable.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = <Socket>[];
    server.listen((socket) {
      accepted.add(socket);
      socket.drain<void>();
    });
    addTearDown(() async {
      for (final socket in accepted) {
        socket.destroy();
      }
      await server.close();
      await ConnectionManager.instance.resetForTesting();
    });

    final device = demoDevices.first.copyWith(
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
    );
    await DeviceRepository.instance.update(device);
    await ConnectionManager.instance.connect(device);
    await tester.pumpAndSettle();

    // Open the device, then its (now enabled) write screen.
    await tester.tap(find.byKey(ValueKey(device.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write Value'));
    await tester.pumpAndSettle();

    // Switch type to UInt32 and type a value that spans two registers.
    await tester.tap(find.text('UInt16'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UInt32').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '65538');
    await tester.pump();

    // The raw-words preview is computed by the real screen logic.
    expect(find.textContaining('0x0001, 0x0002'), findsOneWidget);

    // Dismiss the keyboard so the submit button (bottom bar) is back in tree.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Connected with writing enabled, so the submit action is available.
    final submit = tester.widget<FilledButton>(
      find.byKey(AppTestKeys.deviceWriteSubmitButton),
    );
    expect(submit.onPressed, isNotNull);
  });
}
