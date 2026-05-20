import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'connect_device_sheet.dart';

class _SavedDevice {
  final String name;
  final String address;
  final String protocol;
  final int unitId;
  final bool connected;
  final bool lastUsed;

  const _SavedDevice({
    required this.name,
    required this.address,
    required this.protocol,
    required this.unitId,
    this.connected = false,
    this.lastUsed = false,
  });
}

const _mockSaved = [
  _SavedDevice(name: 'PLC #1', address: '192.168.0.10:502', protocol: 'Modbus TCP', unitId: 1, connected: true, lastUsed: true),
  _SavedDevice(name: 'Water Pump Station', address: '192.168.0.20:502', protocol: 'Modbus TCP', unitId: 1),
  _SavedDevice(name: 'HVAC Controller', address: '192.168.0.30:502', protocol: 'Modbus TCP', unitId: 1),
  _SavedDevice(name: 'Energy Meter', address: '192.168.0.40:502', protocol: 'Modbus TCP', unitId: 1),
  _SavedDevice(name: 'Boiler Control', address: '10.0.0.15:502', protocol: 'Modbus TCP', unitId: 2),
];

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  String _search = '';

  List<_SavedDevice> get _filtered => _mockSaved
      .where((d) =>
          _search.isEmpty ||
          d.name.toLowerCase().contains(_search.toLowerCase()) ||
          d.address.contains(_search))
      .toList();

  void _openConnect() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ConnectDeviceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Devices', style: tt.headlineMedium),
                  ),
                  IconButton(
                      icon: const Icon(Icons.add), onPressed: _openConnect),
                  IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () {}),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search devices',
                  prefixIcon: Icon(Icons.search,
                      color: cs.onSurfaceVariant, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 72),
                children: [
                  _sectionHeader(context, 'Saved connections'),
                  ..._filtered
                      .map((d) => _DeviceCard(device: d, onTap: () {})),
                  _sectionHeader(context, 'Discovered devices'),
                  _DiscoveredCard(
                    address: '192.168.0.50:502',
                    protocol: 'Modbus TCP',
                    unitId: 1,
                    onConnect: _openConnect,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _ScanButton(onTap: () {}),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(title,
          style: tt.labelLarge!.copyWith(color: cs.onSurfaceVariant)),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final _SavedDevice device;
  final VoidCallback onTap;
  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
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
                  color: device.connected
                      ? appColors.connectedColor
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(device.name, style: tt.titleSmall),
                        ),
                        if (device.lastUsed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Last used',
                                style: tt.labelSmall!
                                    .copyWith(color: cs.onPrimary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(device.address,
                        style: tt.bodyMedium!
                            .copyWith(color: cs.onSurfaceVariant)),
                    Text('${device.protocol} • ID: ${device.unitId}',
                        style: tt.bodySmall!
                            .copyWith(color: cs.onSurfaceVariant)),
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

class _DiscoveredCard extends StatelessWidget {
  final String address;
  final String protocol;
  final int unitId;
  final VoidCallback onConnect;

  const _DiscoveredCard({
    required this.address,
    required this.protocol,
    required this.unitId,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.wifi, color: cs.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address, style: tt.titleSmall),
                  Text('$protocol • ID: $unitId',
                      style:
                          tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onConnect,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.primary),
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SafeArea(
        top: false,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.wifi_find),
          label: const Text('Scan network'),
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: BorderSide(color: cs.primary),
            foregroundColor: cs.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
