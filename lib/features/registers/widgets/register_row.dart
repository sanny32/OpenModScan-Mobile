import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../../models/app_settings.dart';
import '../../../models/register_entry.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/modbus_format.dart';
import '../../../widgets/type_badge.dart';
import '../register_detail_screen.dart';

class RegisterRow extends StatelessWidget {
  final RegisterEntry entry;
  final bool canWrite;
  final void Function(int address, String typeName, String? comment)?
  onEntryChanged;
  final void Function(int address, String value)? onValueWritten;

  const RegisterRow({
    super.key,
    required this.entry,
    required this.canWrite,
    this.onEntryChanged,
    this.onValueWritten,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final valueColor = _valueColor(context, entry.valueState);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterDetailScreen(
            entry: entry,
            canWrite: canWrite,
            onSaved: onEntryChanged != null
                ? (type, comment) =>
                      onEntryChanged!(entry.address, type, comment)
                : null,
            onValueWritten: onValueWritten != null
                ? (v) => onValueWritten!(entry.address, v)
                : null,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${entry.address}', style: tt.bodyLarge),
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        AppSettings.instance.showTypeBadgesNotifier,
                    builder: (_, showBadges, _) => showBadges
                        ? TypeBadge(type: entry.typeName)
                        : Text(
                            entry.typeName,
                            style: tt.bodySmall!.copyWith(
                              color: appColors.typeColor,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                entry.comment ?? '',
                style: tt.bodyMedium!.copyWith(color: cs.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: canWrite
                  ? () => _showWriteRegisterDialog(context, entry)
                  : null,
              borderRadius: BorderRadius.circular(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.displayValue ?? entry.value,
                    style: tt.bodyLarge!.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        AppSettings.instance.showLastValuesNotifier,
                    builder: (_, showLastValues, _) {
                      if (!showLastValues || entry.previousValue == null) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        _formatPreviousValue(entry),
                        style: tt.bodySmall!.copyWith(
                          color: appColors.previousValueColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

Future<void> _showWriteRegisterDialog(
  BuildContext context,
  RegisterEntry entry,
) async {
  final l10n = context.l10n;
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final appColors = Theme.of(context).extension<AppColors>()!;
  final ctrl = TextEditingController(text: entry.value);
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setInnerState) => AlertDialog(
        title: Text(l10n.writeRegisterTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${l10n.colAddress}: ',
                  style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  '${entry.address}',
                  style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${l10n.colValue}: ',
                  style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  entry.value,
                  style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                ),
                if (entry.previousValue != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '← ${entry.previousValue}',
                    style: tt.bodySmall!.copyWith(
                      color: appColors.previousValueColor,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.labelNewValue,
                errorText: error,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                if (error != null) setInnerState(() => error = null);
              },
              onSubmitted: (_) {
                final raw = int.tryParse(ctrl.text);
                if (raw == null || raw < 0 || raw > 65535) {
                  setInnerState(() => error = l10n.writeValueRange);
                  return;
                }
                // TODO: perform actual Modbus write
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final raw = int.tryParse(ctrl.text);
              if (raw == null || raw < 0 || raw > 65535) {
                setInnerState(() => error = l10n.writeValueRange);
                return;
              }
              // TODO: perform actual Modbus write
              Navigator.pop(ctx);
            },
            child: Text(l10n.btnWrite),
          ),
        ],
      ),
    ),
  );
}

Color _valueColor(BuildContext context, RegisterValueState state) {
  final appColors = Theme.of(context).extension<AppColors>()!;
  return switch (state) {
    RegisterValueState.received => appColors.valueColor,
    RegisterValueState.unavailable => appColors.unavailableValueColor,
    RegisterValueState.exception => appColors.exceptionValueColor,
  };
}

String _formatPreviousValue(RegisterEntry entry) {
  final raw = entry.previousValue;
  if (raw == null) return '';
  final rawInt = int.tryParse(raw);
  if (rawInt == null) return raw;
  return computeDisplayValue(entry.address, entry.typeName, {
    entry.address: rawInt,
  });
}
