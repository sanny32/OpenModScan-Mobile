import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/main.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/services/app_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.resetToDefaults();
    AppNavigationService.instance.tabIndex.value = 0;
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OModScanApp());

    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('Theme setting updates app theme', (WidgetTester tester) async {
    await tester.pumpWidget(const OModScanApp());

    AppNavigationService.instance.tabIndex.value = 3;
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.light_mode_outlined),
      300,
    );
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final prefs = await SharedPreferences.getInstance();

    expect(app.themeMode, ThemeMode.dark);
    expect(prefs.getString('themeMode'), 'dark');
  });

  testWidgets('Language setting updates app locale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OModScanApp());

    AppNavigationService.instance.tabIndex.value = 3;
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byIcon(Icons.language), 300);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Russian'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final prefs = await SharedPreferences.getInstance();

    expect(app.locale, const Locale('ru'));
    expect(prefs.getString('locale'), 'ru');
    expect(find.text('Системная'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
  });
}
