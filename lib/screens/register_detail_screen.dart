import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../models/register_entry.dart';
import '../theme/app_theme.dart';

const _kRegisterOrders = ['MSRF', 'LSRF'];
const _kByteOrders = ['Direct', 'Swapped'];
final _detailRegisterTypes = kRegisterTypes.where((t) => t != 'Bool').toList();

Color _typeColor(BuildContext context, String type) {
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

String _typeAbbrev(String type) {
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

String _formatFloat(double f) {
  if (f.isNaN) return 'NaN';
  if (f.isInfinite) return f > 0 ? '+inf' : '-inf';
  if (f == 0.0) return '0';
  final abs = f.abs();
  if (abs < 0.001 || abs >= 1e7) return f.toStringAsExponential(6);
  return f.toStringAsPrecision(7).replaceAll(RegExp(r'\.?0+$'), '');
}

String _displayTimestamp(String timestamp) {
  if (RegExp(r'\.\d+$').hasMatch(timestamp)) return timestamp;
  return '$timestamp.000';
}

class RegisterDetailScreen extends StatefulWidget {
  final RegisterEntry entry;
  const RegisterDetailScreen({super.key, required this.entry});

  @override
  State<RegisterDetailScreen> createState() => _RegisterDetailScreenState();
}

class _RegisterDetailScreenState extends State<RegisterDetailScreen> {
  late String _selectedType;
  late TextEditingController _commentCtrl;
  String _registerOrder = _kRegisterOrders.first;
  String _byteOrder = _kByteOrders.first;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _selectedType = _detailRegisterTypes.contains(widget.entry.typeName)
        ? widget.entry.typeName
        : _detailRegisterTypes.first;
    _commentCtrl = TextEditingController(text: widget.entry.comment ?? '');
    _commentCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _commentCtrl.removeListener(_onTextChanged);
    _commentCtrl.dispose();
    super.dispose();
  }

  int? get _rawUInt16 {
    final v = int.tryParse(widget.entry.value);
    if (v != null && v >= 0 && v <= 65535) return v;
    return null;
  }

  List<_Interpretation> _buildInterpretations(int raw) {
    final r = _byteOrder == 'Swapped'
        ? ((raw & 0xFF) << 8) | ((raw >> 8) & 0xFF)
        : raw;

    final uint16 = r;
    final int16 = r > 32767 ? r - 65536 : r;
    final uint32 = _registerOrder == 'MSRF' ? r << 16 : r;
    final int32 = uint32 > 0x7FFFFFFF ? uint32 - 0x100000000 : uint32;
    final uint64 = _registerOrder == 'MSRF' ? r << 48 : r;
    final int64 = uint64;

    final bdF32 = ByteData(4);
    _registerOrder == 'MSRF'
        ? bdF32.setUint16(0, r, Endian.big)
        : bdF32.setUint16(2, r, Endian.big);
    final float32 = bdF32.getFloat32(0, Endian.big);

    final bdF64 = ByteData(8);
    _registerOrder == 'MSRF'
        ? bdF64.setUint16(0, r, Endian.big)
        : bdF64.setUint16(6, r, Endian.big);
    final float64 = bdF64.getFloat64(0, Endian.big);

    final hex = '0x${r.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final bin = r.toRadixString(2).padLeft(16, '0');
    final binFmt =
        '${bin.substring(0, 4)} ${bin.substring(4, 8)} '
        '${bin.substring(8, 12)} ${bin.substring(12)}';

    return [
      _Interpretation('UInt16', uint16.toString()),
      _Interpretation('Int16', int16.toString()),
      _Interpretation('UInt32', uint32.toString()),
      _Interpretation('Int32', int32.toString()),
      _Interpretation('UInt64', uint64.toString()),
      _Interpretation('Int64', int64.toString()),
      _Interpretation('Float32', _formatFloat(float32)),
      _Interpretation('Float64', _formatFloat(float64)),
      _Interpretation('Hex', hex),
      _Interpretation('Binary', binFmt),
    ];
  }

  String _displayValueForType(int? raw, String type, String fallback) {
    if (raw == null) return fallback;
    for (final interpretation in _buildInterpretations(raw)) {
      if (interpretation.typeName == type) return interpretation.value;
    }
    return fallback;
  }

  void _save() {
    // TODO: persist type, comment, register order, byte order.
    setState(() => _hasChanges = false);
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
                    options: _kRegisterOrders,
                    value: _registerOrder,
                    onSelected: selectRegisterOrder,
                  ),
                  const SizedBox(height: 14),
                  _LayoutChoiceSection(
                    label: l10n.labelByteOrder,
                    icon: Icons.swap_horiz_rounded,
                    options: _kByteOrders,
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
    final raw = _rawUInt16;
    final entry = widget.entry;
    final currentValue = _displayValueForType(raw, _selectedType, entry.value);

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
          if (_hasChanges) ...[
            _SavePillButton(onPressed: _save, label: l10n.save),
            const SizedBox(width: 6),
          ],
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
                  if (entry.previousValue != null) ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, thickness: 1.2, color: cs.outline),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 19,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Text(
                            l10n.labelPreviousValue,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyLarge!.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          entry.previousValue!,
                          style: tt.bodyMedium!.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionHeader(l10n.labelProperties),
            const SizedBox(height: 7),
            _OutlinedCard(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                children: [
                  _OutlineField(
                    label: l10n.colType,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        itemHeight: 48,
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: cs.onSurfaceVariant,
                          size: 24,
                        ),
                        selectedItemBuilder: (ctx) => _detailRegisterTypes
                            .map(
                              (t) => Row(
                                children: [
                                  _TypeBadge(type: t),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _TypeNameText(
                                      type: t,
                                      isSelected: false,
                                      compact: true,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                        items: _detailRegisterTypes
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    _TypeBadge(type: t),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(_typeDescription(t))),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedType = v;
                              _hasChanges = true;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentCtrl,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.colComment,
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: cs.outline.withValues(alpha: 0.55),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: cs.primary, width: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (raw != null) ...[
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
                    final items = _buildInterpretations(raw);
                    return List.generate(items.length, (i) {
                      final interp = items[i];
                      final isCurrent = interp.typeName == _selectedType;
                      return _InterpretationRow(
                        interpretation: interp,
                        selected: isCurrent,
                        showDivider: i > 0,
                        onTap: isCurrent
                            ? null
                            : () => setState(() {
                                _selectedType = interp.typeName;
                                _hasChanges = true;
                              }),
                      );
                    });
                  }(),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showWriteDialog,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.edit_outlined),
        label: Text(
          l10n.writeValue,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
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

class _SavePillButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _SavePillButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Ink(
          height: 42,
          width: 78,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: cs.onPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
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

class _OutlineField extends StatelessWidget {
  final String label;
  final Widget child;

  const _OutlineField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: false,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: cs.primary, width: 1.4),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(14, 3, 12, 3),
      ),
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(context, type);
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
        _typeAbbrev(type),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
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
                    _TypeBadge(type: interpretation.typeName),
                    const SizedBox(width: 12),
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
  final bool compact;

  const _TypeNameText({
    required this.type,
    required this.isSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final description = _typeDescription(type);
    final match = RegExp(r'^(.*?) (\(.+\))$').firstMatch(description);
    final main = match?.group(1) ?? description;
    final suffix = match?.group(2);
    final color = isSelected ? cs.primary : cs.onSurface;
    final size = compact ? 15.0 : 14.0;

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
