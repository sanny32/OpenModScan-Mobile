import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/device_info.dart';
import '../models/register_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_status_chip.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const device = mockDevice;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
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
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConnectionStatusChip(connected: device.connected),
          const SizedBox(height: 12),
          _PlcCard(device: device),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error),
              foregroundColor: cs.error,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.disconnect),
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
                  onTap: () {},
                ),
              ),
            ],
          ),
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
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appColors.openLogColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.list_alt,
                    color: appColors.openLogColor, size: 24),
              ),
              title: Text(l10n.openLog,
                  style:
                      tt.titleSmall!.copyWith(color: appColors.openLogColor)),
              subtitle: Text(l10n.openLogSubtitle,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _PlcCard extends StatelessWidget {
  final DeviceInfo device;
  const _PlcCard({required this.device});

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
                Icon(Icons.wifi, color: appColors.connectedColor, size: 22),
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
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 38),
              const SizedBox(height: 8),
              Text(title,
                  style: tt.bodyLarge!
                      .copyWith(color: color, fontWeight: FontWeight.bold),
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
