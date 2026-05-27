import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/device_info.dart';
import '../../models/discovered_device.dart';
import '../../runtime/runtime_ports.dart';
import 'device_form_sheet.dart';
import 'discovered_devices_screen.dart';
import 'devices_controller.dart';
import 'saved_devices_screen.dart';
import 'widgets/device_card.dart';
import 'widgets/devices_section_header.dart';
import 'widgets/scan_panel.dart';

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

  Future<void> _connectDiscovered(DiscoveredDevice discovered) async {
    try {
      if (widget.controller.scannerState == ScannerStateView.scanning) {
        widget.controller.stopScan();
      }
      final device = await widget.controller.connectDiscoveredDevice(
        discovered,
      );
      if (!mounted) return;
      widget.onOpenDevice(device.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('$error')));
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

  void _openSavedDevices() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SavedDevicesScreen(
          controller: widget.controller,
          onOpenDevice: widget.onOpenDevice,
        ),
      ),
    );
  }

  void _openScanSheet({required bool startOnOpen}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanSheet(
        controller: widget.controller,
        startOnOpen: startOnOpen,
        onConnect: _connectDiscovered,
      ),
    );
  }

  void _openDiscoveredDevices() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiscoveredDevicesScreen(
          controller: widget.controller,
          onConnect: _connectDiscovered,
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
    final visibleSavedDevices = widget.controller.visibleHomeDevices;
    final hiddenSavedDeviceCount =
        widget.controller.devices.length - visibleSavedDevices.length;
    final canClearDiscovered =
        widget.controller.hasDiscoveredDevices &&
        widget.controller.scannerState != ScannerStateView.scanning;
    final hasDiscoveredDevices = discovered.isNotEmpty;
    final hasSavedDevices = widget.controller.devices.isNotEmpty;
    final useSplitLayout = hasDiscoveredDevices && hasSavedDevices;

    Widget buildDismissible(DeviceInfo d) => Dismissible(
      key: ValueKey(d.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteDevice(d),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: cs.onError, size: 26),
      ),
      child: DeviceCard(
        device: d,
        connected: widget.controller.isConnected(d),
        favorite: d.isFavorite,
        onToggleFavorite: () => widget.controller.toggleFavorite(d),
        onTap: () => widget.onOpenDevice(d.id),
      ),
    );

    final savedChildren = <Widget>[
      DevicesSectionHeader(title: l10n.devicesSavedConnections),
      ...visibleSavedDevices.map(buildDismissible),
      if (hiddenSavedDeviceCount > 0)
        _SavedDevicesFooter(
          hiddenCount: hiddenSavedDeviceCount,
          totalCount: widget.controller.devices.length,
          onShowAll: _openSavedDevices,
        ),
    ];

    final discoveredChildren = <Widget>[
      DevicesSectionHeader(
        title: l10n.devicesDiscoveredTitle,
        trailing: !canClearDiscovered
            ? null
            : TextButton(
                onPressed: widget.controller.clearDiscoveredDevices,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.devicesClearDiscovered),
              ),
      ),
      DiscoveredDevicesPreview(
        discoveredDevices: discovered,
        onConnect: _connectDiscovered,
        onShowAll: _openDiscoveredDevices,
      ),
    ];

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
                child: useSplitLayout
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final maxSavedHeight = constraints.maxHeight * 2 / 3;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: maxSavedHeight,
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  children: savedChildren,
                                ),
                              ),
                              DevicesSectionHeader(
                                title: l10n.devicesDiscoveredTitle,
                                trailing: !canClearDiscovered
                                    ? null
                                    : TextButton(
                                        onPressed:
                                            widget
                                                .controller
                                                .clearDiscoveredDevices,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          l10n.devicesClearDiscovered,
                                        ),
                                      ),
                              ),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, discoveredConstraints) {
                                    return DiscoveredDevicesPreview(
                                      discoveredDevices: discovered,
                                      onConnect: _connectDiscovered,
                                      onShowAll: _openDiscoveredDevices,
                                      availableHeight:
                                          discoveredConstraints.maxHeight,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 8),
                        children: [
                          ...savedChildren,
                          if (hasDiscoveredDevices) ...discoveredChildren,
                        ],
                      ),
              ),
              _ScanNetworkDock(
                scanning:
                    widget.controller.scannerState == ScannerStateView.scanning,
                onPressed: () => _openScanSheet(
                  startOnOpen:
                      widget.controller.scannerState !=
                      ScannerStateView.scanning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanNetworkDock extends StatelessWidget {
  final bool scanning;
  final VoidCallback onPressed;

  const _ScanNetworkDock({required this.scanning, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: OutlinedButton.icon(
        icon: Icon(
          scanning ? Icons.travel_explore : Icons.radar_outlined,
          size: 18,
        ),
        label: Text(
          scanning ? l10n.devicesScanningTitle : l10n.devicesScanNetwork,
        ),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: cs.primary),
          foregroundColor: cs.primary,
          textStyle: tt.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _SavedDevicesFooter extends StatelessWidget {
  final int hiddenCount;
  final int totalCount;
  final VoidCallback onShowAll;

  const _SavedDevicesFooter({
    required this.hiddenCount,
    required this.totalCount,
    required this.onShowAll,
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onShowAll,
        borderRadius: BorderRadius.circular(12),
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
