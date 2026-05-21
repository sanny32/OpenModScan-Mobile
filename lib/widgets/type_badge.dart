import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Color typeColor(BuildContext context, String type) {
  final cs = Theme.of(context).colorScheme;
  final appColors = Theme.of(context).extension<AppColors>()!;
  switch (type) {
    case 'UInt16':
    case 'UInt32':
    case 'UInt64':
      return cs.primary;
    case 'Int16':
    case 'Int32':
    case 'Int64':
      return appColors.connectedColor;
    case 'Float32':
    case 'Float64':
      return appColors.warningColor;
    case 'Hex':
      return appColors.openLogColor;
    case 'Binary':
      return appColors.warningColor;
    default:
      return cs.onSurfaceVariant;
  }
}

String typeAbbrev(String type) {
  switch (type) {
    case 'UInt16':
      return 'U16';
    case 'Int16':
      return 'I16';
    case 'UInt32':
      return 'U32';
    case 'Int32':
      return 'I32';
    case 'UInt64':
      return 'U64';
    case 'Int64':
      return 'I64';
    case 'Float32':
      return 'F32';
    case 'Float64':
      return 'F64';
    case 'Hex':
      return 'HEX';
    case 'Binary':
      return 'BIN';
    default:
      return type.length > 4
          ? type.substring(0, 4).toUpperCase()
          : type.toUpperCase();
  }
}

class TypeBadge extends StatelessWidget {
  final String type;
  const TypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = typeColor(context, type);
    return Container(
      width: 38,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        typeAbbrev(type),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
