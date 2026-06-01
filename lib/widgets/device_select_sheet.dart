import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/device_info.dart';

/// Shared bottom sheet for switching the active device. Used by the Registers
/// and Traffic screens so device selection looks and behaves the same way.
///
/// Returns the chosen device id, or `null` if the sheet was dismissed.
Future<String?> showDeviceSelectSheet(
  BuildContext context, {
  required List<DeviceInfo> devices,
  required String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      final l10n = ctx.l10n;
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
            for (final device in devices)
              ListTile(
                leading: Icon(Icons.memory, color: cs.onSurfaceVariant),
                title: Text(device.name),
                trailing: device.id == selectedId
                    ? Icon(Icons.check, color: cs.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, device.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
