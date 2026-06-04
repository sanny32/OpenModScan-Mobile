import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/discovered_device.dart';
import '../../theme/app_dimens.dart';
import 'devices_controller.dart';
import 'widgets/scan_panel.dart';

class DiscoveredDevicesScreen extends StatefulWidget {
  final DevicesController controller;
  final Future<void> Function(DiscoveredDevice) onConnect;

  const DiscoveredDevicesScreen({
    super.key,
    required this.controller,
    required this.onConnect,
  });

  @override
  State<DiscoveredDevicesScreen> createState() =>
      _DiscoveredDevicesScreenState();
}

class _DiscoveredDevicesScreenState extends State<DiscoveredDevicesScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  Future<void> _connect(DiscoveredDevice device) async {
    Navigator.of(context).pop();
    await widget.onConnect(device);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devices = widget.controller.discoveredDevices;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesDiscoveredTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            8,
            AppSpacing.screenGutter,
            16,
          ),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < devices.length; i++)
                    DiscoveredDeviceRow(
                      device: devices[i],
                      onConnect: _connect,
                      showBottomDivider: i < devices.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
