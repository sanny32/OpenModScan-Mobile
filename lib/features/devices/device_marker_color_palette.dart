import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/device_info.dart';

extension DeviceMarkerColorPalette on DeviceMarkerColor {
  Color resolve(ColorScheme colorScheme) {
    final dark = colorScheme.brightness == Brightness.dark;
    return switch (this) {
      DeviceMarkerColor.blue => colorScheme.primary,
      DeviceMarkerColor.green =>
        dark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
      DeviceMarkerColor.amber =>
        dark ? const Color(0xFFFFC107) : const Color(0xFFFFA000),
      DeviceMarkerColor.red =>
        dark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F),
      DeviceMarkerColor.purple =>
        dark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2),
      DeviceMarkerColor.teal =>
        dark ? const Color(0xFF4DB6AC) : const Color(0xFF00897B),
      DeviceMarkerColor.gray =>
        dark ? const Color(0xFFB0BEC5) : const Color(0xFF757575),
    };
  }

  String label(AppLocalizations l10n) => switch (this) {
    DeviceMarkerColor.blue => l10n.deviceMarkerColorBlue,
    DeviceMarkerColor.green => l10n.deviceMarkerColorGreen,
    DeviceMarkerColor.amber => l10n.deviceMarkerColorAmber,
    DeviceMarkerColor.red => l10n.deviceMarkerColorRed,
    DeviceMarkerColor.purple => l10n.deviceMarkerColorPurple,
    DeviceMarkerColor.teal => l10n.deviceMarkerColorTeal,
    DeviceMarkerColor.gray => l10n.deviceMarkerColorGray,
  };
}
