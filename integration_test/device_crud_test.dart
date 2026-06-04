// Device create/edit/delete flow driven entirely through the UI. Seeds its own
// state via launchSeededApp, so it is independent of OMODSCAN_DEMO_DATA and is
// green whether or not the demo flag is set.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:omodscan_mobile/widgets/app_test_keys.dart';

import 'support/integration_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final alpha = DeviceInfo(
    id: 'crud-alpha',
    name: 'CRUD Alpha',
    host: '192.168.50.10',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
    createdAt: DateTime(2026, 5, 24, 12, 2),
  );
  final beta = DeviceInfo(
    id: 'crud-beta',
    name: 'CRUD Beta',
    host: '192.168.50.11',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
    createdAt: DateTime(2026, 5, 24, 12, 1),
  );

  testWidgets('create, edit and delete a saved device', (tester) async {
    await launchSeededApp(tester, devices: [alpha, beta]);

    expect(find.text('CRUD Alpha'), findsOneWidget);
    expect(find.text('CRUD Beta'), findsOneWidget);

    // Create.
    await tester.tap(find.byKey(AppTestKeys.deviceAddButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(AppTestKeys.deviceFormNameField),
      'CRUD Gamma',
    );
    await tester.tap(find.byKey(AppTestKeys.deviceFormSaveButton));
    await tester.pumpAndSettle();

    expect(find.text('CRUD Gamma'), findsOneWidget);
    expect(_names(), contains('CRUD Gamma'));

    // Edit Alpha via its detail screen.
    await tester.tap(find.byKey(ValueKey(alpha.id)));
    await tester.pumpAndSettle();
    // Open the device form via the AppBar edit action. (Targeting it by key:
    // the notes section also renders an edit_outlined icon, and the Scaffold
    // builds the body before the appBar, so find.byIcon(...).first would hit
    // the notes icon and open the notes sheet instead.)
    await tester.tap(find.byKey(AppTestKeys.deviceEditButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(AppTestKeys.deviceFormNameField),
      'CRUD Alpha Edited',
    );
    // In edit mode the only save control is the button at the bottom of the
    // form's scrollable list, so scroll it into view before tapping.
    final saveButton = find.byKey(AppTestKeys.deviceFormSaveButton);
    await tester.scrollUntilVisible(
      saveButton,
      200,
      // The form's own list scrollable — `.first` skips the inner scrollables
      // each TextField builds for its editable content.
      scrollable: find
          .descendant(
            of: find.byKey(AppTestKeys.deviceFormScrollable),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    // Custom back IconButton (no 'Back' tooltip) — pageBack() can't find it.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('CRUD Alpha Edited'), findsOneWidget);
    expect(find.text('CRUD Alpha'), findsNothing);
    expect(_names(), contains('CRUD Alpha Edited'));
    expect(_names(), isNot(contains('CRUD Alpha')));

    // Delete Beta by swiping its card away (Dismissible, end-to-start).
    await tester.drag(find.byKey(ValueKey(beta.id)), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('CRUD Beta'), findsNothing);
    expect(
      DeviceRepository.instance.snapshot.any((d) => d.id == beta.id),
      isFalse,
    );
  });
}

List<String> _names() =>
    DeviceRepository.instance.snapshot.map((d) => d.name).toList();
