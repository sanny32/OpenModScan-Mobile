import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';
import '../../models/register_entry.dart';
import '../../theme/app_theme.dart';
import '../../utils/modbus_format.dart';
import '../../widgets/type_badge.dart';

String _typeDescription(String type) {
  switch (type) {
    case 'UInt16':
      return 'UInt16 (16 bit)';
    case 'Int16':
      return 'Int16 (16 bit)';
    case 'UInt32':
      return 'UInt32 (32 bit)';
    case 'Int32':
      return 'Int32 (32 bit)';
    case 'UInt64':
      return 'UInt64 (64 bit)';
    case 'Int64':
      return 'Int64 (64 bit)';
    case 'Float32':
      return 'Float32 (IEEE 754)';
    case 'Float64':
      return 'Float64 (IEEE 754)';
    case 'Hex':
      return 'Hex';
    case 'Binary':
      return 'Binary';
    default:
      return type;
  }
}

String _displayTimestamp(String timestamp) {
  if (RegExp(r'\.\d+$').hasMatch(timestamp)) return timestamp;
  return '$timestamp.000';
}

class RegisterDetailScreen extends StatefulWidget {
  final RegisterEntry entry;
  final bool canWrite;
  final void Function(String typeName, String? comment)? onSaved;
  final void Function(String newValue)? onValueWritten;

  const RegisterDetailScreen({
    super.key,
    required this.entry,
    this.canWrite = true,
    this.onSaved,
    this.onValueWritten,
  });

  @override
  State<RegisterDetailScreen> createState() => _RegisterDetailScreenState();
}

class _RegisterDetailScreenState extends State<RegisterDetailScreen> {
  late String _selectedType;
  late TextEditingController _commentCtrl;
  late String _registerOrder;
  late String _byteOrder;

  @override
  void initState() {
    super.initState();
    final settings = AppSettings.instance;
    _selectedType = kRegisterTypes.contains(widget.entry.typeName)
        ? widget.entry.typeName
        : kRegisterTypes.first;
    _registerOrder = AppSettings.registerOrders.contains(settings.registerOrder)
        ? settings.registerOrder
        : AppSettings.registerOrders.first;
    _byteOrder = AppSettings.byteOrders.contains(settings.byteOrder)
        ? settings.byteOrder
        : AppSettings.byteOrders.first;
    _commentCtrl = TextEditingController(text: widget.entry.comment ?? '');
    AppSettings.instance.showTypeBadgesNotifier.addListener(_onSettingChanged);
    AppSettings.instance.showLastValuesNotifier.addListener(_onSettingChanged);
  }

  void _onSettingChanged() => setState(() {});

  String _displayPreviousValue(String raw) {
    final rawInt = int.tryParse(raw);
    if (rawInt == null) return raw;
    return computeDisplayValue(
      widget.entry.address,
      _selectedType,
      {widget.entry.address: rawInt},
      registerOrder: _registerOrder,
      byteOrder: _byteOrder,
    );
  }

  void _saveComment(String? value) {
    _commentCtrl.text = value ?? '';
    setState(() {});
    final comment = _commentCtrl.text.trim();
    widget.onSaved?.call(_selectedType, comment.isEmpty ? null : comment);
  }

  void _selectType(String type) {
    setState(() => _selectedType = type);
    final comment = _commentCtrl.text.trim();
    widget.onSaved?.call(type, comment.isEmpty ? null : comment);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    AppSettings.instance.showTypeBadgesNotifier.removeListener(
      _onSettingChanged,
    );
    AppSettings.instance.showLastValuesNotifier.removeListener(
      _onSettingChanged,
    );
    super.dispose();
  }

  bool get _hasRawWords => widget.entry.rawWords.isNotEmpty;

  List<_Interpretation> _buildInterpretations() {
    final addr = widget.entry.address;
    final words = widget.entry.rawWords;
    String v(String type) => computeDisplayValue(
      addr,
      type,
      words,
      registerOrder: _registerOrder,
      byteOrder: _byteOrder,
    );
    return [for (final type in kRegisterTypes) _Interpretation(type, v(type))];
  }

  String _displayValueForType(String type) {
    if (!_hasRawWords) return widget.entry.displayValue ?? widget.entry.value;
    for (final interp in _buildInterpretations()) {
      if (interp.typeName == type) return interp.value;
    }
    return widget.entry.value;
  }

