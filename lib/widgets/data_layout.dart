import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../theme/app_dimens.dart';
import 'segmented_button_style.dart';

/// Tappable "MSRF · Direct ▾" chip shown in a section header. Opens the data
/// layout bottom sheet so the register/byte order can be changed in place.
class DataLayoutChip extends StatelessWidget {
  final String registerOrder;
  final String byteOrder;
  final VoidCallback onTap;

  const DataLayoutChip({
    super.key,
    required this.registerOrder,
    required this.byteOrder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.smAll,
      child: InkWell(
        borderRadius: AppRadii.smAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                '$registerOrder · $byteOrder',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a bottom sheet that lets the user pick the register and byte order.
/// Changes are reported immediately through [onRegisterOrder]/[onByteOrder] so
/// the screen behind the sheet can update live.
Future<void> showDataLayoutSheet(
  BuildContext context, {
  required String registerOrder,
  required String byteOrder,
  required ValueChanged<String> onRegisterOrder,
  required ValueChanged<String> onByteOrder,
}) {
  var currentRegisterOrder = registerOrder;
  var currentByteOrder = byteOrder;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      final l10n = ctx.l10n;

      return StatefulBuilder(
        builder: (ctx, setInnerState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data layout',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _LayoutChoiceSection(
                  label: l10n.labelRegisterOrder,
                  icon: Icons.swap_vert_rounded,
                  options: AppSettings.registerOrders,
                  value: currentRegisterOrder,
                  onSelected: (value) {
                    onRegisterOrder(value);
                    setInnerState(() => currentRegisterOrder = value);
                  },
                ),
                const SizedBox(height: 14),
                _LayoutChoiceSection(
                  label: l10n.labelByteOrder,
                  icon: Icons.swap_horiz_rounded,
                  options: AppSettings.byteOrders,
                  value: currentByteOrder,
                  onSelected: (value) {
                    onByteOrder(value);
                    setInnerState(() => currentByteOrder = value);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _LayoutChoiceSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> options;
  final String value;
  final ValueChanged<String> onSelected;

  const _LayoutChoiceSection({
    required this.label,
    required this.icon,
    required this.options,
    required this.value,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: options
              .map(
                (option) =>
                    ButtonSegment<String>(value: option, label: Text(option)),
              )
              .toList(),
          selected: {value},
          onSelectionChanged: (selection) => onSelected(selection.first),
          showSelectedIcon: false,
          style: appSegmentedButtonStyle(context),
        ),
      ],
    );
  }
}
