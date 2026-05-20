import 'package:flutter/material.dart';
import '../models/device_info.dart';

class ConnectionInfoBar extends StatelessWidget {
  final DeviceInfo device;

  const ConnectionInfoBar({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.dns_outlined, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text(device.address,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(width: 10),
          _vDivider(),
          const SizedBox(width: 10),
          Text(device.protocolName,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(width: 10),
          _vDivider(),
          const SizedBox(width: 10),
          Text('ID: ${device.unitId}',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 14, color: Colors.grey.shade700);
}
