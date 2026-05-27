import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/device_info.dart';
import '../../../models/discovered_device.dart';
import '../../../runtime/runtime_ports.dart';
import '../../../theme/app_theme.dart';

class ScanPanel extends StatelessWidget {
  final ScannerStateView state;
  final double progress;
  final int total;
  final int foundCount;
  final List<DiscoveredDevice> discoveredDevices;
  final String? cidr;
  final DateTime? startedAt;
  final ProtocolType? protocol;
  final VoidCallback onTap;
  final VoidCallback onStop;
  final void Function(DiscoveredDevice) onConnect;

  const ScanPanel({
    super.key,
    required this.state,
    required this.progress,
    required this.total,
    required this.foundCount,
    required this.discoveredDevices,
    required this.cidr,
    required this.startedAt,
    required this.protocol,
    required this.onTap,
    required this.onStop,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: switch (state) {
        ScannerStateView.scanning => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScanningCard(
              progress: progress,
              total: total,
              foundCount: foundCount,
              discoveredDevices: discoveredDevices,
              cidr: cidr,
              startedAt: startedAt,
              protocol: protocol,
              onConnect: onConnect,
              onStop: onStop,
            ),
          ],
        ),
        ScannerStateView.done => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScanningCard(
              progress: total == 0 ? 0 : 1,
              total: total,
              foundCount: foundCount,
              discoveredDevices: discoveredDevices,
              cidr: cidr,
              startedAt: startedAt,
              protocol: protocol,
              completed: true,
              onConnect: onConnect,
              onRestart: onTap,
            ),
          ],
        ),
        ScannerStateView.idle => _ScanNetworkButton(onStart: onTap),
      },
    );
  }
}

class _ScanActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _ScanActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        side: BorderSide(color: color),
        foregroundColor: color,
        textStyle: Theme.of(context).textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ScanNetworkButton extends StatelessWidget {
  final VoidCallback onStart;

  const _ScanNetworkButton({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return OutlinedButton.icon(
      icon: const Icon(Icons.radar_outlined, size: 18),
      label: Text(l10n.devicesScanNetwork),
      onPressed: onStart,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: BorderSide(color: cs.primary),
        foregroundColor: cs.primary,
        textStyle: tt.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ScanningCard extends StatelessWidget {
  final double progress;
  final int total;
  final int foundCount;
  final List<DiscoveredDevice> discoveredDevices;
  final String? cidr;
  final DateTime? startedAt;
  final ProtocolType? protocol;
  final bool completed;
  final void Function(DiscoveredDevice) onConnect;
  final VoidCallback? onStop;
  final VoidCallback? onRestart;

  const _ScanningCard({
    required this.progress,
    required this.total,
    required this.foundCount,
    required this.discoveredDevices,
    required this.cidr,
    required this.startedAt,
    required this.protocol,
    required this.onConnect,
    this.completed = false,
    this.onStop,
    this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>();
    final l10n = context.l10n;
    final pct = total == 0 ? 0 : (progress * 100).clamp(0, 100).round();
    final accent = completed
        ? (appColors?.connectedColor ?? Colors.green)
        : cs.primary;
    final protocolName = _protocolLabel(l10n, protocol);
    final visibleDiscoveredDevices = discoveredDevices.take(2).toList();
    final hiddenDiscoveredCount =
        discoveredDevices.length - visibleDiscoveredDevices.length;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    completed
                        ? Icons.check_circle_outline
                        : Icons.travel_explore,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        completed
                            ? l10n.devicesScanCompletedTitle
                            : l10n.devicesScanningTitle,
                        style: tt.titleMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        completed
                            ? l10n.devicesFoundCount(foundCount)
                            : l10n.devicesScanningProtocolSubtitle(
                                protocolName,
                              ),
                        style: tt.bodyMedium!.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: total == 0 ? null : progress,
                      color: accent,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '$pct%',
                  style: tt.bodyMedium!.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final subnet = _SubnetLabel(text: cidr);
                final times = _ScanTimeLabels(
                  startedAt: startedAt,
                  completed: completed,
                  foundCount: foundCount,
                );
                if (constraints.maxWidth < 420) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [subnet, const SizedBox(height: 8), times],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: subnet),
                    const SizedBox(width: 8),
                    times,
                  ],
                );
              },
            ),
            if (discoveredDevices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Theme.of(context).dividerTheme.color),
              for (final device in visibleDiscoveredDevices)
                _DiscoveredScanRow(device: device, onConnect: onConnect),
              if (hiddenDiscoveredCount > 0)
                _DiscoveredDevicesFooter(
                  hiddenCount: hiddenDiscoveredCount,
                  totalCount: discoveredDevices.length,
                  devices: discoveredDevices,
                  onConnect: onConnect,
                ),
            ],
            if (!completed && onStop != null) ...[
              const SizedBox(height: 12),
              _ScanActionButton(
                icon: Icons.stop_circle_outlined,
                label: l10n.devicesScanStop,
                onPressed: onStop!,
                color: cs.primary,
              ),
            ],
            if (completed && onRestart != null) ...[
              const SizedBox(height: 12),
              _ScanActionButton(
                icon: Icons.radar_outlined,
                label: l10n.devicesScanNetwork,
                onPressed: onRestart!,
                color: cs.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _protocolLabel(AppLocalizations l10n, ProtocolType? protocol) {
    return switch (protocol) {
      ProtocolType.modbusRtuIp => l10n.connectTypeRtu,
      ProtocolType.modbusTcp || null => l10n.connectTypeTcp,
    };
  }
}

class _DiscoveredScanRow extends StatelessWidget {
  final DiscoveredDevice device;
  final void Function(DiscoveredDevice) onConnect;

  const _DiscoveredScanRow({required this.device, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(Icons.wifi, color: cs.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.address,
                      style: tt.titleSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.protocolAndUnitId(
                        device.protocolName,
                        device.unitId,
                      ),
                      style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => onConnect(device),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.55)),
                  foregroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  minimumSize: const Size(96, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: tt.labelLarge,
                ),
                child: Text(l10n.devicesConnect),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Theme.of(context).dividerTheme.color),
      ],
    );
  }
}

