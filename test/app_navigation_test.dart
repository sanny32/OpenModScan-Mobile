import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/devices/device_screen.dart';
import 'package:omodscan_mobile/main.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_fixtures.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.resetToDefaults();
    await DeviceRepository.instance.replaceAll(List.of(demoDevices));
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OModScanApp());

    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('Each tab keeps its nested navigation stack', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLC #1').first);
    await tester.pumpAndSettle();
    expect(find.byType(DeviceScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.devices_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(DeviceScreen), findsOneWidget);
  });

  testWidgets('Deleted device snackbar disappears after timeout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();

    await tester.drag(find.text('PLC #1'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Device deleted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Device deleted'), findsNothing);
  });

  testWidgets('New device name is prefilled and required', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final nameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == 'Device #6',
    );
    expect(nameField, findsOneWidget);

    await tester.enterText(nameField, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('New device form rejects duplicate name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final nameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == 'Device #6',
    );
    await tester.enterText(nameField, 'PLC #1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name already exists'), findsOneWidget);
  });

  testWidgets('Register list dialog closes without disposed controllers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RegisterListDialogHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Register list dialog rejects duplicate name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const RegisterListDialogHarness(existingNames: ['List 1']),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name already exists'), findsOneWidget);
  });

  testWidgets('Register list dialog clears error when name is changed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const RegisterListDialogHarness(existingNames: ['List 1']),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Name already exists'), findsOneWidget);

    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'List 1',
      ),
      'List 2',
    );
    await tester.pump();

    expect(find.text('Name already exists'), findsNothing);
  });
}
