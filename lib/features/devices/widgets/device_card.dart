import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/device_info.dart';
import '../../../theme/app_theme.dart';

class DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final bool connected;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.connected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>();
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: connected
                      ? (appColors?.connectedColor ?? cs.primary)
                      : cs.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
              Icon(Icons.memory, color: cs.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: tt.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      device.address,
                      style: tt.bodyMedium!.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      l10n.protocolAndUnitId(
                        device.protocolName,
                        device.unitId,
                      ),
                      style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
