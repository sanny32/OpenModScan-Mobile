import 'package:flutter/material.dart';

class DevicesSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const DevicesSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: tt.labelLarge!.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
