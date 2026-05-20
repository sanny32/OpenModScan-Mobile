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
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Devices',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _openConnect,
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search devices',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.grey, size: 20),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            // List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 72),
                children: [
                  _sectionHeader('Saved connections'),
                  ..._filtered.map((d) => _DeviceCard(device: d, onTap: () {})),
                  _sectionHeader('Discovered devices'),
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

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(title,
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );
}

class _DeviceCard extends StatelessWidget {
  final _SavedDevice device;
  final VoidCallback onTap;
  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                      ? AppTheme.qualityGood
                      : Colors.grey.shade700,
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(Icons.memory, color: Color(0xFF1976D2), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(device.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        if (device.lastUsed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Last used',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(device.address,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13)),
                    Text('${device.protocol} • ID: ${device.unitId}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.grey),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.wifi, color: Color(0xFF1976D2), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('$protocol • ID: $unitId',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onConnect,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1976D2)),
                foregroundColor: const Color(0xFF1976D2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SafeArea(
        top: false,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.wifi_find),
          label: const Text('Scan network'),
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: Color(0xFF1976D2)),
            foregroundColor: const Color(0xFF1976D2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
