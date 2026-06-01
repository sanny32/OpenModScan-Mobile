import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// Presents a single-choice bottom sheet for a setting and invokes
/// [onSelected] with the chosen raw option.
Future<void> showSettingChoiceSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String selected,
  String Function(String)? optionLabel,
  required FutureOr<void> Function(String) onSelected,
}) async {
  final cs = Theme.of(context).colorScheme;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
          ),
          for (final option in options)
            ListTile(
              title: Text(optionLabel?.call(option) ?? option),
              trailing: option == selected
                  ? Icon(Icons.check, color: cs.primary)
                  : null,
              onTap: () async {
                Navigator.pop(ctx);
                await onSelected(option);
              },
            ),
        ],
      ),
    ),
  );
}

/// Presents a numeric text sheet, clamping the parsed value to [min]/[max]
/// before forwarding it to [onSubmitted].
Future<void> showSettingNumberSheet(
  BuildContext context, {
  required String title,
  required int initialValue,
  required int min,
  required int max,
  required FutureOr<void> Function(int) onSubmitted,
}) async {
  await showSettingTextSheet(
    context,
    title: title,
    initialValue: '$initialValue',
    keyboardType: TextInputType.number,
    onSubmitted: (value) async {
      final parsed = int.tryParse(value) ?? initialValue;
      await onSubmitted(parsed.clamp(min, max).toInt());
    },
  );
}

/// Presents a free-form text sheet for a single setting value.
Future<void> showSettingTextSheet(
  BuildContext context, {
  required String title,
  required String initialValue,
  required TextInputType keyboardType,
  required FutureOr<void> Function(String) onSubmitted,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => TextSettingSheet(
      title: title,
      initialValue: initialValue,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
    ),
  );
}

/// Presents a start/end range sheet, clamping both bounds to [min]/[max].
Future<void> showSettingRangeSheet(
  BuildContext context, {
  required String title,
  required int startValue,
  required int endValue,
  required int min,
  required int max,
  required FutureOr<void> Function(int, int) onSubmitted,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => RangeSettingSheet(
      title: title,
      startValue: startValue,
      endValue: endValue,
      min: min,
      max: max,
      onSubmitted: onSubmitted,
    ),
  );
}

class TextSettingSheet extends StatefulWidget {
  final String title;
  final String initialValue;
  final TextInputType keyboardType;
  final FutureOr<void> Function(String) onSubmitted;

  const TextSettingSheet({
    super.key,
    required this.title,
    required this.initialValue,
    required this.keyboardType,
    required this.onSubmitted,
  });

  @override
  State<TextSettingSheet> createState() => _TextSettingSheetState();
}

class _TextSettingSheetState extends State<TextSettingSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingSheetFrame(
      title: widget.title,
      onSave: () async {
        final value = _controller.text.trim();
        Navigator.pop(context);
        await widget.onSubmitted(value);
      },
      child: TextField(
        controller: _controller,
        keyboardType: widget.keyboardType,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) async {
          final value = _controller.text.trim();
          Navigator.pop(context);
          await widget.onSubmitted(value);
        },
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

class _SettingSheetFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final FutureOr<void> Function() onSave;

  const _SettingSheetFrame({
    required this.title,
    required this.child,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withAlpha(102),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(title, style: tt.titleLarge),
                const SizedBox(height: 14),
                child,
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async => onSave(),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(context.l10n.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RangeSettingSheet extends StatefulWidget {
  final String title;
  final int startValue;
  final int endValue;
  final int min;
  final int max;
  final FutureOr<void> Function(int, int) onSubmitted;

  const RangeSettingSheet({
    super.key,
    required this.title,
    required this.startValue,
    required this.endValue,
    required this.min,
    required this.max,
    required this.onSubmitted,
  });

  @override
  State<RangeSettingSheet> createState() => _RangeSettingSheetState();
}

class _RangeSettingSheetState extends State<RangeSettingSheet> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: '${widget.startValue}');
    _endController = TextEditingController(text: '${widget.endValue}');
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingSheetFrame(
      title: widget.title,
      onSave: () async {
        final start = int.tryParse(_startController.text) ?? widget.startValue;
        final end = int.tryParse(_endController.text) ?? widget.endValue;
        Navigator.pop(context);
        await widget.onSubmitted(
          start.clamp(widget.min, widget.max).toInt(),
          end.clamp(widget.min, widget.max).toInt(),
        );
      },
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _startController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.settingsRangeStart,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _endController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.settingsRangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
