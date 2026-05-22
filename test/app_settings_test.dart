import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('editable settings write through to preferences', () async {
    final settings = AppSettings.instance;
    await settings.resetToDefaults();

    await settings.setAddressBase('1-based');
    await settings.setByteOrder('Swapped');
    await settings.setReadFailureAttempts(5);
    await settings.setSaveLogToFile(true);
    await settings.setShowTypeBadges(true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('addressBase'), '1-based');
    expect(prefs.getString('byteOrder'), 'Swapped');
    expect(prefs.getInt('readFailureAttempts'), 5);
    expect(prefs.getBool('saveLogToFile'), isTrue);
    expect(prefs.getBool('showTypeBadges'), isTrue);
  });
}
