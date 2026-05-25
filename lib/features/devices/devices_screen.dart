import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/device_info.dart';
import '../../models/discovered_device.dart';
import '../../runtime/runtime_ports.dart';
import 'device_form_sheet.dart';
import 'devices_controller.dart';
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

  List<DeviceInfo> get _filtered => widget.controller.filteredDevices;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final discovered = widget.controller.discoveredDevices;
    final canClearDiscovered =
        widget.controller.hasDiscoveredDevices &&
        widget.controller.scannerState != ScannerStateView.scanning;

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
                    DevicesSectionHeader(title: l10n.devicesSavedConnections),
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
                        child: DeviceCard(
                          device: d,
                          connected: widget.controller.isConnected(d),
                          onTap: () => widget.onOpenDevice(d.id),
                        ),
                      ),
                    ),
                    DevicesSectionHeader(
                      title: l10n.devicesDiscoveredDevices,
                      trailing: !canClearDiscovered
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
                    ScanPanel(
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
                      onConnect: _connectDiscovered,
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
}
