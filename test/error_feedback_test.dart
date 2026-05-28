import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/services/modbus_client.dart';
import 'package:omodscan_mobile/widgets/error_feedback.dart';

void main() {
  testWidgets('formats connection errors without exposing exception class', (
    tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final message = errorFeedbackMessage(
      capturedContext,
      const ModbusClientException('Could not connect to 192.168.0.10:502.'),
    );

    expect(message.title, 'Connection failed');
    expect(
      message.body,
      'Could not reach 192.168.0.10:502. Check the IP address, port, and network availability.',
    );
    expect(message.body, isNot(contains('ModbusClientException')));
  });

  testWidgets('shows readable floating error snackbar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showErrorSnackBar(
                context,
                const ModbusClientException('Could not connect to :502.'),
              ),
              child: const Text('Show error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show error'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final colorScheme = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).colorScheme;

    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.backgroundColor, colorScheme.errorContainer);
    expect(find.text('Connection failed'), findsOneWidget);
    expect(find.textContaining('Could not reach the device'), findsOneWidget);
    expect(find.textContaining('ModbusClientException'), findsNothing);
  });
}
