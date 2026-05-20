import 'package:flutter/widgets.dart';
import '../gen/l10n/app_localizations.dart';

export '../gen/l10n/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
