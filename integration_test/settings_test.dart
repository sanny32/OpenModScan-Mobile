// Settings flow: change a setting through the UI and confirm it is applied and
// persisted. Uses launchSeededApp, so it does not depend on OMODSCAN_DEMO_DATA.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omodscan_mobile/features/settings/settings_screen.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/widgets/app_test_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('toggling a setting applies and persists it', (tester) async {
    await launchSeededApp(tester);

    await goToTab(tester, AppTestKeys.navSettingsTab);
    expect(find.text('Settings'), findsWidgets);

    final initial = AppSettings.instance.scanClearOnStart;

    // Open the Network scanner section and flip its only toggle ("Clear
    // results on start"). Finders are scoped to the SettingsScreen: the nav
    // shell keeps the devices branch mounted (IndexedStack), and that branch
    // also renders an Icons.sensors scan button, so an unscoped finder is
    // ambiguous.
    await tester.tap(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byIcon(Icons.sensors),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(AppSettings.instance.scanClearOnStart, !initial);

    // Round-trip through the store to prove it was persisted, not just in
    // memory. The switch persists fire-and-forget through many sequential
    // writes, so wait for the backing store to reflect the change before
    // reloading. (Polling via AppSettings.load() instead would reset the
    // in-memory value mid-write and make the pending save persist the old one.)
    final prefs = await SharedPreferences.getInstance();
    for (var attempt = 0; attempt < 100; attempt++) {
      if (prefs.getBool('scanClearOnStart') == !initial) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await AppSettings.instance.load();
    expect(AppSettings.instance.scanClearOnStart, !initial);
  });
}
