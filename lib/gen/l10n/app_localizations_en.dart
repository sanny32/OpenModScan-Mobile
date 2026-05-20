// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenModScan Mobile';

  @override
  String get navDevices => 'Devices';

  @override
  String get navRegisters => 'Registers';

  @override
  String get navLog => 'Log';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String unitId(int id) {
    return 'ID: $id';
  }

  @override
  String get devicesSearch => 'Search devices';

  @override
  String get devicesSavedConnections => 'Saved connections';

  @override
  String get devicesDiscoveredDevices => 'Discovered devices';

  @override
  String get devicesLastUsed => 'Last used';

  @override
  String get devicesConnect => 'Connect';

  @override
  String get devicesScanNetwork => 'Scan network';

  @override
  String protocolAndUnitId(String protocol, int unitId) {
    return '$protocol • ID: $unitId';
  }

  @override
  String get appBarName => 'OpenModScan';

  @override
  String get appBarNameSuffix => ' Mobile';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get readRegisters => 'Read Registers';

  @override
  String get readRegistersSubtitle => 'Read holding/input\nregisters';

  @override
  String get writeValue => 'Write Value';

  @override
  String get writeValueSubtitle => 'Write single/multiple\nregisters';

  @override
  String get lastValues => 'Last Values';

  @override
  String get viewAll => 'View All >';

  @override
  String get openLog => 'Open Log';

  @override
  String get openLogSubtitle => 'View communication log';

  @override
  String get tabCoils => 'Coils';

  @override
  String get colAddress => 'Address';

  @override
  String get colValue => 'Value';

  @override
  String get colType => 'Type';

  @override
  String get colComment => 'Comment';

  @override
  String get btnRead => 'Read';

  @override
  String get labelStart => 'Start';

  @override
  String get labelCount => 'Count';

  @override
  String get labelAutoRefresh => 'Auto refresh';

  @override
  String registersShowing(int start, int end) {
    return 'Showing $start – $end';
  }

  @override
  String registersLastUpdate(String time) {
    return 'Last update: $time';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterTx => 'TX';

  @override
  String get filterRx => 'RX';

  @override
  String get filterErrors => 'Errors';

  @override
  String get labelAutoScroll => 'Auto scroll';

  @override
  String get colTime => 'Time';

  @override
  String get colDirection => 'Direction';

  @override
  String get colFunction => 'Function';

  @override
  String logMessages(int count) {
    return 'Messages: $count';
  }

  @override
  String get logClearOnDisconnect => 'Clear on disconnect';

  @override
  String get connectToDevice => 'Connect to device';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get connect => 'Connect';

  @override
  String get connectionType => 'Connection type';

  @override
  String get connectTypeTcp => 'Modbus TCP';

  @override
  String get connectTypeTcpSub => 'Standard Modbus TCP';

  @override
  String get connectTypeRtu => 'RTU over TCP/IP';

  @override
  String get connectTypeRtuSub => 'Modbus RTU over TCP';

  @override
  String get labelName => 'Name';

  @override
  String get labelHost => 'Host / IP address';

  @override
  String get labelPort => 'Port';

  @override
  String get labelUnitIdField => 'Unit ID (Slave ID)';

  @override
  String get labelTimeout => 'Timeout';

  @override
  String get labelReconnectDelay => 'Reconnect delay';

  @override
  String get labelNotes => 'Notes (optional)';

  @override
  String get notesHint => 'Add any notes about this connection';
}
