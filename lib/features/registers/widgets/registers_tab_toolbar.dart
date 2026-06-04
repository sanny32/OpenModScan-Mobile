import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../widgets/segmented_button_style.dart';

class RegistersTabToolbar extends StatelessWidget {
  final Widget? leading;
  final List<ButtonSegment<String>> segments;
  final String selectedSegment;
  final ValueChanged<String> onSegmentChanged;
  final bool canRead;
  final bool supportsRead;
  final bool readInProgress;
  final VoidCallback onRead;

  const RegistersTabToolbar({
    super.key,
    this.leading,
    required this.segments,
    required this.selectedSegment,
    required this.onSegmentChanged,
    required this.canRead,
    required this.supportsRead,
    required this.readInProgress,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;

    final segmented = SegmentedButton<String>(
      segments: segments,
      selected: {selectedSegment},
      onSelectionChanged: (selection) => onSegmentChanged(selection.first),
      style: appSegmentedButtonStyle(context),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          if (leading != null) ...[
            Expanded(child: leading!),
            const SizedBox(width: 8),
            segmented,
          ] else ...[
            segmented,
            const Spacer(),
          ],
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: readInProgress
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 15),
            label: Text(l10n.btnRead),
            onPressed: canRead && supportsRead && !readInProgress
                ? onRead
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              textStyle: tt.bodyMedium,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
