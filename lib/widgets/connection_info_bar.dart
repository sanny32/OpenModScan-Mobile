import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/device_info.dart';

class ConnectionInfoBar extends StatelessWidget {
  final DeviceInfo device;

  const ConnectionInfoBar({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Container(
      color: cs.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.dns_outlined, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(device.address, style: tt.bodyMedium),
          const SizedBox(width: 10),
          _vDivider(cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(device.protocolName, style: tt.bodyMedium),
          const SizedBox(width: 10),
          _vDivider(cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(l10n.unitId(device.unitId), style: tt.bodyMedium),
        ],
      ),
    );
  }

  Widget _vDivider(Color color) =>
      Container(width: 1, height: 14, color: color);
}
