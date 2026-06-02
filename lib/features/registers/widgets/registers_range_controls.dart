import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../../models/register_list.dart';
import '../../../widgets/app_switch.dart';
import 'max_count_formatter.dart';

class RegistersRangeControls extends StatelessWidget {
  final TextEditingController startAddrCtrl;
  final TextEditingController countCtrl;
  final int maxCount;
  final int minStartAddress;
  final bool autoRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;
  final TextEditingController refreshIntervalCtrl;
  final VoidCallback onRefreshIntervalCommitted;
  final FocusNode? startAddrFocus;
  final FocusNode? countFocus;
  final FocusNode? refreshIntervalFocus;

  const RegistersRangeControls({
    super.key,
    required this.startAddrCtrl,
    required this.countCtrl,
    required this.maxCount,
    this.minStartAddress = 0,
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
    required this.refreshIntervalCtrl,
    required this.onRefreshIntervalCommitted,
    this.startAddrFocus,
    this.countFocus,
    this.refreshIntervalFocus,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        children: [
          Text(
            l10n.labelStart,
            style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 58,
            child: TextField(
              controller: startAddrCtrl,
              focusNode: startAddrFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                MaxCountFormatter(max: null, min: minStartAddress),
              ],
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.labelCount,
            style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 42,
            child: TextField(
              controller: countCtrl,
              focusNode: countFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                MaxCountFormatter(max: maxCount, min: 1),
              ],
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const Spacer(),
          Tooltip(
            message: l10n.labelAutoRefresh,
            child: Icon(
              Icons.update_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          AppSwitch(value: autoRefresh, onChanged: onAutoRefreshChanged),
          const SizedBox(width: 2),
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                onRefreshIntervalCommitted();
              }
            },
            child: SizedBox(
              width: 58,
              child: TextField(
                controller: refreshIntervalCtrl,
                focusNode: refreshIntervalFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  MaxCountFormatter(max: kMaxRegisterRefreshIntervalMs),
                ],
                style: tt.bodyMedium,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                ),
                onEditingComplete: () {
                  onRefreshIntervalCommitted();
                  FocusScope.of(context).unfocus();
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text('ms', style: tt.bodyMedium),
        ],
      ),
    );
  }
}
