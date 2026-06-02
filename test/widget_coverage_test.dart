import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/settings/about_screen.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/theme/app_theme.dart';
import 'package:omodscan_mobile/widgets/data_layout.dart';
import 'package:omodscan_mobile/widgets/device_select_sheet.dart';
import 'package:omodscan_mobile/widgets/type_badge.dart';

import 'helpers.dart';

void main() {
  setUp(resetAppTestState);

  testWidgets('About screen renders app metadata and support links', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AboutScreen()));
    await tester.pump();

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Application'), findsOneWidget);
    expect(find.text('OpenModScan Mobile'), findsAtLeastNWidgets(1));
    expect(find.text('Version'), findsWidgets);
    expect(find.text('Build date'), findsOneWidget);
    expect(find.text('MIT License'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('mail@ananev.org'), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);
  });

  testWidgets('Device select sheet sorts connected devices first and returns id',
      (tester) async {
    final devices = [
      DeviceInfo(
        id: 'z',
        name: 'Zulu',
        host: '10.0.0.3',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
      ),
      DeviceInfo(
        id: 'a',
        name: 'Alpha',
        host: '10.0.0.1',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
      ),
      DeviceInfo(
        id: 'b',
        name: 'Bravo',
        host: '10.0.0.2',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
      ),
    ];
    String? selectedId;

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selectedId = await showDeviceSelectSheet(
                  context,
                  devices: devices,
                  selectedId: 'b',
                  isConnected: (device) => device.id == 'z',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Select Device'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Disconnected'), findsNWidgets(2));
    expect(tester.getTopLeft(find.text('Zulu')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha')).dy));
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(selectedId, 'a');
  });

  testWidgets('Data layout chip opens sheet and reports selections', (
    tester,
  ) async {
    String? registerOrder;
    String? byteOrder;

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: Builder(
            builder: (context) => DataLayoutChip(
              registerOrder: AppSettings.registerOrders.first,
              byteOrder: AppSettings.byteOrders.first,
              onTap: () => showDataLayoutSheet(
                context,
                registerOrder: AppSettings.registerOrders.first,
                byteOrder: AppSettings.byteOrders.first,
                onRegisterOrder: (value) => registerOrder = value,
                onByteOrder: (value) => byteOrder = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('MSRF · Direct'));
    await tester.pumpAndSettle();

    expect(find.text('Data layout'), findsOneWidget);
    await tester.tap(find.text('LSRF'));
    await tester.pump();
    await tester.tap(find.text('Swapped'));
    await tester.pump();

    expect(registerOrder, 'LSRF');
    expect(byteOrder, 'Swapped');
  });

  testWidgets('TypeBadge abbreviates and renders known and unknown types', (
    tester,
  ) async {
    expect(typeAbbrev('UInt16'), 'U16');
    expect(typeAbbrev('Float64'), 'F64');
    expect(typeAbbrev('Binary'), 'BIN');
    expect(typeAbbrev('CustomType'), 'CUST');
    expect(typeAbbrev('abc'), 'ABC');

    await tester.pumpWidget(
      _host(
        const Row(
          children: [
            TypeBadge(type: 'UInt32'),
            TypeBadge(type: 'Int16'),
            TypeBadge(type: 'Float32'),
            TypeBadge(type: 'Hex'),
            TypeBadge(type: 'Binary'),
            TypeBadge(type: 'Other'),
          ],
        ),
      ),
    );

    expect(find.text('U32'), findsOneWidget);
    expect(find.text('I16'), findsOneWidget);
    expect(find.text('F32'), findsOneWidget);
    expect(find.text('HEX'), findsOneWidget);
    expect(find.text('BIN'), findsOneWidget);
    expect(find.text('OTHE'), findsOneWidget);
  });
}

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
