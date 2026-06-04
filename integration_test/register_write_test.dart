// Drives the write-value screen through the full app in demo mode. The demo
// build wires the real ConnectionManager, so the demo device is not actually
// connected — this verifies the value-composition UI and the connection gating
// (submit stays disabled until connected) rather than a live socket write.
// REQUIRES --dart-define=OMODSCAN_DEMO_DATA=true (see scripts/integration_test.sh).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_fixtures.dart';
import 'package:omodscan_mobile/widgets/app_test_keys.dart';

import 'support/integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('write screen composes value and gates on connection', (
    tester,
  ) async {
    await launchDemoApp(tester);

    // Open the first device, then its write screen.
    await tester.tap(find.byKey(ValueKey(demoDevices.first.id)));
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

    // Demo device is not connected, so writing must stay disabled.
    final submit = tester.widget<FilledButton>(
      find.byKey(AppTestKeys.deviceWriteSubmitButton),
    );
    expect(submit.onPressed, isNull);
  });
}
