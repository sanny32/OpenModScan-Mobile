import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/main.dart' as app;
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared helpers for driving the full app inside integration tests.
///
/// Two launch flavours are provided so the suite covers both initialisation
/// paths in `main.dart` (`seedDevices: AppFlags.demoData ? demoDevices : []`):
///
/// * [launchDemoApp] — for scenarios that assert on the bundled demo fixtures.
///   These MUST be run with `--dart-define=OMODSCAN_DEMO_DATA=true`, otherwise
///   the repository starts empty and the demo assertions fail. Use
///   `scripts/integration_test.sh`, which sets the flag automatically.
/// * [launchSeededApp] — for scenarios that own their state. It seeds the
///   repository explicitly via the UI-facing [DeviceRepository], so it does NOT
///   depend on the compile-time flag and is green with or without it.

/// Resets persisted state and launches the app, leaving whatever devices the
/// demo flag seeds. Forces English so text assertions are stable.
Future<void> launchDemoApp(WidgetTester tester) async {
  await _resetPreferences();
  await app.main();
  await tester.pumpAndSettle();
}

/// Resets persisted state, launches the app, then seeds [devices] through the
/// live [DeviceRepository] so the saved-devices list reflects them. Independent
/// of the `OMODSCAN_DEMO_DATA` compile-time flag.
Future<void> launchSeededApp(
  WidgetTester tester, {
  List<DeviceInfo> devices = const [],
}) async {
  await _resetPreferences();
  await app.main();
  await tester.pumpAndSettle();
  if (devices.isNotEmpty) {
    await DeviceRepository.instance.replaceAll(List.of(devices));
    await tester.pumpAndSettle();
  }
}

/// Taps a bottom-navigation tab by its stable key (real gesture, not a direct
/// `onTap` call), then settles. Pass one of the `AppTestKeys.nav*Tab` keys.
Future<void> goToTab(WidgetTester tester, ValueKey<String> tabKey) async {
  await tester.tap(find.byKey(tabKey));
  await tester.pumpAndSettle();
}

Future<void> _resetPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  // Force English so localized text assertions are deterministic.
  await prefs.setString('locale', 'en');
}
