import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round-trips typed values through SharedPreferences', () async {
    final store = SharedPreferencesSettingsStore();
    await store.load();

    await store.setString('name', 'PLC');
    await store.setInt('count', 7);
    await store.setBool('flag', true);

    final reopened = SharedPreferencesSettingsStore();
    await reopened.load();
    expect(reopened.getString('name'), 'PLC');
    expect(reopened.getInt('count'), 7);
    expect(reopened.getBool('flag'), isTrue);
  });

  test('returns null for absent keys', () async {
    final store = SharedPreferencesSettingsStore();
    await store.load();

    expect(store.getString('missing'), isNull);
    expect(store.getInt('missing'), isNull);
    expect(store.getBool('missing'), isNull);
  });

  test('getString guards against keys stored as a different type', () async {
    SharedPreferences.setMockInitialValues({'addressBase': 42});
    final store = SharedPreferencesSettingsStore();
    await store.load();

    expect(store.getString('addressBase'), isNull);
  });

  test('reading before load throws a clear error', () {
    final store = SharedPreferencesSettingsStore();
    expect(() => store.getString('name'), throwsStateError);
  });
}
