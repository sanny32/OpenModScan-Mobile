import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/device_info.dart';
import '../../../models/discovered_device.dart';
import '../../../runtime/runtime_ports.dart';
import '../../../theme/app_theme.dart';
import '../devices_controller.dart';
import '../discovered_devices_screen.dart';
import '../layout_metrics.dart';

class DiscoveredDevicesPreview extends StatelessWidget {
  final List<DiscoveredDevice> discoveredDevices;
  final void Function(DiscoveredDevice) onConnect;
  final VoidCallback onShowAll;
  // When provided, fills available space with as many rows as fit.
  final double? availableHeight;

  const DiscoveredDevicesPreview({
    super.key,
    required this.discoveredDevices,
    required this.onConnect,
    required this.onShowAll,
    this.availableHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (discoveredDevices.isEmpty) return const SizedBox.shrink();

    int visibleCount;
    if (availableHeight != null) {
      // Measure a DiscoveredDeviceRow from the active theme/text scale instead
      // of hardcoding 63pt, so the row count stays correct at any font size.
      // Row = 24pt padding + title line + 2pt gap + subtitle line + 1pt divider.
      final tt = Theme.of(context).textTheme;
      final scaler = MediaQuery.textScalerOf(context);
      final rowHeight =
          24 +
          measuredLineHeight(tt.titleSmall, scaler) +
          2 +
          measuredLineHeight(tt.bodySmall, scaler) +
          1;
      // Footer is a fixed 52pt box + 8pt gap; bottom padding is 12pt.
      const footerWithGap = 60.0;
      const bottomPad = 12.0;
      final space = availableHeight! - bottomPad;
      // Can all devices fit without a footer?
      final countWithoutFooter = ((space + 1) / rowHeight).floor();
      if (countWithoutFooter >= discoveredDevices.length) {
        visibleCount = discoveredDevices.length;
      } else {
        visibleCount =
            ((space - footerWithGap) / rowHeight).floor().clamp(
              1,
              discoveredDevices.length,
            );
      }
    } else {
      visibleCount = MediaQuery.sizeOf(context).height >= 900 ? 2 : 1;
    }

    final visibleDevices = discoveredDevices.take(visibleCount).toList();
    final hiddenCount = discoveredDevices.length - visibleDevices.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < visibleDevices.length; i++) ...[
                  DiscoveredDeviceRow(
                    device: visibleDevices[i],
                    onConnect: onConnect,
                    showBottomDivider:
                        i < visibleDevices.length - 1 || hiddenCount > 0,
                  ),
                ],
              ],
            ),
          ),
          if (hiddenCount > 0) ...[
            const SizedBox(height: 8),
            _DiscoveredDevicesFooter(
              hiddenCount: hiddenCount,
              totalCount: discoveredDevices.length,
              onTap: onShowAll,
            ),
          ],
        ],
      ),
    );
  }
}

class ScanSheet extends StatefulWidget {
  final DevicesController controller;
  final bool startOnOpen;
  final Future<void> Function(DiscoveredDevice) onConnect;

  const ScanSheet({
    super.key,
    required this.controller,
    required this.startOnOpen,
    required this.onConnect,
  });

