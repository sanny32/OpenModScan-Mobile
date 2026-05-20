import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/device_info.dart';
import '../models/log_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_info_bar.dart';
import '../widgets/connection_status_chip.dart';

enum _LogFilter { all, tx, rx, errors }

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  _LogFilter _filter = _LogFilter.all;
  bool _autoScroll = true;
  bool _clearOnDisconnect = false;

  List<LogEntry> get _filtered {
    switch (_filter) {
      case _LogFilter.all:
        return mockLogEntries;
      case _LogFilter.tx:
        return mockLogEntries
            .where((e) => e.direction == LogDirection.tx)
            .toList();
      case _LogFilter.rx:
        return mockLogEntries
            .where((e) => e.direction == LogDirection.rx)
            .toList();
      case _LogFilter.errors:
        return mockLogEntries
            .where((e) => e.type == LogEntryType.error)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    const device = mockDevice;
    final entries = _filtered;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final dividerColor =
        Theme.of(context).dividerTheme.color ?? cs.outline;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.navLog, style: tt.titleMedium),
            const SizedBox(height: 2),
            ConnectionStatusChip(connected: device.connected),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.delete_outline), onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          ConnectionInfoBar(device: device),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _FilterBtn(
                    label: l10n.filterAll,
                    selected: _filter == _LogFilter.all,
                    onTap: () => setState(() => _filter = _LogFilter.all)),
                const SizedBox(width: 6),
                _FilterBtn(
                    label: l10n.filterTx,
                    icon: Icons.arrow_upward,
                    color: appColors.txColor,
                    selected: _filter == _LogFilter.tx,
                    onTap: () => setState(() => _filter = _LogFilter.tx)),
                const SizedBox(width: 6),
                _FilterBtn(
                    label: l10n.filterRx,
                    icon: Icons.arrow_downward,
                    color: appColors.rxColor,
                    selected: _filter == _LogFilter.rx,
                    onTap: () => setState(() => _filter = _LogFilter.rx)),
                const SizedBox(width: 6),
                _FilterBtn(
                    label: l10n.filterErrors,
                    icon: Icons.warning_amber_outlined,
                    color: appColors.warningColor,
                    selected: _filter == _LogFilter.errors,
                    onTap: () =>
                        setState(() => _filter = _LogFilter.errors)),
                const Spacer(),
                Text(l10n.labelAutoScroll,
                    style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _autoScroll,
                    onChanged: (v) => setState(() => _autoScroll = v),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: cs.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                    width: 90,
                    child: Text(l10n.colTime,
                        style: tt.bodySmall!
                            .copyWith(color: cs.onSurfaceVariant))),
                SizedBox(
                    width: 58,
                    child: Text(l10n.colDirection,
                        style: tt.bodySmall!
                            .copyWith(color: cs.onSurfaceVariant))),
                Expanded(
                    child: Text(l10n.colFunction,
                        style: tt.bodySmall!
                            .copyWith(color: cs.onSurfaceVariant))),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),
          Expanded(
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: dividerColor),
              itemBuilder: (context, i) => _LogRow(entry: entries[i]),
            ),
          ),
          Container(
            color: cs.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.logMessages(128),
                    style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
                Row(
                  children: [
                    Text(l10n.logClearOnDisconnect,
                        style: tt.bodySmall!
                            .copyWith(color: cs.onSurfaceVariant)),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: _clearOnDisconnect,
                        onChanged: (v) =>
                            setState(() => _clearOnDisconnect = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterBtn({
    required this.label,
    this.icon,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final effectiveColor = color ?? cs.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? effectiveColor : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? effectiveColor : cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant),
              const SizedBox(width: 3),
            ],
            Text(label,
                style: tt.bodyMedium!.copyWith(
                    color: selected ? cs.onPrimary : cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final LogEntry entry;
  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final isError = entry.type == LogEntryType.error;
    final isTx = entry.direction == LogDirection.tx;

    final dirColor = isError
        ? cs.error
        : isTx
            ? appColors.txColor
            : appColors.rxColor;

    final funcColor = isError
        ? cs.error
        : isTx
            ? appColors.txColor
            : appColors.rxColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(entry.time,
                style: tt.labelSmall!.copyWith(color: cs.onSurfaceVariant)),
          ),
          SizedBox(
            width: 58,
            child: entry.direction == null
                ? const SizedBox()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isTx ? l10n.filterTx : l10n.filterRx,
                          style: tt.bodySmall!.copyWith(
                              color: dirColor,
                              fontWeight: FontWeight.bold)),
                      Icon(
                          isTx
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 12,
                          color: dirColor),
                    ],
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.function,
                    style: tt.bodyMedium!.copyWith(
                        color: funcColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(entry.data,
                    style: tt.labelSmall!.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
