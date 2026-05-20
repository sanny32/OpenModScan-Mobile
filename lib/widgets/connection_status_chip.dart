import 'package:flutter/material.dart';

class ConnectionStatusChip extends StatelessWidget {
  final bool connected;

  const ConnectionStatusChip({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    final color = connected ? const Color(0xFF4CAF50) : Colors.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          connected ? 'Connected' : 'Disconnected',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
