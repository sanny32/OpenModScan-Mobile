import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/device_info.dart';
import '../theme/app_theme.dart';

/// Shared bottom sheet for switching the active device. Used by the Registers
/// and Traffic screens so device selection looks and behaves the same way.
///
/// Returns the chosen device id, or `null` if the sheet was dismissed.
Future<String?> showDeviceSelectSheet(
  BuildContext context, {
  required List<DeviceInfo> devices,
  required String? selectedId,
  required bool Function(DeviceInfo) isConnected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final tt = Theme.of(ctx).textTheme;
      final appColors = Theme.of(ctx).extension<AppColors>()!;
      final l10n = ctx.l10n;
      final sortedDevices = [...devices]
        ..sort((a, b) {
          final aConnected = isConnected(a);
          final bConnected = isConnected(b);
          if (aConnected != bConnected) return aConnected ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.menuSelectDevice,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final device in sortedDevices)
                    _DeviceSelectTile(
                      device: device,
                      selected: device.id == selectedId,
                      connected: isConnected(device),
                      connectedColor: appColors.connectedColor,
                      disconnectedColor: appColors.disconnectedColor,
                      onTap: () => Navigator.pop(ctx, device.id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _DeviceSelectTile extends StatelessWidget {
  final DeviceInfo device;
  final bool selected;
  final bool connected;
  final Color connectedColor;
  final Color disconnectedColor;
  final VoidCallback onTap;

  const _DeviceSelectTile({
    required this.device,
    required this.selected,
    required this.connected,
    required this.connectedColor,
    required this.disconnectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final statusColor = connected ? connectedColor : disconnectedColor;

    return ListTile(
      leading: Icon(
        connected ? Icons.memory : Icons.memory_outlined,
        color: connected ? cs.primary : cs.onSurfaceVariant,
      ),
      title: Text(device.name),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            connected ? l10n.statusConnected : l10n.statusDisconnected,
            style: tt.bodySmall!.copyWith(color: statusColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              device.address,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
      trailing: selected ? Icon(Icons.check, color: cs.primary) : null,
      onTap: onTap,
    );
  }
}
