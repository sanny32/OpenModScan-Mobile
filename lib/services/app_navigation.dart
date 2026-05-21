import 'package:flutter/foundation.dart';

class AppNavigationService {
  static final instance = AppNavigationService._();
  AppNavigationService._();

  final tabIndex = ValueNotifier<int>(0);

  /// Non-null means RegistersScreen should switch to this device and start reading.
  final pendingDevice = ValueNotifier<String?>(null);

  void goToRegisters(String deviceName) {
    pendingDevice.value = deviceName;
    tabIndex.value = 1;
  }
}
