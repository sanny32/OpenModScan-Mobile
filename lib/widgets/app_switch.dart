import 'package:flutter/material.dart';

/// A compact [Switch] with a single, app-wide size so every toggle looks the
/// same (replacing the ad-hoc `Transform.scale`/`FittedBox` wrappers that used
/// to differ per call site).
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final WidgetStateProperty<Color?>? thumbColor;
  final WidgetStateProperty<Color?>? trackColor;
  final Alignment alignment;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.thumbColor,
    this.trackColor,
    this.alignment = Alignment.center,
  });

  static const double _scale = 0.8;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: _scale,
      alignment: alignment,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbColor: thumbColor,
        trackColor: trackColor,
      ),
    );
  }
}
