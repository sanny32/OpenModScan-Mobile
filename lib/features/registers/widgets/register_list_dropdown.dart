import 'package:flutter/material.dart';

class RegisterListDropdown extends StatelessWidget {
  final List<String> names;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onAdd;

  const RegisterListDropdown({
    super.key,
    required this.names,
    required this.activeIndex,
    required this.onChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 100),
        child: SizedBox(
          height: 36,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: activeIndex,
                isDense: true,
                isExpanded: true,
                dropdownColor: cs.surfaceContainerHighest,
                style: tt.bodyMedium!.copyWith(color: cs.onSurface),
                items: [
                  for (var i = 0; i < names.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        names[i],
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  DropdownMenuItem(
                    value: -1,
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          'New List',
                          style: tt.bodyMedium!.copyWith(color: cs.primary),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  if (v == -1) {
                    onAdd();
                  } else {
                    onChanged(v);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
