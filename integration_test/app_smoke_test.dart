// Demo smoke flow. REQUIRES the demo fixtures, so it must be launched with
// `--dart-define=OMODSCAN_DEMO_DATA=true` (see scripts/integration_test.sh).
// Without the flag the repository starts empty and the demo assertions fail.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_fixtures.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:omodscan_mobile/widgets/app_test_keys.dart';

import 'support/integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo app smoke flow', (tester) async {
    await launchDemoApp(tester);

    final firstDevice = demoDevices.first;
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text(firstDevice.name), findsOneWidget);

    // Open the first device's detail screen.
    await tester.tap(find.byKey(ValueKey(firstDevice.id)));
    await tester.pumpAndSettle();
    expect(find.text(firstDevice.name), findsOneWidget);

    // Real taps on the bottom navigation (not a direct onTap call).
    await goToTab(tester, AppTestKeys.navRegistersTab);
    expect(find.text('40000'), findsWidgets);
    expect(find.text('Operating mode'), findsWidgets);

    await goToTab(tester, AppTestKeys.navLogTab);
    expect(find.text('03 Read Holding Registers'), findsWidgets);

    await goToTab(tester, AppTestKeys.navSettingsTab);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Connection'), findsWidgets);
    expect(find.text('Appearance'), findsWidgets);

    // Back to the devices branch (still showing the pushed detail), then pop
    // the detail to reach the saved-devices list where the add button lives.
    await goToTab(tester, AppTestKeys.navDevicesTab);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppTestKeys.deviceAddButton));
    await tester.pumpAndSettle();

    const newDeviceName = 'Integration Smoke Device';
    await tester.enterText(
      find.byKey(AppTestKeys.deviceFormNameField),
      newDeviceName,
    );
    await tester.tap(find.byKey(AppTestKeys.deviceFormSaveButton));
    await tester.pumpAndSettle();

    // Verify both the UI list and the underlying repository.
    expect(find.text(newDeviceName), findsOneWidget);
    expect(
      DeviceRepository.instance.snapshot.any(
        (device) => device.name == newDeviceName,
      ),
      isTrue,
    );
  });
}