  @override
  State<ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<ScanSheet> {
  Timer? _scanTicker;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    _syncScanTicker();
    if (widget.startOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.controller.scannerState != ScannerStateView.scanning) {
          widget.controller.startScan();
        }
      });
    }
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
    _syncScanTicker();
  }

  void _syncScanTicker() {
    final scanning =
        widget.controller.scannerState == ScannerStateView.scanning;
    if (scanning && _scanTicker == null) {
      _scanTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!scanning && _scanTicker != null) {
      _scanTicker?.cancel();
      _scanTicker = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _scanTicker?.cancel();
    super.dispose();
  }

  Future<void> _connect(DiscoveredDevice device) async {
    Navigator.of(context).pop();
    await widget.onConnect(device);
  }

  void _showAllDevices() {
    final nav = Navigator.of(context);
    final controller = widget.controller;
    final onConnect = widget.onConnect;
    nav.pop();
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => DiscoveredDevicesScreen(
          controller: controller,
          onConnect: onConnect,
        ),
      ),
    );
  }

  void _clearResults() {
    widget.controller.clearDiscoveredDevices();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final controller = widget.controller;
    final discovered = controller.discoveredDevices;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (_, scrollController) => LayoutBuilder(
        builder: (context, innerConstraints) {
          // innerConstraints.maxHeight is the actual current height of the sheet,
          // and updates as the user drags it. Reserve 68pt for the action button
          // pinned below the list (top padding 8 + button 44 + bottom padding 16).
          const buttonAreaHeight = 68.0;
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.cancel),
                      ),
                      Expanded(
                        child: Text(
                          l10n.devicesDiscoveredDevices,
                          textAlign: TextAlign.center,
                          style: tt.titleMedium,
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: controller.scannerState !=
                                ScannerStateView.scanning
                            ? Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _clearResults,
                                  child: Text(l10n.devicesClearDiscovered),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ScanningCard(
                        progress: controller.scannerProgress,
                        total: controller.scannerTotalCount,
                        foundCount: discovered.length,
                        discoveredDevices: discovered,
                        cidr: controller.scannerCidr,
                        startedAt: controller.scannerStartedAt,
                        protocol: controller.scannerProtocol,
                        completed:
                            controller.scannerState !=
                            ScannerStateView.scanning,
                        onConnect: _connect,
                        onShowAll: _showAllDevices,
                        availableSheetHeight:
                            innerConstraints.maxHeight - buttonAreaHeight,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _ScanActionButton(
                    icon: controller.scannerState == ScannerStateView.scanning
                        ? Icons.stop_circle_outlined
                        : Icons.sensors,
                    label: controller.scannerState == ScannerStateView.scanning
                        ? l10n.devicesScanStop
                        : l10n.devicesScanNetwork,
                    onPressed:
                        controller.scannerState == ScannerStateView.scanning
                        ? controller.stopScan
                        : controller.startScan,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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
    final screenHeight = MediaQuery.sizeOf(context).height;
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
              availableSheetHeight: screenHeight,
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
              availableSheetHeight: screenHeight,
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
      icon: Icon(icon, size: 24),
      label: Text(label),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        side: BorderSide(color: color),
        foregroundColor: color,
        textStyle: Theme.of(context).textTheme.titleSmall,
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
      icon: const Icon(Icons.sensors, size: 24),
      label: Text(l10n.devicesScanNetwork),
      onPressed: onStart,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: BorderSide(color: cs.primary),
        foregroundColor: cs.primary,
        textStyle: tt.titleSmall,
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
  final VoidCallback? onShowAll;
  final double availableSheetHeight;

  const _ScanningCard({
    required this.progress,
    required this.total,
    required this.foundCount,
    required this.discoveredDevices,
    required this.cidr,
    required this.startedAt,
    required this.protocol,
    required this.onConnect,
    required this.availableSheetHeight,
    this.completed = false,
    this.onStop,
    this.onRestart,
    this.onShowAll,
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
    // Whether an action button (stop or restart) renders inside this card.
    final hasActionButton =
        (!completed && onStop != null) || (completed && onRestart != null);
    // Fixed overhead: sheet header (71) + list padding (32) + card padding (26) +
    // icon row (44) + spacers (38) + progress (16) + subnet/time (20) +
    // divider+spacer before devices (13) + action button+spacer (56, when present).
    // When the button is pinned outside the card (hasActionButton == false), the
    // caller subtracts the external button area from availableSheetHeight so the
    // reduced overhead (260) still gives the correct available space.
    final fixedOverhead = hasActionButton ? 316.0 : 260.0;
    const deviceRowHeight = 62.0;
    const footerHeight = 52.0;

    final available = availableSheetHeight - fixedOverhead;
    int maxVisible;
    if (discoveredDevices.isEmpty) {
      maxVisible = 0;
    } else {
      maxVisible = (available / deviceRowHeight).floor();
      if (maxVisible < discoveredDevices.length) {
        maxVisible = ((available - footerHeight) / deviceRowHeight).floor();
      }
      maxVisible = maxVisible.clamp(1, discoveredDevices.length);
    }

    final visibleDiscoveredDevices = discoveredDevices.take(maxVisible).toList();
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
                DiscoveredDeviceRow(device: device, onConnect: onConnect),
              if (hiddenDiscoveredCount > 0)
                _DiscoveredDevicesFooter(
                  hiddenCount: hiddenDiscoveredCount,
                  totalCount: discoveredDevices.length,
                  onTap: onShowAll ?? () => _showDiscoveredDevices(context),
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
                icon: Icons.sensors,
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

  void _showDiscoveredDevices(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final device in discoveredDevices)
              DiscoveredDeviceRow(
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

  String _protocolLabel(AppLocalizations l10n, ProtocolType? protocol) {
    return switch (protocol) {
      ProtocolType.modbusRtuIp => l10n.connectTypeRtu,
      ProtocolType.modbusTcp || null => l10n.connectTypeTcp,
    };
  }
}

class DiscoveredDeviceRow extends StatelessWidget {
  final DiscoveredDevice device;
  final void Function(DiscoveredDevice) onConnect;
  final bool showBottomDivider;

  const DiscoveredDeviceRow({
    super.key,
    required this.device,
    required this.onConnect,
    this.showBottomDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        if (showBottomDivider)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Divider(
              height: 1,
              color: Theme.of(context).dividerTheme.color,
            ),
          ),
      ],
    );
  }
}

class _DiscoveredDevicesFooter extends StatelessWidget {
  final int hiddenCount;
  final int totalCount;
  final VoidCallback onTap;

  const _DiscoveredDevicesFooter({
    required this.hiddenCount,
    required this.totalCount,
    required this.onTap,
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 52,
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