class _DiscoveredDevicesFooter extends StatelessWidget {
  final int hiddenCount;
  final int totalCount;
  final List<DiscoveredDevice> devices;
  final void Function(DiscoveredDevice) onConnect;

  const _DiscoveredDevicesFooter({
    required this.hiddenCount,
    required this.totalCount,
    required this.devices,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final style = tt.labelLarge!.copyWith(
      color: cs.primary,
      fontWeight: FontWeight.w700,
    );

    return InkWell(
      onTap: () => _showDiscoveredDevices(context),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Text(l10n.devicesMoreCount(hiddenCount), style: style),
            const Spacer(),
            Text(l10n.devicesShowAllCount(totalCount), style: style),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: cs.primary, size: 18),
          ],
        ),
      ),
    );
  }

  void _showDiscoveredDevices(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final device in devices)
              _DiscoveredScanRow(
                device: device,
                onConnect: (device) {
                  Navigator.of(sheetContext).pop();
                  onConnect(device);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SubnetLabel extends StatelessWidget {
  final String? text;

  const _SubnetLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text ?? l10n.devicesScanSubnetUnavailable,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _ScanTimeLabels extends StatelessWidget {
  final DateTime? startedAt;
  final bool completed;
  final int foundCount;

  const _ScanTimeLabels({
    required this.startedAt,
    required this.completed,
    required this.foundCount,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final style = tt.bodySmall!.copyWith(color: cs.onSurfaceVariant);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          completed
              ? l10n.devicesScanDuration(_formatElapsed(startedAt))
              : l10n.devicesScanElapsed(_formatElapsed(startedAt)),
          style: style,
        ),
        const SizedBox(width: 16),
        Text(l10n.devicesScanFound(foundCount), style: style),
      ],
    );
  }

  String _formatElapsed(DateTime? startedAt) {
    if (startedAt == null) return '00:00:00';
    final elapsed = DateTime.now().difference(startedAt);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  }
}
