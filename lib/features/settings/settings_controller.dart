import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';
import '../../models/device_info.dart';
import '../../models/modbus_scan.dart';
import '../../services/backup_service.dart';

class SettingsController extends ChangeNotifier {
  final AppSettings settings;
  final BackupService _backup;

  SettingsController(this.settings, {BackupService? backupService})
    : _backup = backupService ?? BackupService();

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

  Future<void> setConnectionType(ProtocolType value) async {
    await settings.setConnectionType(value);
    notifyListeners();
  }

  Future<void> setTimeout(int value) async {
    await settings.setTimeout(value);
    notifyListeners();
  }

  Future<void> setReconnectDelay(int value) async {
    await settings.setReconnectDelay(value);
    notifyListeners();
  }

  Future<void> setDefaultUnitId(int value) async {
    await settings.setDefaultUnitId(value);
    notifyListeners();
  }

  Future<void> setDefaultReadQty(int value) async {
    await settings.setDefaultReadQty(value);
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

  Future<void> setWriteEnabled(bool value) async {
    await settings.setWriteEnabled(value);
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

  Future<void> setMaxLogEntries(int value) async {
    await settings.setMaxLogEntries(value);
    notifyListeners();
  }

  Future<void> setScanProtocol(ProtocolType value) async {
    await settings.setScanProtocol(value);
    notifyListeners();
  }

  Future<void> setScanSubnetPrefix(int value) async {
    await settings.setScanSubnetPrefix(value);
    notifyListeners();
  }

  Future<void> setScanPortRange(int start, int end) async {
    await settings.setScanPortRange(start, end);
    notifyListeners();
  }

  Future<void> setScanUnitIdRange(int start, int end) async {
    await settings.setScanUnitIdRange(start, end);
    notifyListeners();
  }

  Future<void> setScanRequestType(ModbusScanRequestType value) async {
    await settings.setScanRequestType(value);
    notifyListeners();
  }

  Future<void> setScanRequestAddress(int value) async {
    await settings.setScanRequestAddress(value);
    notifyListeners();
  }

  Future<void> setScanConnectTimeout(int value) async {
    await settings.setScanConnectTimeout(value);
    notifyListeners();
  }

  Future<void> setScanConcurrency(int value) async {
    await settings.setScanConcurrency(value);
    notifyListeners();
  }

  Future<void> setScanClearOnStart(bool value) async {
    await settings.setScanClearOnStart(value);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await settings.resetToDefaults();
    notifyListeners();
  }

  Future<BackupResult> exportBackup({String? dialogTitle}) =>
      _backup.export(dialogTitle: dialogTitle);

  Future<BackupResult> importBackup({String? dialogTitle}) async {
    final result = await _backup.import(dialogTitle: dialogTitle);
    if (result == BackupResult.success) notifyListeners();
    return result;
  }
}
