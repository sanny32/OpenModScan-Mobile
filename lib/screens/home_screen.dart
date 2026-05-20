import 'package:flutter/material.dart';
import '../models/device_info.dart';
import '../models/register_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_status_chip.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const device = mockDevice;

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'OpenModScan',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: ' Mobile',
                style: TextStyle(
                    color: Color(0xFF1976D2),
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
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
              side: const BorderSide(color: Colors.red),
              foregroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Disconnect'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.download_outlined,
                  title: 'Read Registers',
                  subtitle: 'Read holding/input\nregisters',
                  color: const Color(0xFF1976D2),
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.upload_outlined,
                  title: 'Write Value',
                  subtitle: 'Write single/multiple\nregisters',
                  color: const Color(0xFF4CAF50),
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Last Values',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {},
                child: const Text('View All >',
                    style: TextStyle(color: Color(0xFF1976D2))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...mockRegisters
              .take(5)
              .map((r) => _LastValueRow(entry: r)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.list_alt, color: Colors.purple, size: 24),
              ),
              title: const Text('Open Log',
                  style: TextStyle(
                      color: Colors.purple, fontWeight: FontWeight.bold)),
              subtitle: const Text('View communication log',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.memory, color: Color(0xFF1976D2), size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(device.address,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(device.protocolName,
                      style: const TextStyle(
                          color: Color(0xFF1976D2), fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.wifi, color: Color(0xFF4CAF50), size: 22),
                const SizedBox(height: 4),
                Text('ID: ${device.unitId}',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12)),
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
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(subtitle,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 11),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text('${entry.address}',
                style:
                    const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Expanded(
            child: Text(entry.value,
                style: const TextStyle(
                    color: AppTheme.valueColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
          Text(entry.typeName,
              style:
                  const TextStyle(color: AppTheme.typeColor, fontSize: 13)),
        ],
      ),
    );
  }
}
