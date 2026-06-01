import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/device_info.dart';

class ConnectionInfoBar extends StatelessWidget {
  final DeviceInfo device;
  final bool showDeviceName;

  const ConnectionInfoBar({
    super.key,
    required this.device,
    this.showDeviceName = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;

    Widget detailsRow() {
      return Row(
        children: [
          Flexible(child: _InfoText(device.address, style: tt.bodyMedium)),
          const SizedBox(width: 10),
          _vDivider(cs.onSurfaceVariant),
          const SizedBox(width: 10),
          _InfoText(device.protocolName, style: tt.bodyMedium),
          const SizedBox(width: 10),
          _vDivider(cs.onSurfaceVariant),
          const SizedBox(width: 10),
          _InfoText(l10n.unitId(device.unitId), style: tt.bodyMedium),
        ],
      );
    }

    return Container(
      color: cs.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: showDeviceName
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.dns_outlined,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _InfoText(
                        device.name,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                detailsRow(),
              ],
            )
          : Row(
              children: [
                Icon(Icons.dns_outlined, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(child: detailsRow()),
              ],
            ),
    );
  }

  Widget _vDivider(Color color) =>
      Container(width: 1, height: 14, color: color);
}

class _InfoText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _InfoText(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
