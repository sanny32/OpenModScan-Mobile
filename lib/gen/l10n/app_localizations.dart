import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenModScan Mobile'**
  String get appTitle;

  /// No description provided for @navDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get navDevices;

  /// No description provided for @navRegisters.
  ///
  /// In en, this message translates to:
  /// **'Registers'**
  String get navRegisters;

  /// No description provided for @navLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get navLog;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get statusDisconnected;

  /// No description provided for @unitId.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String unitId(int id);

  /// No description provided for @devicesSearch.
  ///
  /// In en, this message translates to:
  /// **'Search devices'**
  String get devicesSearch;

  /// No description provided for @devicesSavedConnections.
  ///
  /// In en, this message translates to:
  /// **'Saved connections'**
  String get devicesSavedConnections;

  /// No description provided for @devicesDiscoveredDevices.
  ///
  /// In en, this message translates to:
  /// **'Discovered devices'**
  String get devicesDiscoveredDevices;

  /// No description provided for @devicesLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get devicesLastUsed;

  /// No description provided for @devicesConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get devicesConnect;

  /// No description provided for @devicesScanNetwork.
  ///
  /// In en, this message translates to:
  /// **'Scan network'**
  String get devicesScanNetwork;

  /// No description provided for @protocolAndUnitId.
  ///
  /// In en, this message translates to:
  /// **'{protocol} • ID: {unitId}'**
  String protocolAndUnitId(String protocol, int unitId);

  /// No description provided for @appBarName.
  ///
  /// In en, this message translates to:
  /// **'OpenModScan'**
  String get appBarName;

  /// No description provided for @appBarNameSuffix.
  ///
  /// In en, this message translates to:
  /// **' Mobile'**
  String get appBarNameSuffix;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @readRegisters.
  ///
  /// In en, this message translates to:
  /// **'Read Registers'**
  String get readRegisters;

  /// No description provided for @readRegistersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read holding/input\nregisters'**
  String get readRegistersSubtitle;

  /// No description provided for @writeValue.
  ///
  /// In en, this message translates to:
  /// **'Write Value'**
  String get writeValue;

  /// No description provided for @writeValueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write single/multiple\nregisters'**
  String get writeValueSubtitle;

  /// No description provided for @lastValues.
  ///
  /// In en, this message translates to:
  /// **'Last Values'**
  String get lastValues;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All >'**
  String get viewAll;

  /// No description provided for @openLog.
  ///
  /// In en, this message translates to:
  /// **'Open Log'**
  String get openLog;

  /// No description provided for @openLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View communication log'**
  String get openLogSubtitle;

  /// No description provided for @tabCoils.
  ///
  /// In en, this message translates to:
  /// **'Coils'**
  String get tabCoils;

  /// No description provided for @colAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get colAddress;

  /// No description provided for @colValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get colValue;

  /// No description provided for @colType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get colType;

  /// No description provided for @colComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get colComment;

  /// No description provided for @btnRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get btnRead;

  /// No description provided for @labelStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get labelStart;

  /// No description provided for @labelCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get labelCount;

  /// No description provided for @labelAutoRefresh.
  ///
  /// In en, this message translates to:
  /// **'Auto refresh'**
  String get labelAutoRefresh;

  /// No description provided for @registersShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing {start} – {end}'**
  String registersShowing(int start, int end);

  /// No description provided for @registersLastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last update: {time}'**
  String registersLastUpdate(String time);

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterTx.
  ///
  /// In en, this message translates to:
  /// **'TX'**
  String get filterTx;

  /// No description provided for @filterRx.
  ///
  /// In en, this message translates to:
  /// **'RX'**
  String get filterRx;

  /// No description provided for @filterErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get filterErrors;

  /// No description provided for @labelAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Auto scroll'**
  String get labelAutoScroll;

  /// No description provided for @colTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get colTime;

  /// No description provided for @colDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get colDirection;

  /// No description provided for @colFunction.
  ///
  /// In en, this message translates to:
  /// **'Function'**
  String get colFunction;

  /// No description provided for @logMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages: {count}'**
  String logMessages(int count);

  /// No description provided for @logClearOnDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Clear on disconnect'**
  String get logClearOnDisconnect;

  /// No description provided for @connectToDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect to device'**
  String get connectToDevice;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connectionType.
  ///
  /// In en, this message translates to:
  /// **'Connection type'**
  String get connectionType;

  /// No description provided for @connectTypeTcp.
  ///
  /// In en, this message translates to:
  /// **'Modbus TCP'**
  String get connectTypeTcp;

  /// No description provided for @connectTypeTcpSub.
  ///
  /// In en, this message translates to:
  /// **'Standard Modbus TCP'**
  String get connectTypeTcpSub;

  /// No description provided for @connectTypeRtu.
  ///
  /// In en, this message translates to:
  /// **'RTU over TCP/IP'**
  String get connectTypeRtu;

  /// No description provided for @connectTypeRtuSub.
  ///
  /// In en, this message translates to:
  /// **'Modbus RTU over TCP'**
  String get connectTypeRtuSub;

  /// No description provided for @labelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get labelName;

  /// No description provided for @labelHost.
  ///
  /// In en, this message translates to:
  /// **'Host / IP address'**
  String get labelHost;

  /// No description provided for @labelPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get labelPort;

  /// No description provided for @labelUnitIdField.
  ///
  /// In en, this message translates to:
  /// **'Unit ID (Slave ID)'**
  String get labelUnitIdField;

  /// No description provided for @labelTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout'**
  String get labelTimeout;

  /// No description provided for @labelReconnectDelay.
  ///
  /// In en, this message translates to:
  /// **'Reconnect delay'**
  String get labelReconnectDelay;

  /// No description provided for @labelNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get labelNotes;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Add any notes about this connection'**
  String get notesHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
