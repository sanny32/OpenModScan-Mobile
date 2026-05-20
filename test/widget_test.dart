import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OModScanApp());
    expect(find.text('OpenModScan'), findsOneWidget);
  });
}
