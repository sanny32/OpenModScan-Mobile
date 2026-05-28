import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/device_info.dart';
import 'devices_controller.dart';
import 'widgets/device_card.dart';

class SavedDevicesScreen extends StatefulWidget {
  final DevicesController controller;
  final ValueChanged<String> onOpenDevice;

  const SavedDevicesScreen({
    super.key,
    required this.controller,
    required this.onOpenDevice,
  });

  @override
  State<SavedDevicesScreen> createState() => _SavedDevicesScreenState();
}

class _SavedDevicesScreenState extends State<SavedDevicesScreen> {
  late DeviceSortMode _sortMode;
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _sortMode = widget.controller.savedDevicesSortMode;
    widget.controller.addListener(_rebuild);
    _searchController.addListener(_onSearchChanged);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    setState(() => _search = _searchController.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _setSortMode(DeviceSortMode value) async {
    setState(() => _sortMode = value);
    await widget.controller.setSavedDevicesSortMode(value);
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
    final l10n = context.l10n;
    final devices = widget.controller.devicesForSearchAndSort(
      _search,
      _sortMode,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesSavedConnections)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<DeviceSortMode>(
                  segments: [
                    ButtonSegment(
                      value: DeviceSortMode.lastConnected,
                      label: Text(l10n.devicesSortLastConnected),
                    ),
                    ButtonSegment(
                      value: DeviceSortMode.created,
                      label: Text(l10n.devicesSortCreated),
                    ),
                  ],
                  selected: {_sortMode},
                  showSelectedIcon: false,
                  style: _sortSegmentedButtonStyle(context),
                  onSelectionChanged: (selected) {
                    _setSortMode(selected.single);
                  },
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return Dismissible(
                    key: ValueKey('saved-screen-${device.id}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _deleteDevice(device),
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
                      device: device,
                      connected: widget.controller.isConnected(device),
                      favorite: device.isFavorite,
                      onTap: () => widget.onOpenDevice(device.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle _sortSegmentedButtonStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return ButtonStyle(
    textStyle: WidgetStatePropertyAll(tt.bodyMedium),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return cs.primary;
      return cs.surfaceContainerHighest;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return cs.onPrimary;
      return cs.onSurface;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return cs.onPrimary;
      return cs.onSurface;
    }),
    side: WidgetStatePropertyAll(
      BorderSide(color: Theme.of(context).dividerColor),
    ),
  );
}
