import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../models/log_entry.dart';
import '../../theme/app_theme.dart';
import '../../utils/modbus_traffic_format.dart';

/// Full breakdown of a single captured Modbus frame: MBAP header, decoded PDU
/// fields and the raw hex dump. Opened by tapping a row on the traffic screen.
class TrafficDetailScreen extends StatelessWidget {
  final LogEntry entry;

  const TrafficDetailScreen({super.key, required this.entry});

  Uint8List get _frame => entry.frame ?? parseHexBytes(entry.data.split('\n').first);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final frame = _frame;
    final hasFrame = frame.isNotEmpty;
    final info = hasFrame
        ? describeModbusFrame(frame, entry.direction ?? LogDirection.tx)
        : null;

    final isTx = entry.direction == LogDirection.tx;
    final directionColor = entry.type == LogEntryType.error
        ? cs.error
        : isTx
        ? appColors.txColor
        : appColors.rxColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(info?.functionLabel ?? entry.function, style: tt.titleMedium),
        actions: [
          if (hasFrame)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: l10n.trafficCopyHex,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: formatHexBytes(frame)),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.trafficHexCopied)),
                  );
                }
              },
            ),
        ],
      ),
      body: !hasFrame
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.trafficNoFrame,
                  style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _DirectionChip(
                  label: entry.direction == null
                      ? entry.function
                      : (isTx ? l10n.filterTx : l10n.filterRx),
                  icon: entry.direction == null
                      ? null
                      : (isTx ? Icons.arrow_upward : Icons.arrow_downward),
                  color: directionColor,
                ),
                const SizedBox(height: 16),
                _SectionHeader(l10n.trafficMbapHeader),
                const SizedBox(height: 8),
                _Card(
                  child: Column(
                    children: [
                      _InfoRow(l10n.trafficTransactionId, _hex16(info!.transactionId)),
                      _InfoRow(l10n.trafficProtocolId, _hex16(info.protocolId)),
                      _InfoRow(l10n.trafficLength, '${info.length ?? '—'}'),
                      _InfoRow(l10n.trafficUnitId, '${info.unitId ?? '—'}', last: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionHeader(l10n.trafficPdu),
                const SizedBox(height: 8),
                _Card(
                  child: Column(
                    children: [
                      _InfoRow(l10n.trafficFunctionCode, _functionCodeText(info)),
                      _InfoRow(l10n.colDirection, isTx ? l10n.filterTx : l10n.filterRx),
                      _InfoRow(l10n.colTime, entry.time, last: true),
                    ],
                  ),
                ),
                if (info.fields.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(l10n.trafficDecoded),
                  const SizedBox(height: 8),
                  _Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < info.fields.length; i++)
                          _InfoRow(
                            info.fields[i].label,
                            info.fields[i].value,
                            valueColor: info.isException ? cs.error : null,
                            last: i == info.fields.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _SectionHeader(l10n.trafficRawFrame),
                const SizedBox(height: 8),
                _Card(
                  child: SelectableText(
                    formatHexBytes(frame),
                    style: tt.bodyMedium!.copyWith(
                      fontFamily: 'monospace',
                      color: cs.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static String _hex16(int? value) => value == null
      ? '—'
      : '0x${value.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  static String _functionCodeText(ModbusFrameInfo info) {
    final fc = info.functionCode;
    if (fc == null) return '—';
    return '0x${fc.toRadixString(16).toUpperCase().padLeft(2, '0')}  ·  ${info.functionLabel}';
  }
}

class _DirectionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const _DirectionChip({required this.label, this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: tt.labelLarge!.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.7 : 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: isDark ? 0.16 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 1),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall!.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool last;

  const _InfoRow(this.label, this.value, {this.valueColor, this.last = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.18))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: tt.bodyMedium!.copyWith(
                color: valueColor ?? cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
