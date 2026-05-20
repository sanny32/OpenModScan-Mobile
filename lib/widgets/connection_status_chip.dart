import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ConnectionStatusChip extends StatelessWidget {
  final bool connected;

  const ConnectionStatusChip({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final tt = Theme.of(context).textTheme;
    final color =
        connected ? appColors.connectedColor : appColors.disconnectedColor;
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
          style: tt.bodySmall!.copyWith(color: color),
        ),
      ],
    );
  }
}
