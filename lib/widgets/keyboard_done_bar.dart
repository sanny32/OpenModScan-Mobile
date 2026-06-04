import 'package:flutter/material.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import '../l10n/l10n.dart';

/// Height of the "Done" accessory bar above the keyboard. Add this to the
/// bottom padding of content pinned to the keyboard top (e.g. a button anchored
/// above the keyboard) so the bar doesn't overlap it.
const double kKeyboardDoneBarHeight = 45;

/// A text field bound to the keyboard accessory bar: its [focusNode] plus the
/// [label] shown on the left of the bar while that field is focused.
class KeyboardBarField {
  final FocusNode focusNode;
  final String label;
  const KeyboardBarField(this.focusNode, this.label);
}

/// Builds the native-style "Done" accessory bar config: the field's label on
/// the left, a green "Done" + chevron on the right. Works on iOS and Android.
///
/// Wrap a screen body in `KeyboardActions(disableScroll: true, config: ...)`
/// using this, passing one [KeyboardBarField] per text field. For a single
/// field, [KeyboardDoneField] is more convenient.
KeyboardActionsConfig buildKeyboardDoneConfig(
  BuildContext context,
  List<KeyboardBarField> fields,
) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return KeyboardActionsConfig(
    keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
    keyboardBarColor: cs.surface,
    keyboardSeparatorColor: isDark ? Colors.white24 : Colors.black12,
    nextFocus: false,
    actions: [
      for (final field in fields)
        KeyboardActionsItem(
          focusNode: field.focusNode,
          displayArrows: false,
          displayDoneButton: false,
          toolbarAlignment: MainAxisAlignment.spaceBetween,
          toolbarButtons: [
            (_) => _KeyboardBarLabel(label: field.label),
            (node) => _KeyboardDoneButton(focusNode: node),
          ],
        ),
    ],
  );
}

/// Convenience wrapper that adds the "Done" accessory bar to a single text
/// field, managing its own [FocusNode]. Use [builder] to attach the provided
/// node to your `TextField`/`TextFormField`.
///
/// `KeyboardActions(disableScroll: true)` returns its child unchanged, so this
/// adds no layout — drop it around any field anywhere (columns, lists, sheets).
class KeyboardDoneField extends StatefulWidget {
  final String label;
  final FocusNode? focusNode;
  final Widget Function(FocusNode focusNode) builder;

  const KeyboardDoneField({
    super.key,
    required this.label,
    this.focusNode,
    required this.builder,
  });

  @override
  State<KeyboardDoneField> createState() => _KeyboardDoneFieldState();
}

class _KeyboardDoneFieldState extends State<KeyboardDoneField> {
  late final FocusNode _ownedNode;

  FocusNode get _node => widget.focusNode ?? _ownedNode;

  @override
  void initState() {
    super.initState();
    _ownedNode = FocusNode();
  }

  @override
  void dispose() {
    _ownedNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardActions(
      disableScroll: true,
      config: buildKeyboardDoneConfig(context, [
        KeyboardBarField(_node, widget.label),
      ]),
      child: widget.builder(_node),
    );
  }
}

/// Left-aligned grey field label inside the keyboard accessory bar.
class _KeyboardBarLabel extends StatelessWidget {
  final String label;
  const _KeyboardBarLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        label,
        style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// Right-aligned green "Done" button (text + chevron) that dismisses the
/// keyboard.
class _KeyboardDoneButton extends StatelessWidget {
  final FocusNode focusNode;
  const _KeyboardDoneButton({required this.focusNode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => focusNode.unfocus(),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.done,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}
