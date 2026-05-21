import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/device_info.dart';
import '../models/register_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_status_chip.dart';
import 'device_form_sheet.dart';

class DeviceScreen extends StatefulWidget {
  final DeviceInfo device;
  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  late DeviceInfo _device;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
  }

  void _editDevice() {
    showModalBottomSheet<DeviceInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceFormSheet(initial: _device),
    ).then((updated) {
      if (updated != null) setState(() => _device = updated);
    });
  }

  void _editNotes() {
    final ctrl = TextEditingController(text: _device.notes);
    final l10n = context.l10n;
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.labelNotes),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.notesHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    ).then((value) {
      if (value != null) setState(() => _device = _device.copyWith(notes: value));
    });
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
          onPressed: () => Navigator.pop(context, _device),
        ),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: l10n.appBarName,
                style: tt.titleLarge!.copyWith(color: cs.onSurface),
              ),
              TextSpan(
                text: l10n.appBarNameSuffix,
                style: tt.titleLarge!.copyWith(color: appColors.brandGreen),
              ),
            ],
          ),
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
          ConnectionStatusChip(connected: _device.connected),
          const SizedBox(height: 12),
          _PlcCard(device: _device, connected: _device.connected),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(
                () => _device = _device.copyWith(connected: !_device.connected)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: _device.connected ? cs.error : cs.primary),
              foregroundColor: _device.connected ? cs.error : cs.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(_device.connected ? l10n.disconnect : l10n.connect),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.download_outlined,
                  title: l10n.readRegisters,
                  subtitle: l10n.readRegistersSubtitle,
                  color: cs.primary,
                  enabled: _device.connected,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.upload_outlined,
                  title: l10n.writeValue,
                  subtitle: l10n.writeValueSubtitle,
                  color: appColors.writeActionColor,
                  enabled: _device.connected,
                  onTap: () {},
                ),
              ),
            ],
          ),
          if (_device.connected) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.lastValues, style: tt.titleMedium),
                TextButton(
                  onPressed: () {},
                  child: Text(l10n.viewAll),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...mockRegisters.take(5).map((r) => _LastValueRow(entry: r)),
          ],
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              enabled: _device.connected,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (_device.connected
                          ? appColors.openLogColor
                          : cs.onSurfaceVariant)
                      .withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.list_alt,
                    color: _device.connected
                        ? appColors.openLogColor
                        : cs.onSurfaceVariant,
                    size: 24),
              ),
              title: Text(l10n.openLog,
                  style: tt.titleSmall!.copyWith(
                      color: _device.connected
                          ? appColors.openLogColor
                          : cs.onSurfaceVariant)),
              subtitle: Text(l10n.openLogSubtitle,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: _device.connected ? () {} : null,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.labelNotes,
                            style: tt.labelMedium!
                                .copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          _device.notes.isEmpty
                              ? l10n.notesHint
                              : _device.notes,
                          style: tt.bodyMedium!.copyWith(
                              color: _device.notes.isEmpty
                                  ? cs.onSurfaceVariant
                                  : cs.onSurface),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    color: cs.onSurfaceVariant,
                    onPressed: _editNotes,
                  ),
                ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.memory, color: cs.primary, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name, style: tt.titleMedium),
                  const SizedBox(height: 2),
                  Text(device.address,
                      style: tt.bodyMedium!
                          .copyWith(color: cs.onSurfaceVariant)),
                  Text(device.protocolName,
                      style: tt.bodySmall!.copyWith(color: cs.primary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.wifi,
                    color: connected
                        ? appColors.connectedColor
                        : cs.onSurfaceVariant,
                    size: 22),
                const SizedBox(height: 4),
                Text(l10n.unitId(device.unitId),
                    style:
                        tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
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
            children: [
              Icon(icon, color: effectiveColor, size: 38),
              const SizedBox(height: 8),
              Text(title,
                  style: tt.bodyLarge!.copyWith(
                      color: effectiveColor, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: tt.labelSmall!.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastValueRow extends StatelessWidget {
  final RegisterEntry entry;
  const _LastValueRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text('${entry.address}',
                style: tt.bodyMedium!.copyWith(color: cs.onSurface)),
          ),
          Expanded(
            child: Text(entry.value,
                style: tt.bodyMedium!.copyWith(
                    color: appColors.valueColor, fontWeight: FontWeight.bold)),
          ),
          Text(entry.typeName,
              style: tt.bodyMedium!.copyWith(color: appColors.typeColor)),
        ],
      ),
    );
  }
}
