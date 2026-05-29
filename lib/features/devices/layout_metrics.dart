import 'package:flutter/material.dart';

/// Painted height of a single line of text for [style] under [scaler].
///
/// Used by the devices screens to size list rows from the active theme's real
/// font metrics, so "how many rows fit" math stays correct across font sizes
/// (accessibility text scaling), themes, and locales — not just one device.
double measuredLineHeight(TextStyle? style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: 'Ag', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  return painter.height;
}
