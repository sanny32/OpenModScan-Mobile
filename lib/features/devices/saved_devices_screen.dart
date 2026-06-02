import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../widgets/keyboard_done_bar.dart';
import '../../models/device_info.dart';
import '../../theme/app_dimens.dart';
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
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
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

  Widget _buildDeviceTile(
    BuildContext context,
    DeviceInfo device, {
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('saved-screen-${device.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteDevice(device),
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
        device: device,
        connected: widget.controller.isConnected(device),
        onTap: () => widget.onOpenDevice(device.id),
        trailing: trailing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final devices = widget.controller.savedDevicesForSearch(_search);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesSavedConnections)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                8,
                AppSpacing.screenGutter,
                4,
              ),
              child: KeyboardDoneField(
                label: l10n.kbSearch,
                builder: (focusNode) => TextField(
                  controller: _searchController,
                  focusNode: focusNode,
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
              // Drag-to-reorder maps on-screen indices 1:1 to storage order, so
              // it is only offered when no search filter narrows the list.
              child: _search.isEmpty
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      buildDefaultDragHandles: false,
                      itemCount: devices.length,
                      onReorderItem: (oldIndex, newIndex) async {
                        await widget.controller.reorderSavedDevices(
                          oldIndex,
                          newIndex,
                        );
                      },
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return _buildDeviceTile(
                          context,
                          device,
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Icon(
                                Icons.drag_handle,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: devices.length,
                      itemBuilder: (context, index) =>
                          _buildDeviceTile(context, devices[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
