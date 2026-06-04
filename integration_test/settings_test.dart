// Settings flow: change a setting through the UI and confirm it is applied and
// persisted. Uses launchSeededApp, so it does not depend on OMODSCAN_DEMO_DATA.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/widgets/app_test_keys.dart';

import 'support/integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('toggling a setting applies and persists it', (tester) async {
    await launchSeededApp(tester);

    await goToTab(tester, AppTestKeys.navSettingsTab);
    expect(find.text('Settings'), findsWidgets);

    final initial = AppSettings.instance.scanClearOnStart;

    // Open the Network scanner section (unique sensors icon) and flip its only
    // toggle ("Clear results on start").
    await tester.tap(find.byIcon(Icons.sensors));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(AppSettings.instance.scanClearOnStart, !initial);

    // Round-trip through the store to prove it was persisted, not just in memory.
    await AppSettings.instance.load();
    expect(AppSettings.instance.scanClearOnStart, !initial);
  });
}
