import 'package:flutter/widgets.dart';

/// Corner-radius tokens. A single scale so related elements round the same way
/// instead of each call site picking an ad-hoc value:
///   xs   — small inner chips, inline value tiles
///   sm   — badges, compact chips
///   md   — inputs, buttons, segmented controls
///   lg   — cards / surfaces
///   xl   — large feature tiles (logo, icon panels)
///   full — pills and extended FABs (stadium shape)
abstract final class AppRadii {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 20;
  static const double full = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}
