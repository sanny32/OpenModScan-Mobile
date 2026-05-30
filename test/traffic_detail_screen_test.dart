import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/traffic/traffic_controller.dart';
import 'package:omodscan_mobile/features/traffic/traffic_detail_screen.dart';
import 'package:omodscan_mobile/features/traffic/traffic_screen.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/log_entry.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/theme/app_theme.dart';
import 'package:omodscan_mobile/utils/modbus_traffic_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

LogEntry _readResponse() => buildTrafficLogEntry(
  frame: Uint8List.fromList(const [
    0x00, 0x07, 0x00, 0x00, 0x00, 0x07, 0x01,
    0x03, 0x04, 0x00, 0x7B, 0x00, 0x2D, // values 123, 45
  ]),
  direction: LogDirection.rx,
  time: DateTime(2026, 5, 30, 7, 11, 19, 868),
);

LogEntry _exceptionResponse() => buildTrafficLogEntry(
  frame: Uint8List.fromList(const [
    0x00, 0x01, 0x00, 0x00, 0x00, 0x03, 0x01, 0x83, 0x02,
  ]),
  direction: LogDirection.rx,
  time: DateTime(2026, 5, 30),
);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

class _FakeLogs extends ChangeNotifier implements TrafficLogSource {
  final List<LogEntry> entries;
  _FakeLogs(this.entries);

  @override
  List<LogEntry> entriesFor(String? deviceId) => entries;

  @override
  void clear(String? deviceId) {}
}

class _FakeConnections implements ConnectionRuntime {
  @override
  final ValueNotifier<Set<String>> connectedDeviceIds = ValueNotifier(const {});

  @override
  bool isConnected(DeviceInfo device) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // A tall viewport so the lazy ListView builds every card (incl. off-screen
  // decoded rows and the raw hex dump) within the test.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('renders full breakdown for a read response', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(_host(TrafficDetailScreen(entry: _readResponse())));
    await tester.pumpAndSettle();

    expect(find.text('Transaction ID'), findsOneWidget);
    expect(find.text('0x0007'), findsOneWidget); // transaction id value
    expect(find.text('Unit ID'), findsOneWidget);
    expect(find.text('Values'), findsOneWidget);
    expect(find.text('123, 45'), findsOneWidget);
    // Raw hex dump present.
    expect(
      find.textContaining('00 07 00 00 00 07 01 03 04 00 7B 00 2D'),
      findsOneWidget,
    );
  });

  testWidgets('shows exception description as error', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      _host(TrafficDetailScreen(entry: _exceptionResponse())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Illegal Data Address'), findsOneWidget);
    expect(find.text('Exception code'), findsOneWidget);
  });

  testWidgets('copy button puts hex on the clipboard', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(_host(TrafficDetailScreen(entry: _readResponse())));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();

    expect(copied, hasLength(1));
    expect(copied.single, '00 07 00 00 00 07 01 03 04 00 7B 00 2D');
    expect(find.text('Frame copied to clipboard'), findsOneWidget);
  });

  testWidgets('falls back to a placeholder without frame data', (tester) async {
    await tester.pumpWidget(
      _host(
        const TrafficDetailScreen(
          entry: LogEntry(time: '00:00:00.000', function: 'X', data: 'zz'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No frame data available'), findsOneWidget);
  });

  testWidgets('tapping a traffic row opens the detail screen', (tester) async {
    final device = DeviceInfo(
      id: 'dev-a',
      name: 'Device A',
      host: '127.0.0.1',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
    );
    final repository = FakeDeviceRepository([device]);
    final controller = TrafficController(
      repository,
      _FakeConnections(),
      _FakeLogs([_readResponse()]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(TrafficScreen(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.byType(TrafficDetailScreen), findsNothing);
    await tester.tap(find.text('03 Read Holding Registers').first);
    await tester.pumpAndSettle();

    expect(find.byType(TrafficDetailScreen), findsOneWidget);
  });

  testWidgets('error rows without a frame are not tappable', (tester) async {
    final device = DeviceInfo(
      id: 'dev-a',
      name: 'Device A',
      host: '127.0.0.1',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
    );
    final repository = FakeDeviceRepository([device]);
    final controller = TrafficController(
      repository,
      _FakeConnections(),
      _FakeLogs([
        const LogEntry(
          time: '07:41:13.743',
          function: 'Error',
          data: 'Connection to 192.168.0.104:502 failed!',
          type: LogEntryType.error,
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(TrafficScreen(controller: controller)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Error'));
    await tester.pumpAndSettle();

    expect(find.byType(TrafficDetailScreen), findsNothing);
  });
}
