import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/device_info.dart';
import '../../models/log_entry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/connection_info_bar.dart';
import '../../widgets/connection_status_chip.dart';
import '../../widgets/error_feedback.dart';
import 'traffic_controller.dart';

class TrafficScreen extends StatefulWidget {
  final TrafficController controller;

  const TrafficScreen({super.key, required this.controller});

  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  bool _connectionBusy = false;

  DeviceInfo? get _selectedDevice => widget.controller.selectedDevice;

  void _clearTraffic() {
    // TODO: wire up traffic log clearing once TrafficLogSource exposes it.
  }

  Future<void> _toggleSelectedConnection() async {
    final device = _selectedDevice;
    if (device == null || _connectionBusy) return;

    setState(() => _connectionBusy = true);
    try {
      await widget.controller.toggleConnection(device);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _connectionBusy = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.controller.entries;
    final selected = _selectedDevice;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final dividerColor = Theme.of(context).dividerTheme.color ?? cs.outline;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected?.name ?? l10n.navLog, style: tt.titleMedium),
            const SizedBox(height: 2),
            ConnectionStatusChip(
              connected:
                  selected != null && widget.controller.isConnected(selected),
            ),
          ],
        ),
        actions: [
          if (selected != null)
            IconButton(
              icon: Icon(
                Icons.power_settings_new,
                color: widget.controller.isConnected(selected)
                    ? appColors.connectedColor
                    : cs.onSurfaceVariant,
              ),
              tooltip: widget.controller.isConnected(selected)
                  ? l10n.disconnect
                  : l10n.connect,
              onPressed: _connectionBusy ? null : _toggleSelectedConnection,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: widget.controller.selectDevice,
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                onTap: _clearTraffic,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(l10n.logClearTraffic),
                  ],
                ),
              ),
              if (widget.controller.connectedDevices.isNotEmpty)
                const PopupMenuDivider(),
              ...widget.controller.connectedDevices.map(
                (d) => PopupMenuItem<String>(
                  value: d.id,
                  child: Row(
                    children: [
                      Icon(Icons.memory, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Text(d.name),
                      if (d.id == selected?.id) ...[
                        const Spacer(),
                        Icon(Icons.check, size: 16, color: cs.primary),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (selected != null) ConnectionInfoBar(device: selected),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _FilterBtn(
                  label: l10n.filterAll,
                  selected: widget.controller.filter == TrafficFilter.all,
                  onTap: () => widget.controller.setFilter(TrafficFilter.all),
                ),
                const SizedBox(width: 6),
                _FilterBtn(
                  label: l10n.filterTx,
                  icon: Icons.arrow_upward,
                  color: appColors.txColor,
                  selected: widget.controller.filter == TrafficFilter.tx,
                  onTap: () => widget.controller.setFilter(TrafficFilter.tx),
                ),
                const SizedBox(width: 6),
                _FilterBtn(
                  label: l10n.filterRx,
                  icon: Icons.arrow_downward,
                  color: appColors.rxColor,
                  selected: widget.controller.filter == TrafficFilter.rx,
                  onTap: () => widget.controller.setFilter(TrafficFilter.rx),
                ),
                const SizedBox(width: 6),
                _FilterBtn(
                  label: l10n.filterErrors,
                  icon: Icons.warning_amber_outlined,
                  color: appColors.warningColor,
                  selected: widget.controller.filter == TrafficFilter.errors,
                  onTap: () =>
                      widget.controller.setFilter(TrafficFilter.errors),
                ),
                const Spacer(),
                Text(
                  l10n.labelAutoScroll,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: widget.controller.autoScroll,
                    onChanged: widget.controller.setAutoScroll,
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
                  child: Text(
                    l10n.colTime,
                    style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                    l10n.colDirection,
                    style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.colFunction,
                    style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
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
                Text(
                  l10n.logMessages(128),
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
                Row(
                  children: [
                    Text(
                      l10n.logClearOnDisconnect,
                      style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: widget.controller.clearOnDisconnect,
                        onChanged: widget.controller.setClearOnDisconnect,
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
          border: Border.all(color: selected ? effectiveColor : cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: tt.bodyMedium!.copyWith(
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
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
            child: Text(
              entry.time,
              style: tt.labelSmall!.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          SizedBox(
            width: 58,
            child: entry.direction == null
                ? const SizedBox()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isTx ? l10n.filterTx : l10n.filterRx,
                        style: tt.bodySmall!.copyWith(
                          color: dirColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        isTx ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: dirColor,
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.function,
                  style: tt.bodyMedium!.copyWith(
                    color: funcColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.data,
                  style: tt.labelSmall!.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
