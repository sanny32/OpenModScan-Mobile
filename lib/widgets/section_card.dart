import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// Uppercase section label used above cards (e.g. "CURRENT VALUE").
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 1),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall!.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// White surface card with a subtle border and shadow. Shared by detail and
/// write screens so they read as the same visual family.
class OutlinedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool clip;

  const OutlinedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.clip = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: AppRadii.lgAll,
        border: Border.all(
          color: cs.outline.withValues(alpha: isDark ? 0.7 : 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: isDark ? 0.16 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