  Future<void> _showWriteDialog() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ctrl = TextEditingController(text: widget.entry.value);
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: Text(l10n.writeRegisterTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${l10n.colAddress}: ',
                    style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    '${widget.entry.address}',
                    style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${l10n.colValue}: ',
                    style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    widget.entry.value,
                    style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (widget.entry.previousValue != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '← ${widget.entry.previousValue}',
                      style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.labelNewValue,
                  errorText: error,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) {
                  if (error != null) setInnerState(() => error = null);
                },
                onSubmitted: (_) =>
                    _doWrite(ctx, ctrl, l10n, setInnerState, (e) => error = e),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () =>
                  _doWrite(ctx, ctrl, l10n, setInnerState, (e) => error = e),
              child: Text(l10n.btnWrite),
            ),
          ],
        ),
      ),
    );
  }

  void _doWrite(
    BuildContext ctx,
    TextEditingController ctrl,
    dynamic l10n,
    StateSetter setInnerState,
    void Function(String?) setError,
  ) {
    final raw = int.tryParse(ctrl.text);
    if (raw == null || raw < 0 || raw > 65535) {
      setInnerState(() => setError(l10n.writeValueRange));
      return;
    }
    // TODO: perform actual Modbus write.
    widget.onValueWritten?.call(ctrl.text);
    Navigator.pop(ctx);
  }

  Future<void> _showDataLayoutSheet() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) {
          void selectRegisterOrder(String value) {
            setState(() {
              _registerOrder = value;
            });
            setInnerState(() {});
          }

          void selectByteOrder(String value) {
            setState(() {
              _byteOrder = value;
            });
            setInnerState(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data layout',
                    style: tt.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LayoutChoiceSection(
                    label: l10n.labelRegisterOrder,
                    icon: Icons.swap_vert_rounded,
                    options: AppSettings.registerOrders,
                    value: _registerOrder,
                    onSelected: selectRegisterOrder,
                  ),
                  const SizedBox(height: 14),
                  _LayoutChoiceSection(
                    label: l10n.labelByteOrder,
                    icon: Icons.swap_horiz_rounded,
                    options: AppSettings.byteOrders,
                    value: _byteOrder,
                    onSelected: selectByteOrder,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final entry = widget.entry;
    final currentValue = _displayValueForType(_selectedType);
    final showPreviousValue =
        entry.previousValue != null &&
        AppSettings.instance.showLastValuesNotifier.value;

    return Scaffold(
      backgroundColor: cs.surfaceContainerHighest,
      appBar: AppBar(
        toolbarHeight: 56,
        title: Text(
          '${entry.address}',
          style: tt.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            iconSize: 24,
            onPressed: () {},
          ),
          const SizedBox(width: 2),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OutlinedCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT VALUE',
                        style: tt.titleSmall!.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (entry.timestamp != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.schedule_rounded,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (entry.date != null)
                                  Text(
                                    entry.date!,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: tt.bodyLarge!.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12,
                                      height: 1,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: entry.date != null ? 5 : 0,
                                  ),
                                  child: Text(
                                    _displayTimestamp(entry.timestamp!),
                                    maxLines: 1,
                                    softWrap: false,
                                    style: tt.bodyLarge!.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 13,
                                      height: 1,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          currentValue,
                          maxLines: 1,
                          softWrap: false,
                          style: tt.displaySmall?.copyWith(
                            color: appColors.valueColor,
                            fontSize: 42,
                            height: 0.95,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showPreviousValue) ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, thickness: 1.2, color: cs.outline),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          l10n.labelPreviousValue,
                          style: tt.bodySmall!.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 15,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _displayPreviousValue(entry.previousValue!),
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium!.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionHeader(l10n.colComment.toUpperCase()),
            const SizedBox(height: 7),
            _CommentCard(
              comment: _commentCtrl.text.isEmpty ? null : _commentCtrl.text,
              onChanged: _saveComment,
            ),
            if (_hasRawWords) ...[
              const SizedBox(height: 18),
              _InterpretationsHeader(
                title: l10n.labelInterpretations,
                registerOrder: _registerOrder,
                byteOrder: _byteOrder,
                onTap: _showDataLayoutSheet,
              ),
              const SizedBox(height: 7),
              _OutlinedCard(
                padding: EdgeInsets.zero,
                clip: true,
                child: Column(
                  children: () {
                    final items = _buildInterpretations();
                    return List.generate(items.length, (i) {
                      final interp = items[i];
                      final isCurrent = interp.typeName == _selectedType;
                      return _InterpretationRow(
                        interpretation: interp,
                        selected: isCurrent,
                        showDivider: i > 0,
                        onTap: isCurrent
                            ? null
                            : () => _selectType(interp.typeName),
                      );
                    });
                  }(),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: widget.canWrite
          ? FloatingActionButton.extended(
              onPressed: _showWriteDialog,
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                l10n.writeValue,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }
}

class _InterpretationsHeader extends StatelessWidget {
  final String title;
  final String registerOrder;
  final String byteOrder;
  final VoidCallback onTap;

  const _InterpretationsHeader({
    required this.title,
    required this.registerOrder,
    required this.byteOrder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(child: _SectionHeader(title)),
        Material(
          color: cs.surface.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$registerOrder · $byteOrder',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LayoutChoiceSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> options;
  final String value;
  final ValueChanged<String> onSelected;

  const _LayoutChoiceSection({
    required this.label,
    required this.icon,
    required this.options,
    required this.value,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: options
              .map(
                (option) =>
                    ButtonSegment<String>(value: option, label: Text(option)),
              )
              .toList(),
          selected: {value},
          onSelectionChanged: (selection) => onSelected(selection.first),
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return cs.primary;
              }
              return cs.surface;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return cs.onPrimary;
              }
              return cs.onSurface;
            }),
            side: WidgetStatePropertyAll(
              BorderSide(color: cs.outline.withValues(alpha: 0.55)),
            ),
            textStyle: WidgetStatePropertyAll(
              tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlinedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool clip;

  const _OutlinedCard({
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
        borderRadius: BorderRadius.circular(10),
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

class _InterpretationRow extends StatelessWidget {
  final _Interpretation interpretation;
  final bool selected;
  final bool showDivider;
  final VoidCallback? onTap;

  const _InterpretationRow({
    required this.interpretation,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider)
          Divider(height: 1, color: cs.outline.withValues(alpha: 0.7)),
        Material(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surface.withValues(alpha: 0),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 21,
                      color: selected
                          ? cs.primary
                          : cs.onSurfaceVariant.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 12),
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          AppSettings.instance.showTypeBadgesNotifier,
                      builder: (_, showBadges, _) => showBadges
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TypeBadge(type: interpretation.typeName),
                                const SizedBox(width: 12),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: _TypeNameText(
                        type: interpretation.typeName,
                        isSelected: selected,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          interpretation.value,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: selected
                                ? appColors.valueColor
                                : cs.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeNameText extends StatelessWidget {
  final String type;
  final bool isSelected;

  const _TypeNameText({required this.type, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final description = _typeDescription(type);
    final match = RegExp(r'^(.*?) (\(.+\))$').firstMatch(description);
    final main = match?.group(1) ?? description;
    final suffix = match?.group(2);
    final color = isSelected ? cs.primary : cs.onSurface;
    const size = 14.0;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: main,
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          if (suffix != null)
            TextSpan(
              text: ' $suffix',
              style: TextStyle(
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                fontSize: size,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

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

class _Interpretation {
  final String typeName;
  final String value;
  const _Interpretation(this.typeName, this.value);
}

class _CommentCard extends StatelessWidget {
  final String? comment;
  final ValueChanged<String?> onChanged;

  const _CommentCard({required this.comment, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasComment = comment != null && comment!.isNotEmpty;
    return _OutlinedCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) {
            final ctrl = TextEditingController(text: comment ?? '');
            return _CommentDialog(ctrl: ctrl, onSaved: onChanged);
          },
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasComment ? comment! : context.l10n.commentHint,
                  style: tt.bodyLarge?.copyWith(
                    color: hasComment ? cs.onSurface : cs.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentDialog extends StatefulWidget {
  final TextEditingController ctrl;
  final ValueChanged<String?> onSaved;

  const _CommentDialog({required this.ctrl, required this.onSaved});

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  @override
  void dispose() {
    widget.ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.colComment),
      content: TextField(
        controller: widget.ctrl,
        autofocus: true,
        maxLines: null,
        decoration: InputDecoration(
          hintText: l10n.commentHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            final text = widget.ctrl.text.trim();
            widget.onSaved(text.isEmpty ? null : text);
            Navigator.pop(context);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
