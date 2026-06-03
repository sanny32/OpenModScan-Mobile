import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';
import '../../models/register_entry.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_theme.dart';
import '../../utils/modbus_format.dart';
import '../../utils/value_input.dart';
import '../../widgets/app_test_keys.dart';
import '../../widgets/data_layout.dart';
import '../../widgets/error_feedback.dart';
import '../../widgets/section_card.dart';
import '../../widgets/type_badge.dart';
import 'register_runtime_value.dart';

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
  final Future<String?> Function(String newValue, String typeName)?
  onValueWritten;
  final Listenable? valuesListenable;
  final RegisterRuntimeValue? Function(int address)? liveValueAt;

  const RegisterDetailScreen({
    super.key,
    required this.entry,
    this.canWrite = true,
    this.onSaved,
    this.onValueWritten,
    this.valuesListenable,
    this.liveValueAt,
  });

  @override
  State<RegisterDetailScreen> createState() => _RegisterDetailScreenState();
}

class _RegisterDetailScreenState extends State<RegisterDetailScreen> {
  late String _selectedType;
  late TextEditingController _commentCtrl;
  late String _registerOrder;
  late String _byteOrder;
  late RegisterEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    final settings = AppSettings.instance;
    _selectedType = kRegisterTypes.contains(_entry.typeName)
        ? _entry.typeName
        : kRegisterTypes.first;
    _registerOrder = AppSettings.registerOrders.contains(settings.registerOrder)
        ? settings.registerOrder
        : AppSettings.registerOrders.first;
    _byteOrder = AppSettings.byteOrders.contains(settings.byteOrder)
        ? settings.byteOrder
        : AppSettings.byteOrders.first;
    _commentCtrl = TextEditingController(text: _entry.comment ?? '');
    AppSettings.instance.showTypeBadgesNotifier.addListener(_onSettingChanged);
    AppSettings.instance.showLastValuesNotifier.addListener(_onSettingChanged);
    widget.valuesListenable?.addListener(_refreshFromRuntime);
  }

  void _onSettingChanged() => setState(() {});

  /// Pulls the latest value for this register from the live runtime source so
  /// the screen reflects auto-refresh reads and writes while it is open.
  void _refreshFromRuntime() {
    final liveValueAt = widget.liveValueAt;
    if (liveValueAt == null) return;
    final runtime = liveValueAt(_entry.address);
    if (runtime == null) return;
    final rawWords = Map<int, int>.from(_entry.rawWords);
    final previousRawWords = Map<int, int>.from(_entry.previousRawWords);
    for (var j = 0; j <= 3; j++) {
      final word = liveValueAt(_entry.address + j);
      final parsed = word == null ? null : int.tryParse(word.value);
      if (parsed != null) rawWords[_entry.address + j] = parsed;
      final parsedPrev = word?.previous == null
          ? null
          : int.tryParse(word!.previous!);
      if (parsedPrev != null) previousRawWords[_entry.address + j] = parsedPrev;
    }
    setState(() {
      _entry = _entry.copyWith(
        value: runtime.value,
        previousValue: runtime.previous,
        valueState: RegisterValueState.received,
        timestamp: runtime.readAt == null
            ? null
            : formatModbusTime(runtime.readAt!),
        date: runtime.readAt == null ? null : formatModbusDate(runtime.readAt!),
        rawWords: rawWords,
        previousRawWords: previousRawWords,
      );
    });
  }

  String _displayPreviousValue(String raw) {
    if (_entry.previousRawWords.isNotEmpty) {
      return computeDisplayValue(
        _entry.address,
        _selectedType,
        _entry.previousRawWords,
        registerOrder: _registerOrder,
        byteOrder: _byteOrder,
      );
    }
    final rawInt = int.tryParse(raw);
    if (rawInt == null) return raw;
    return computeDisplayValue(
      _entry.address,
      _selectedType,
      {_entry.address: rawInt},
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
    if (widget.onSaved != null) {
      Navigator.maybePop(context);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    widget.valuesListenable?.removeListener(_refreshFromRuntime);
    AppSettings.instance.showTypeBadgesNotifier.removeListener(
      _onSettingChanged,
    );
    AppSettings.instance.showLastValuesNotifier.removeListener(
      _onSettingChanged,
    );
    super.dispose();
  }

  bool get _hasRawWords => _entry.rawWords.isNotEmpty;

  List<_Interpretation> _buildInterpretations() {
    final addr = _entry.address;
    final words = _entry.rawWords;
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
    if (!_hasRawWords) return _entry.displayValue ?? _entry.value;
    for (final interp in _buildInterpretations()) {
      if (interp.typeName == type) return interp.value;
    }
    return _entry.value;
  }

  Future<void> _showWriteDialog() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ctrl = TextEditingController(
      text: _displayValueForType(_selectedType),
    );
    String? error;
    var writing = false;

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
                    '${_entry.displayAddress ?? _entry.address}',
                    style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${l10n.writeDataType}: ',
                    style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    _selectedType,
                    style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: valueKeyboardTypeFor(_selectedType),
                decoration: InputDecoration(
                  labelText: l10n.labelNewValue,
                  errorText: error,
                  isDense: true,
                ),
                onChanged: (_) {
                  if (error != null) setInnerState(() => error = null);
                },
                onSubmitted: (_) {
                  if (!writing) {
                    _doWrite(
                      ctx,
                      ctrl,
                      l10n,
                      setInnerState,
                      (e) => error = e,
                      (value) => writing = value,
                    );
                  }
                },
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: writing ? null : () => Navigator.pop(ctx),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: writing
                          ? null
                          : () => _doWrite(
                              ctx,
                              ctrl,
                              l10n,
                              setInnerState,
                              (e) => error = e,
                              (value) => writing = value,
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        textStyle: tt.labelLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(l10n.btnWrite),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyWrittenValue(String newValue) {
    final now = DateTime.now();
    final previousRawWords = Map<int, int>.from(_entry.rawWords);
    final rawWords = Map<int, int>.from(_entry.rawWords);
    final intValue = int.tryParse(newValue);
    if (intValue != null) rawWords[_entry.address] = intValue;
    _entry = _entry.copyWith(
      value: newValue,
      previousValue: _entry.value,
      valueState: RegisterValueState.received,
      timestamp: formatModbusTime(now),
      date: formatModbusDate(now),
      rawWords: rawWords,
      previousRawWords: previousRawWords,
    );
  }

  Future<void> _doWrite(
    BuildContext ctx,
    TextEditingController ctrl,
    dynamic l10n,
    StateSetter setInnerState,
    void Function(String?) setError,
    void Function(bool) setWriting,
  ) async {
    try {
      encodeRegisterValue(
        _selectedType,
        ctrl.text,
        registerOrder: _registerOrder,
        byteOrder: _byteOrder,
      );
    } catch (_) {
      setInnerState(() => setError(l10n.writeInvalidValue));
      return;
    }
    setInnerState(() => setWriting(true));
    try {
      final newValue = await widget.onValueWritten?.call(
        ctrl.text,
        _selectedType,
      );
      // Always reflect the value read back after the write (the live listener,
      // if any, applies the same value idempotently).
      if (newValue != null && mounted) {
        setState(() => _applyWrittenValue(newValue));
      }
      if (ctx.mounted) Navigator.pop(ctx);
    } catch (error) {
      if (ctx.mounted && mounted) {
        setInnerState(() => setWriting(false));
        showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _showDataLayoutSheet() {
    return showDataLayoutSheet(
      context,
      registerOrder: _registerOrder,
      byteOrder: _byteOrder,
      onRegisterOrder: (value) => setState(() => _registerOrder = value),
      onByteOrder: (value) => setState(() => _byteOrder = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final entry = _entry;
    final currentValue = _displayValueForType(_selectedType);
    final valueColor = _valueColor(context, entry.valueState);
    final showPreviousValue =
        entry.previousValue != null &&
        AppSettings.instance.showLastValuesNotifier.value;

    return Scaffold(
      backgroundColor: cs.surfaceContainerHighest,
      appBar: AppBar(
        toolbarHeight: 56,
        title: Text(
          '${entry.displayAddress ?? entry.address}',
          style: tt.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          6,
          AppSpacing.screenGutter,
          92,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(l10n.labelCurrentValue),
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
                            color: valueColor,
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
                            color: appColors.previousValueColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 15,
                          color: appColors.previousValueColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _displayPreviousValue(entry.previousValue!),
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium!.copyWith(
                              color: appColors.previousValueColor,
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
            SectionHeader(l10n.colComment.toUpperCase()),
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
              OutlinedCard(
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

Color _valueColor(BuildContext context, RegisterValueState state) {
  final appColors = Theme.of(context).extension<AppColors>()!;
  return switch (state) {
    RegisterValueState.received => appColors.valueColor,
    RegisterValueState.unavailable => appColors.unavailableValueColor,
    RegisterValueState.exception => appColors.exceptionValueColor,
  };
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
    return Row(
      children: [
        Expanded(child: SectionHeader(title)),
        DataLayoutChip(
          registerOrder: registerOrder,
          byteOrder: byteOrder,
          onTap: onTap,
        ),
      ],
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
              : Colors.transparent,
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
    return OutlinedCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final text = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _CommentSheet(initial: comment ?? ''),
          );
          if (text == null) return;
          final updatedComment = text.trim();
          onChanged(updatedComment.isEmpty ? null : updatedComment);
        },
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

class _CommentSheet extends StatefulWidget {
  final String initial;

  const _CommentSheet({required this.initial});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                Text(l10n.colComment, style: tt.titleLarge),
                const SizedBox(height: 14),
                TextField(
                  key: AppTestKeys.registerCommentField,
                  controller: _ctrl,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(hintText: l10n.commentHint),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: AppTestKeys.registerCommentSaveButton,
                      onPressed: () =>
                          Navigator.pop(context, _ctrl.text.trim()),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(l10n.save),
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
