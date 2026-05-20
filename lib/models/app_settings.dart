class AppSettings {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  String connectionType = 'Modbus TCP';
  int timeout = 1000;
  int reconnectDelay = 3000;
  int defaultUnitId = 1;
  int defaultReadQty = 20;
  bool confirmBeforeWrite = true;
  bool showLastValues = true;
  String logLevel = 'Info';
  bool saveLogToFile = false;
  bool clearLogOnDisconnect = false;
  int maxLogEntries = 1000;
  String theme = 'System';
  String language = 'English';

  void resetToDefaults() {
    connectionType = 'Modbus TCP';
    timeout = 1000;
    reconnectDelay = 3000;
    defaultUnitId = 1;
    defaultReadQty = 20;
    confirmBeforeWrite = true;
    showLastValues = true;
    logLevel = 'Info';
    saveLogToFile = false;
    clearLogOnDisconnect = false;
    maxLogEntries = 1000;
    theme = 'System';
    language = 'English';
  }
}
