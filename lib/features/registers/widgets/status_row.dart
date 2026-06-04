import 'package:flutter/material.dart';

import '../../../models/register_entry.dart';
import '../../../models/status_entry.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_switch.dart';
import '../status_detail_screen.dart';

class StatusRow extends StatelessWidget {
  final StatusEntry entry;
  final RegisterValueState valueState;
  final bool canWrite;
  final ValueChanged<bool>? onChanged;
  final void Function(int address, String? comment)? onEntryChanged;
  final Future<bool?> Function(bool value)? onDetailValueWritten;

  const StatusRow({
    super.key,
    required this.entry,
    required this.valueState,
    required this.canWrite,
    required this.onChanged,
    required this.onEntryChanged,
    this.onDetailValueWritten,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final exceptionColor = appColors.exceptionValueColor;
    final isException = valueState == RegisterValueState.exception;
    final referenceAddress = entry.displayAddress ?? entry.address;

    void openDetail() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatusDetailScreen(
            address: referenceAddress,
            initialValue: entry.value,
            comment: entry.comment,
            canWrite: canWrite,
            timestamp: entry.timestamp,
            date: entry.date,
            onSaved: onEntryChanged == null
                ? null
                : (comment) => onEntryChanged!(entry.address, comment),
            onValueWritten: onDetailValueWritten,
          ),
        ),
      );
    }

    final statusSwitch = AppSwitch(
      value: entry.value,
      onChanged: canWrite ? onChanged : null,
      alignment: Alignment.centerRight,
      thumbColor: isException ? WidgetStatePropertyAll(exceptionColor) : null,
      trackColor: isException
          ? WidgetStatePropertyAll(exceptionColor.withAlpha(77))
          : null,
    );

    return InkWell(
      onTap: openDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                referenceAddress.toString().padLeft(5, '0'),
                style: tt.bodyLarge,
              ),
            ),
            Expanded(
              child: Text(
                entry.comment,
                style: tt.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Align(alignment: Alignment.centerRight, child: statusSwitch),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
