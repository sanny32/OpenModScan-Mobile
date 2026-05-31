import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/device_info.dart';

import '../../models/app_settings.dart';
import '../../models/register_address_type.dart';
import '../../models/register_list.dart';
import '../../navigation/navigation_targets.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_feedback.dart';
import '../registers/register_list_dialogs.dart';
import 'device_marker_color_palette.dart';
import 'devices_controller.dart';
import 'device_form_sheet.dart';

int _regTypeOffset(String t) => RegisterAddressType.fromCode(t).displayOffset;

String _regTypeLabel(String t) => RegisterAddressType.tryParse(t)?.label ?? t;

class DeviceScreen extends StatefulWidget {
  final String deviceId;
  final DevicesController controller;
  final ValueChanged<RegistersRouteArgs> onOpenRegisters;
  final ValueChanged<TrafficRouteArgs> onOpenTraffic;

  const DeviceScreen({
    super.key,
    required this.deviceId,
    required this.controller,
    required this.onOpenRegisters,
    required this.onOpenTraffic,
  });

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  late DeviceInfo _device;
  var _connectionBusy = false;

  bool get _connected => widget.controller.isConnected(_device);

  @override
  void initState() {
    super.initState();
    _device = widget.controller.deviceById(widget.deviceId)!;
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final updated = widget.controller.deviceById(widget.deviceId);
    if (updated != null) {
      setState(() => _device = updated);
    }
  }

  Future<void> _editNotes() => showDialog<void>(
    context: context,
    builder: (_) => _NotesDialog(
      initial: _device.notes,
      onSaved: (text) =>
          widget.controller.updateDevice(_device.copyWith(notes: text)),
    ),
  );

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_connectionBusy) return;
    setState(() => _connectionBusy = true);
    try {
      await widget.controller.toggleConnection(_device);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _connectionBusy = false);
      }
    }
  }

  void _editDevice() {
    showModalBottomSheet<DeviceFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceFormSheet(
        initial: _device,
        existingNames: widget.controller.devices
            .where((d) => d.id != _device.id)
            .map((d) => d.name)
            .toList(),
      ),
    ).then((result) {
      if (result != null) widget.controller.updateDevice(result.device);
    });
  }

  Future<void> _addRegisterList() async {
    final result = await showRegisterListDialog(
      context,
      defaultName: 'List ${_device.registerLists.length + 1}',
      existingNames: _device.registerLists.map((l) => l.name).toList(),
    );

    if (!mounted) return;
    if (result != null) {
      await widget.controller.addRegisterList(_device.id, result);
    }
  }

  Future<void> _deleteRegisterList(int index) async {
    await widget.controller.removeRegisterList(
      _device.id,
      _device.registerLists[index].id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _device.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: tt.titleLarge!.copyWith(color: cs.onSurface),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editDevice,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PlcCard(device: _device, connected: _connected),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _connectionBusy ? null : _toggleConnection,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _connected ? cs.error : cs.primary),
              foregroundColor: _connected ? cs.error : cs.primary,
              minimumSize: const Size(double.infinity, 48),
              textStyle: Theme.of(context).textTheme.titleSmall,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _connectionBusy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_connected ? l10n.disconnect : l10n.connect),
          ),
          const SizedBox(height: 16),
          // IntrinsicHeight + stretch keeps both cards the same height even when
          // their subtitles wrap to a different number of lines.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.download_outlined,
                    title: l10n.readRegisters,
                    subtitle: l10n.readRegistersSubtitle,
                    color: cs.primary,
                    enabled: _connected,
                    onTap: () {
                      widget.onOpenRegisters(
                        RegistersRouteArgs(deviceId: _device.id),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.upload_outlined,
                    title: l10n.writeValue,
                    subtitle: l10n.writeValueSubtitle,
                    color: appColors.writeActionColor,
                    enabled: _connected,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.sectionRegisterLists, style: tt.titleMedium),
          const SizedBox(height: 8),
          ...List.generate(_device.registerLists.length, (i) {
            final list = _device.registerLists[i];
            return Dismissible(
              key: ValueKey(list.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: cs.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.delete_outline, color: cs.onError),
              ),
              onDismissed: (_) => _deleteRegisterList(i),
              child: _RegisterListTile(
                list: list,
                onTap: () {
                  widget.onOpenRegisters(
                    RegistersRouteArgs(
                      deviceId: _device.id,
                      registerListId: list.id,
                    ),
                  );
                },
              ),
            );
          }),
          _AddRegisterListTile(onTap: _addRegisterList),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              enabled: _connected,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      (_connected
                              ? appColors.openLogColor
                              : cs.onSurfaceVariant)
                          .withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.list_alt,
                  color: _connected
                      ? appColors.openLogColor
                      : cs.onSurfaceVariant,
                  size: 24,
                ),
              ),
              title: Text(
                l10n.openLog,
                style: tt.titleSmall!.copyWith(
                  color: _connected
                      ? appColors.openLogColor
                      : cs.onSurfaceVariant,
                ),
              ),
              subtitle: Text(
                l10n.openLogSubtitle,
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: _connected
                  ? () => widget.onOpenTraffic(TrafficRouteArgs(_device.id))
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _editNotes,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.labelNotes,
                            style: tt.labelMedium!.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _device.notes.isNotEmpty
                                ? _device.notes
                                : l10n.notesHint,
                            style: tt.bodyMedium!.copyWith(
                              color: _device.notes.isNotEmpty
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlcCard extends StatelessWidget {
  final DeviceInfo device;
  final bool connected;
  const _PlcCard({required this.device, required this.connected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    final statusLabel = connected
        ? l10n.statusConnected
        : l10n.statusDisconnected;
    final markerColor = device.markerColor.resolve(cs);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: markerColor.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.memory, color: markerColor, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    device.protocolName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: tt.bodySmall!.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  Icons.wifi,
                  semanticLabel: statusLabel,
                  color: connected
                      ? appColors.connectedColor
                      : cs.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.unitId(device.unitId),
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final effectiveColor = enabled ? color : cs.onSurfaceVariant;
    return Card(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: effectiveColor, size: 38),
              const SizedBox(height: 8),
              Text(
                title,
                style: tt.bodyLarge!.copyWith(
                  color: effectiveColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: tt.labelSmall!.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddRegisterListTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRegisterListTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(Icons.add, color: cs.primary),
        title: Text(
          context.l10n.menuAddRegs,
          style: tt.titleSmall!.copyWith(color: cs.primary),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _NotesDialog extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onSaved;

  const _NotesDialog({required this.initial, required this.onSaved});

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.labelNotes),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: null,
        decoration: InputDecoration(
          hintText: l10n.notesHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            widget.onSaved(_ctrl.text.trim());
            Navigator.pop(context);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _RegisterListTile extends StatelessWidget {
  final RegisterList list;
  final VoidCallback? onTap;
  const _RegisterListTile({required this.list, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final offset = _regTypeOffset(list.regType);
    final minStart = AppSettings.instance.addressBaseStart;
    final startAddress = list.startAddress < minStart
        ? minStart
        : list.startAddress;
    final start = offset + startAddress;
    final end = start + list.count - 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(Icons.table_rows_outlined, color: cs.primary),
        title: Text(list.name, style: tt.titleSmall),
        subtitle: Text(
          '${_regTypeLabel(list.regType)} · $start – $end',
          style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
