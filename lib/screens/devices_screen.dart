import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/device_info.dart';
import '../services/device_repository.dart';
import '../theme/app_theme.dart';
import 'device_form_sheet.dart';
import 'device_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  String _search = '';
  bool _loading = true;
  late List<DeviceInfo> _devices;

  @override
  void initState() {
    super.initState();
    _devices = [];
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final saved = await DeviceRepository.instance.load();
    if (mounted) {
      setState(() {
        _devices = saved.isEmpty ? List.of(mockDevices) : saved;
        _loading = false;
      });
    }
  }

  List<DeviceInfo> get _filtered => _devices
      .where((d) =>
          _search.isEmpty ||
          d.name.toLowerCase().contains(_search.toLowerCase()) ||
          d.address.contains(_search))
      .toList();

  void _openConnect() async {
    final device = await showModalBottomSheet<DeviceInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DeviceFormSheet(),
    );
    if (device != null && mounted) {
      setState(() => _devices.add(device));
      DeviceRepository.instance.save(_devices);
    }
  }

  void _deleteDevice(DeviceInfo device) {
    final index = _devices.indexOf(device);
    setState(() => _devices.remove(device));
    DeviceRepository.instance.save(_devices);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
      SnackBar(
        content: Text(context.l10n.deviceDeleted),
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () {
            setState(() => _devices.insert(index, device));
            DeviceRepository.instance.save(_devices);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return ScaffoldMessenger(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.navDevices, style: tt.headlineMedium),
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
                  hintText: l10n.devicesSearch,
                  prefixIcon: Icon(Icons.search,
                      color: cs.onSurfaceVariant, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _sectionHeader(context, l10n.devicesSavedConnections),
                  ..._filtered.map((d) => Dismissible(
                        key: ValueKey(d),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteDevice(d),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.delete_outline,
                              color: cs.onError, size: 26),
                        ),
                        child: _DeviceCard(
                          device: d,
                          onTap: () => Navigator.push<DeviceInfo>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DeviceScreen(device: d)),
                          ).then((updated) {
                            if (updated != null) {
                              final idx = _devices.indexOf(d);
                              if (idx != -1) {
                                setState(() => _devices[idx] = updated);
                                DeviceRepository.instance.save(_devices);
                              }
                            }
                          }),
                        ),
                      )),
                  _sectionHeader(context, l10n.devicesDiscoveredDevices),
                  _DiscoveredCard(
                    address: '192.168.0.50:502',
                    protocol: 'Modbus TCP',
                    unitId: 1,
                    onConnect: _openConnect,
                  ),
                ],
              ),
            ),
          _ScanButton(onTap: () {}),
            ],
          ),
        ),
      ),
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
  final DeviceInfo device;
  final VoidCallback onTap;
  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
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
                            child: Text(l10n.devicesLastUsed,
                                style: tt.labelSmall!
                                    .copyWith(color: cs.onPrimary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(device.address,
                        style: tt.bodyMedium!
                            .copyWith(color: cs.onSurfaceVariant)),
                    Text(
                      l10n.protocolAndUnitId(device.protocolName, device.unitId),
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
    final l10n = context.l10n;
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
                  Text(
                    l10n.protocolAndUnitId(protocol, unitId),
                    style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                  ),
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
              child: Text(l10n.devicesConnect),
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
    final l10n = context.l10n;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SafeArea(
        top: false,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.wifi_find),
          label: Text(l10n.devicesScanNetwork),
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
