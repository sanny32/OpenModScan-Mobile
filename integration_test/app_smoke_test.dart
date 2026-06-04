import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omodscan_mobile/main.dart' as app;
import 'package:omodscan_mobile/runtime/fakes/demo_fixtures.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:omodscan_mobile/widgets/app_test_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo app smoke flow', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString('locale', 'en');

    await app.main();
    await tester.pumpAndSettle();

    final firstDevice = demoDevices.first;
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text(firstDevice.name), findsOneWidget);

    await tester.tap(find.byKey(ValueKey(firstDevice.id)));
    await tester.pumpAndSettle();
    expect(find.text(firstDevice.name), findsOneWidget);

    await _goToTab(tester, 1);
    expect(find.text('40000'), findsWidgets);
    expect(find.text('Operating mode'), findsWidgets);

    await _goToTab(tester, 2);
    expect(find.text('03 Read Holding Registers'), findsWidgets);

    await _goToTab(tester, 3);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Connection'), findsWidgets);
    expect(find.text('Appearance'), findsWidgets);

    await _goToTab(tester, 0);
    await _goToTab(tester, 0);
    await tester.tap(find.byKey(AppTestKeys.deviceAddButton));
    await tester.pumpAndSettle();

    const newDeviceName = 'Integration Smoke Device';
    await tester.enterText(
      find.byKey(AppTestKeys.deviceFormNameField),
      newDeviceName,
    );
    await tester.tap(find.byKey(AppTestKeys.deviceFormSaveButton));
    await tester.pumpAndSettle();

    expect(
      DeviceRepository.instance.snapshot.any(
        (device) => device.name == newDeviceName,
      ),
      isTrue,
    );
  });
}

Future<void> _goToTab(WidgetTester tester, int index) async {
  tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).onTap!(
    index,
  );
  await tester.pumpAndSettle();
}
