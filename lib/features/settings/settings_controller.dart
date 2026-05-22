import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';

class SettingsController extends ChangeNotifier {
  final AppSettings settings;

  SettingsController(this.settings);

  Future<void> setTheme(String value) async {
    await settings.setTheme(value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    await settings.setLanguage(value);
    notifyListeners();
  }

  Future<void> setReadFailureAttempts(int value) async {
    await settings.setReadFailureAttempts(value);
    notifyListeners();
  }

  Future<void> setAddressBase(String value) async {
    await settings.setAddressBase(value);
    notifyListeners();
  }

  Future<void> setRegisterOrder(String value) async {
    await settings.setRegisterOrder(value);
    notifyListeners();
  }

  Future<void> setByteOrder(String value) async {
    await settings.setByteOrder(value);
    notifyListeners();
  }

  Future<void> setConfirmBeforeWrite(bool value) async {
    await settings.setConfirmBeforeWrite(value);
    notifyListeners();
  }

  Future<void> setShowLastValues(bool value) async {
    await settings.setShowLastValues(value);
    notifyListeners();
  }

  Future<void> setShowTypeBadges(bool value) async {
    await settings.setShowTypeBadges(value);
    notifyListeners();
  }

  Future<void> setSaveLogToFile(bool value) async {
    await settings.setSaveLogToFile(value);
    notifyListeners();
  }

  Future<void> setClearLogOnDisconnect(bool value) async {
    await settings.setClearLogOnDisconnect(value);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await settings.resetToDefaults();
    notifyListeners();
  }
}
