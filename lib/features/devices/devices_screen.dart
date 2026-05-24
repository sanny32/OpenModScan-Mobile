import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/device_info.dart';
import '../../models/discovered_device.dart';
import '../../runtime/runtime_ports.dart';
import '../../theme/app_theme.dart';
import 'devices_controller.dart';
import 'device_form_sheet.dart';

class DevicesScreen extends StatefulWidget {
  final DevicesController controller;
  final ValueChanged<String> onOpenDevice;

  const DevicesScreen({
    super.key,
    required this.controller,
    required this.onOpenDevice,
  });

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  Timer? _scanTicker;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    _syncScanTicker();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
    _syncScanTicker();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _scanTicker?.cancel();
    super.dispose();
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

  List<DeviceInfo> get _filtered => widget.controller.filteredDevices;

  String _scanSectionTitle(AppLocalizations l10n) {
    return switch (widget.controller.scannerState) {
      ScannerStateView.scanning => l10n.devicesScanningNetwork,
      ScannerStateView.done => l10n.devicesScanCompleted,
      ScannerStateView.idle => l10n.devicesDiscoveredDevices,
    };
  }

  void _openConnect([DiscoveredDevice? discovered]) async {
    final initial = DeviceInfo(
      name: 'Device #${widget.controller.devices.length + 1}',
      host: discovered?.host ?? '',
      port: discovered?.port ?? 502,
      protocol: discovered?.protocol ?? ProtocolType.modbusTcp,
      unitId: discovered?.unitId ?? 1,
    );

    final result = await showModalBottomSheet<DeviceFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceFormSheet(
        initial: initial,
        addMode: true,
        existingNames: widget.controller.devices.map((d) => d.name).toList(),
      ),
    );
    if (result != null && mounted) {
      await widget.controller.addDevice(result.device);
      if (!result.connectAfterSave) return;

      try {
        await widget.controller.toggleConnection(result.device);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _deleteDevice(DeviceInfo device) async {
    final index = await widget.controller.removeDevice(device.id);
    if (!mounted || index == null) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.deviceDeleted),
          persist: false,
          action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () {
              widget.controller.restoreDevice(index, device);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final discovered = widget.controller.discoveredDevices;

    return ScaffoldMessenger(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.navDevices, style: tt.headlineMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _openConnect,
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  onChanged: widget.controller.setSearch,
                  decoration: InputDecoration(
                    hintText: l10n.devicesSearch,
                    prefixIcon: Icon(
                      Icons.search,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    _sectionHeader(context, l10n.devicesSavedConnections),
                    ..._filtered.map(
                      (d) => Dismissible(
                        key: ValueKey(d),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteDevice(d),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: cs.onError,
                            size: 26,
                          ),
                        ),
                        child: _DeviceCard(
                          device: d,
                          connected: widget.controller.isConnected(d),
                          onTap: () => widget.onOpenDevice(d.id),
                        ),
                      ),
                    ),
                    _sectionHeader(
                      context,
                      _scanSectionTitle(l10n),
                      trailing: !widget.controller.hasDiscoveredDevices
                          ? null
                          : TextButton(
                              onPressed:
                                  widget.controller.clearDiscoveredDevices,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(l10n.devicesClearDiscovered),
                            ),
                    ),
                    _ScanButton(
                      state: widget.controller.scannerState,
                      progress: widget.controller.scannerProgress,
                      total: widget.controller.scannerTotalCount,
                      foundCount: discovered.length,
                      discoveredDevices: discovered,
                      cidr: widget.controller.scannerCidr,
                      startedAt: widget.controller.scannerStartedAt,
                      protocol: widget.controller.scannerProtocol,
                      onTap: widget.controller.startScan,
                      onStop: widget.controller.stopScan,
                      onConnect: _openConnect,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: tt.labelLarge!.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final bool connected;
  final VoidCallback onTap;
  const _DeviceCard({
    required this.device,
    required this.connected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>();
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: connected
                      ? (appColors?.connectedColor ?? cs.primary)
                      : cs.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
              Icon(Icons.memory, color: cs.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: tt.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      device.address,
                      style: tt.bodyMedium!.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
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
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
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

  const _ScanButton({
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
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
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
            ),
            const SizedBox(height: 10),
            _ScanActionButton(
              icon: Icons.radar_outlined,
              label: l10n.devicesScanNetwork,
              onPressed: onTap,
              color: cs.primary,
            ),
          ],
        ),
        ScannerStateView.idle => _EmptyScanCard(onStart: onTap),
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

class _EmptyScanCard extends StatelessWidget {
  final VoidCallback onStart;

  const _EmptyScanCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.travel_explore, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.devicesNoScansYet,
              style: tt.titleMedium!.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.devicesNoScansYetSubtitle,
              textAlign: TextAlign.center,
              style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              icon: const Icon(Icons.radar_outlined, size: 18),
              label: Text(l10n.devicesStartScanning),
              onPressed: onStart,
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
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

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
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
                const SizedBox(width: 14),
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
                Text(
                  _protocolLabel(l10n, protocol),
                  style: tt.labelLarge!.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 16),
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
              const SizedBox(height: 14),
              Divider(height: 1, color: Theme.of(context).dividerTheme.color),
              for (final device in discoveredDevices)
                _DiscoveredScanRow(device: device, onConnect: onConnect),
            ],
            if (!completed && onStop != null) ...[
              const SizedBox(height: 14),
              _ScanActionButton(
                icon: Icons.stop_circle_outlined,
                label: l10n.devicesScanStop,
                onPressed: onStop!,
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
