import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/discovered_device.dart';
import '../../models/device_info.dart';
import '../../runtime/runtime_ports.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/app_test_keys.dart';
import '../../widgets/error_feedback.dart';
import '../../widgets/keyboard_done_bar.dart';
import 'device_form_sheet.dart';
import 'discovered_devices_screen.dart';
import 'devices_controller.dart';
import 'layout_metrics.dart';
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
      protocol: discovered?.protocol ?? widget.controller.defaultConnectionType,
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
        showErrorSnackBar(context, error);
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
      showErrorSnackBar(context, error);
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
    final canClearDiscovered =
        widget.controller.hasDiscoveredDevices &&
        widget.controller.scannerState != ScannerStateView.scanning;
    final hasDiscoveredDevices = discovered.isNotEmpty;
    final hasSavedDevices = widget.controller.devices.isNotEmpty;
    final useSplitLayout = hasDiscoveredDevices && hasSavedDevices;

    // Row/header heights are measured from the actual theme text styles and the
    // current text scale, so the "how many fit" math stays correct for any font
    // size (accessibility scaling), theme, or locale — not just one screen.
    final textScaler = MediaQuery.textScalerOf(context);
    final savedCardHeight = _measuredSavedCardHeight(tt, textScaler);
    final savedHeaderHeight = _measuredSavedHeaderHeight(tt, textScaler);

    Widget buildDismissible(DeviceInfo d) => Dismissible(
      key: ValueKey(d.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteDevice(d),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: cs.onError, size: 26),
      ),
      child: DeviceCard(
        device: d,
        connected: widget.controller.isConnected(d),
        onTap: () => widget.onOpenDevice(d.id),
      ),
    );

    // Reordering lives on the dedicated full-screen list (opened by the header
    // action), where the whole list is visible and indices map 1:1 to storage.
    // The home preview is only a height-constrained prefix, so it stays a plain
    // list to avoid nesting a reorderable scrollable inside the split layout.
    final savedHeaderAction = !hasSavedDevices
        ? null
        : IconButton(
            icon: const Icon(Icons.swap_vert, size: 22),
            tooltip: l10n.devicesReorder,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _openSavedDevices,
          );

    // Builds the saved-devices section showing the first [limit] devices (a
    // prefix of the stored order) plus a "show all" footer when some are
    // hidden. Used by both layouts; each passes the limit that fits its space.
    List<Widget> buildSavedChildren(int limit) {
      final total = widget.controller.devices.length;
      final visible = widget.controller.visibleHomeDevices(limit);
      final hidden = total - visible.length;
      return [
        DevicesSectionHeader(
          title: l10n.devicesSavedConnections,
          // Offer the reorder shortcut only when no "show all" footer is shown
          // (the footer already opens the same full list), so there are never
          // two entries to it at once.
          trailing: hidden > 0 ? null : savedHeaderAction,
        ),
        ...visible.map(buildDismissible),
        if (hidden > 0)
          _SavedDevicesFooter(
            hiddenCount: hidden,
            totalCount: total,
            onShowAll: _openSavedDevices,
          ),
      ];
    }

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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  8,
                  AppSpacing.screenGutter,
                  0,
                ),
                child: KeyboardDoneField(
                  label: l10n.kbSearch,
                  builder: (focusNode) => TextField(
                    focusNode: focusNode,
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
              ),
              Expanded(
                child: useSplitLayout
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final maxSavedHeight = constraints.maxHeight * 2 / 3;
                          // Show only as many cards as fit (with the footer) in
                          // the saved section's share, so the footer is never
                          // clipped into the discovered section below.
                          final savedLimit = _savedFitCount(
                            available: maxSavedHeight,
                            headerHeight: savedHeaderHeight,
                            cardHeight: savedCardHeight,
                            count: widget.controller.filteredDevices.length,
                          );
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
                                  children: buildSavedChildren(savedLimit),
                                ),
                              ),
                              DevicesSectionHeader(
                                title: l10n.devicesDiscoveredTitle,
                                trailing: !canClearDiscovered
                                    ? null
                                    : TextButton(
                                        onPressed: widget
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
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final savedLimit = _savedFitCount(
                            available: constraints.maxHeight,
                            headerHeight: savedHeaderHeight,
                            cardHeight: savedCardHeight,
                            count: widget.controller.filteredDevices.length,
                          );
                          return ListView(
                            padding: const EdgeInsets.only(bottom: 8),
                            children: [
                              ...buildSavedChildren(savedLimit),
                              if (hasDiscoveredDevices) ...discoveredChildren,
                            ],
                          );
                        },
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

/// Full height of a [DeviceCard]: 8pt vertical margin + 28pt content padding +
/// the three stacked text lines (title, address, protocol) with a 2pt gap.
double _measuredSavedCardHeight(TextTheme tt, TextScaler scaler) {
  return 8 +
      28 +
      measuredLineHeight(tt.titleSmall, scaler) +
      2 +
      measuredLineHeight(tt.bodyMedium, scaler) +
      measuredLineHeight(tt.bodySmall, scaler) +
      2; // sub-pixel rounding buffer so we never under-count and clip a card
}

/// Full height of a [DevicesSectionHeader]: 22pt vertical padding + one line.
double _measuredSavedHeaderHeight(TextTheme tt, TextScaler scaler) {
  return 22 + measuredLineHeight(tt.labelLarge, scaler);
}

/// How many saved-device cards fit in [available] height under the section
/// header, reserving room for the "show all" footer ([footerHeight]) whenever
/// not all [count] devices fit. Returns at least 1 when any device matches.
int _savedFitCount({
  required double available,
  required double headerHeight,
  required double cardHeight,
  required int count,
  double footerHeight = 60.0,
}) {
  if (count == 0) return 0;
  final fitsAll = ((available - headerHeight) / cardHeight).floor();
  if (fitsAll >= count) return count;
  return ((available - headerHeight - footerHeight) / cardHeight)
      .floor()
      .clamp(1, count)
      .toInt();
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        8,
        AppSpacing.screenGutter,
        12,
      ),
      child: FilledButton.icon(
        key: AppTestKeys.scanNetworkButton,
        icon: Icon(scanning ? Icons.travel_explore : Icons.sensors, size: 24),
        label: Text(
          scanning ? l10n.devicesScanningTitle : l10n.devicesScanNetwork,
        ),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          textStyle: tt.titleSmall,
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
          ),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.devicesMoreCount(hiddenCount),
                    style: style,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.devicesShowAllCount(totalCount),
                    style: style,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
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
