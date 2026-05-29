import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../../models/app_settings.dart';
import '../../../models/register_entry.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/modbus_format.dart';
import '../../../widgets/error_feedback.dart';
import '../../../widgets/type_badge.dart';
import '../register_detail_screen.dart';
import '../register_runtime_value.dart';

class RegisterRow extends StatelessWidget {
  final RegisterEntry entry;
  final bool canWrite;
  final int groupWordCount;
  final bool groupExpanded;
  final VoidCallback? onGroupExpansionToggled;
  final void Function(int address, String typeName, String? comment)?
  onEntryChanged;
  final Future<String?> Function(int address, String value)? onValueWritten;
  final Listenable? valuesListenable;
  final RegisterRuntimeValue? Function(int address)? liveValueAt;

  const RegisterRow({
    super.key,
    required this.entry,
    required this.canWrite,
    this.groupWordCount = 1,
    this.groupExpanded = false,
    this.onGroupExpansionToggled,
    this.onEntryChanged,
    this.onValueWritten,
    this.valuesListenable,
    this.liveValueAt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final valueColor = _valueColor(context, entry.valueState);
    final isGroup = groupWordCount > 1 && onGroupExpansionToggled != null;
    final effectiveCanWrite = canWrite && AppSettings.instance.writeEnabled;

    void openDetail() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterDetailScreen(
            entry: entry,
            canWrite: effectiveCanWrite,
            onSaved: onEntryChanged != null
                ? (type, comment) =>
                      onEntryChanged!(entry.address, type, comment)
                : null,
            onValueWritten: onValueWritten != null
                ? (v) => onValueWritten!(entry.address, v)
                : null,
            valuesListenable: valuesListenable,
            liveValueAt: liveValueAt,
          ),
        ),
      );
    }

    void showWriteDialog() {
      _showWriteRegisterDialog(context, entry, onValueWritten);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: openDetail,
          child: Padding(
            padding: EdgeInsets.fromLTRB(isGroup ? 4 : 16, 10, 16, 10),
            child: Row(
              children: [
                if (isGroup)
                  Tooltip(
                    message: groupExpanded
                        ? 'Hide raw words for ${entry.address}'
                        : 'Show raw words for ${entry.address}',
                    child: SizedBox(
                      width: 28,
                      height: 32,
                      child: InkResponse(
                        radius: 18,
                        onTap: onGroupExpansionToggled,
                        child: Icon(
                          groupExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
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
                      if (isGroup)
                        Text(
                          '$groupWordCount regs',
                          style: tt.labelSmall!.copyWith(
                            color: cs.onSurfaceVariant,
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
                  onTap: effectiveCanWrite ? showWriteDialog : null,
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
        ),
        if (isGroup && groupExpanded)
          for (var i = 0; i < groupWordCount; i++)
            _RawRegisterWordRow(
              address: entry.address + i,
              value: entry.rawWords[entry.address + i] ?? 0,
            ),
      ],
    );
  }
}

class _RawRegisterWordRow extends StatelessWidget {
  final int address;
  final int value;

  const _RawRegisterWordRow({required this.address, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(40, 6, 40, 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              '$address',
              style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              'Raw UInt16',
              style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            '$value',
            style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

Future<void> _showWriteRegisterDialog(
  BuildContext context,
  RegisterEntry entry,
  Future<String?> Function(int address, String value)? onValueWritten,
) async {
  final l10n = context.l10n;
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final appColors = Theme.of(context).extension<AppColors>()!;
  final ctrl = TextEditingController(text: entry.value);
  String? error;
  var writing = false;

  Future<void> doWrite(BuildContext ctx, StateSetter setInnerState) async {
    final raw = int.tryParse(ctrl.text);
    if (raw == null || raw < 0 || raw > 65535) {
      setInnerState(() => error = l10n.writeValueRange);
      return;
    }
    setInnerState(() => writing = true);
    try {
      await onValueWritten?.call(entry.address, ctrl.text);
      if (ctx.mounted) Navigator.pop(ctx);
    } catch (writeError) {
      if (ctx.mounted) {
        setInnerState(() => writing = false);
        showErrorSnackBar(context, writeError);
      }
    }
  }

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
                if (!writing) {
                  doWrite(ctx, setInnerState);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: writing ? null : () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: writing ? null : () => doWrite(ctx, setInnerState),
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
