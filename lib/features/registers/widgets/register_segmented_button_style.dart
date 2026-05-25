import 'package:flutter/material.dart';

ButtonStyle registerSegmentedButtonStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return ButtonStyle(
    textStyle: WidgetStatePropertyAll(tt.bodyMedium),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return cs.primary;
      return cs.surfaceContainerHighest;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return cs.onPrimary;
      return cs.onSurface;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return cs.onPrimary;
      return cs.onSurface;
    }),
    side: WidgetStatePropertyAll(
      BorderSide(color: Theme.of(context).dividerColor),
    ),
  );
}
