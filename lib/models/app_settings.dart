class AppSettings {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  static const registerOrders = ['MSRF', 'LSRF'];
  static const byteOrders = ['Direct', 'Swapped'];
  static const addressBases = ['0-based', '1-based'];
  static const readFailureAttemptOptions = [1, 2, 3, 5, 10];

  String connectionType = 'Modbus TCP';
  int timeout = 1000;
  int reconnectDelay = 3000;
  int readFailureAttempts = 3;
  int defaultUnitId = 1;
  int defaultReadQty = 20;
  String addressBase = addressBases.first;
  String registerOrder = registerOrders.first;
  String byteOrder = byteOrders.first;
  bool confirmBeforeWrite = true;
  bool showLastValues = true;
  bool saveLogToFile = false;
  bool clearLogOnDisconnect = false;
  int maxLogEntries = 1000;
  String theme = 'System';
  String language = 'English';

  void resetToDefaults() {
    connectionType = 'Modbus TCP';
    timeout = 1000;
    reconnectDelay = 3000;
    readFailureAttempts = 3;
    defaultUnitId = 1;
    defaultReadQty = 20;
    addressBase = addressBases.first;
    registerOrder = registerOrders.first;
    byteOrder = byteOrders.first;
    confirmBeforeWrite = true;
    showLastValues = true;
    saveLogToFile = false;
    clearLogOnDisconnect = false;
    maxLogEntries = 1000;
    theme = 'System';
    language = 'English';
  }
}
