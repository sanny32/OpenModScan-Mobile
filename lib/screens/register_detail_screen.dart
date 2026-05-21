import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../models/register_entry.dart';
import '../theme/app_theme.dart';

// ─── Register / Byte order options ────────────────────────────────────────────
const _kRegisterOrders = ['High-Low', 'Low-High'];
const _kByteOrders = ['Big Endian', 'Little Endian'];

// ─── Type metadata helpers ─────────────────────────────────────────────────────
Color _typeColor(String type) {
  switch (type) {
    case 'UInt16':
    case 'UInt32':
    case 'UInt64':
      return const Color(0xFF1976D2);
    case 'Int16':
    case 'Int32':
    case 'Int64':
      return const Color(0xFF00796B);
    case 'Float32':
    case 'Float64':
      return const Color(0xFFE65100);
    case 'Hex':
      return const Color(0xFF7B1FA2);
    case 'Binary':
      return const Color(0xFFBF360C);
    case 'Bool':
      return const Color(0xFF388E3C);
    default:
      return const Color(0xFF455A64);
  }
}

String _typeAbbrev(String type) {
  switch (type) {
    case 'UInt16': return 'U16';
    case 'Int16':  return 'I16';
    case 'UInt32': return 'U32';
    case 'Int32':  return 'I32';
    case 'UInt64': return 'U64';
    case 'Int64':  return 'I64';
    case 'Float32': return 'F32';
    case 'Float64': return 'F64';
    case 'Hex':    return 'HEX';
    case 'Binary': return 'BIN';
    case 'Bool':   return 'BOOL';
    default:       return type.length > 4 ? type.substring(0, 4).toUpperCase() : type.toUpperCase();
  }
}

String _typeDescription(String type) {
  switch (type) {
    case 'UInt16':  return 'UInt16 (16 bit)';
    case 'Int16':   return 'Int16 (16 bit)';
    case 'UInt32':  return 'UInt32 (32 bit)';
    case 'Int32':   return 'Int32 (32 bit)';
    case 'UInt64':  return 'UInt64 (64 bit)';
    case 'Int64':   return 'Int64 (64 bit)';
    case 'Float32': return 'Float32 (IEEE 754)';
    case 'Float64': return 'Float64 (IEEE 754)';
    case 'Hex':     return 'Hex';
    case 'Binary':  return 'Binary';
    case 'Bool':    return 'Bool';
    default:        return type;
  }
}

String _formatFloat(double f) {
  if (f.isNaN) return 'NaN';
  if (f.isInfinite) return f > 0 ? '+∞' : '-∞';
  if (f == 0.0) return '0';
  final abs = f.abs();
  if (abs < 0.001 || abs >= 1e7) return f.toStringAsExponential(6);
  return f.toStringAsPrecision(7).replaceAll(RegExp(r'\.?0+$'), '');
}

// ─── Main screen ──────────────────────────────────────────────────────────────
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
    _selectedType = kRegisterTypes.contains(widget.entry.typeName)
        ? widget.entry.typeName
        : kRegisterTypes.first;
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

  // ── Interpretation computations ──────────────────────────────────────────────
  int? get _rawUInt16 {
    final v = int.tryParse(widget.entry.value);
    if (v != null && v >= 0 && v <= 65535) return v;
    return null;
  }

  List<_Interpretation> _buildInterpretations(int raw) {
    // Apply byte order swap if needed
    final r = _byteOrder == 'Little Endian'
        ? ((raw & 0xFF) << 8) | ((raw >> 8) & 0xFF)
        : raw;

    // 16-bit
    final uint16 = r;
    final int16 = r > 32767 ? r - 65536 : r;

    // 32-bit
    final uint32 = _registerOrder == 'High-Low' ? r << 16 : r;
    final int32 = uint32 > 0x7FFFFFFF ? uint32 - 0x100000000 : uint32;

    // 64-bit
    final uint64 = _registerOrder == 'High-Low' ? r << 48 : r;
    final int64 = uint64; // Dart int is 64-bit signed; small values stay positive

    // Float32
    final bdF32 = ByteData(4);
    _registerOrder == 'High-Low'
        ? bdF32.setUint16(0, r, Endian.big)
        : bdF32.setUint16(2, r, Endian.big);
    final float32 = bdF32.getFloat32(0, Endian.big);

    // Float64
    final bdF64 = ByteData(8);
    _registerOrder == 'High-Low'
        ? bdF64.setUint16(0, r, Endian.big)
        : bdF64.setUint16(6, r, Endian.big);
    final float64 = bdF64.getFloat64(0, Endian.big);

    // Display formats
    final hex = '0x${r.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final bin = r.toRadixString(2).padLeft(16, '0');
    final binFmt = '${bin.substring(0, 4)} ${bin.substring(4, 8)} '
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
      _Interpretation('Bool', r != 0 ? 'true' : 'false'),
    ];
  }

  // ── Save / Write ─────────────────────────────────────────────────────────────
  void _save() {
    // TODO: persist type, comment, register order, byte order
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
                  Text('${l10n.colAddress}: ',
                      style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant)),
                  Text('${widget.entry.address}',
                      style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('${l10n.colValue}: ',
                      style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant)),
                  Text(widget.entry.value,
                      style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                  if (widget.entry.previousValue != null) ...[
                    const SizedBox(width: 8),
                    Text('← ${widget.entry.previousValue}',
                        style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
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
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
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

  void _doWrite(BuildContext ctx, TextEditingController ctrl, dynamic l10n,
      StateSetter setInnerState, void Function(String?) setError) {
    final raw = int.tryParse(ctrl.text);
    if (raw == null || raw < 0 || raw > 65535) {
      setInnerState(() => setError(l10n.writeValueRange));
      return;
    }
    // TODO: perform actual Modbus write
    Navigator.pop(ctx);
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final raw = _rawUInt16;
    final entry = widget.entry;

    return Scaffold(
      appBar: AppBar(
        title: Text('${entry.address}'),
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilledButton.tonal(
                onPressed: _save,
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(l10n.save),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Value card ────────────────────────────────────
            _OutlinedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT VALUE',
                        style: tt.labelSmall!.copyWith(
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      if (entry.timestamp != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 13, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(entry.timestamp!,
                                    style: tt.labelSmall!
                                        .copyWith(color: cs.onSurfaceVariant)),
                                if (entry.date != null)
                                  Text(entry.date!,
                                      style: tt.labelSmall!.copyWith(
                                          color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.value,
                    style: tt.displaySmall!.copyWith(
                      color: appColors.valueColor,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (entry.previousValue != null) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: cs.outlineVariant),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.arrow_back_rounded,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(l10n.labelPreviousValue,
                            style: tt.bodySmall!
                                .copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Text(
                          entry.previousValue!,
                          style: tt.bodyMedium!.copyWith(
                            color: cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Properties ────────────────────────────────────
            _SectionHeader(l10n.labelProperties),
            const SizedBox(height: 8),
            _OutlinedCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Type dropdown with badge
                  _OutlineField(
                    label: l10n.colType,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        isDense: true,
                        isExpanded: true,
                        selectedItemBuilder: (ctx) => kRegisterTypes
                            .map((t) => Row(
                                  children: [
                                    _TypeBadge(type: t),
                                    const SizedBox(width: 8),
                                    Text(_typeDescription(t),
                                        style: tt.bodyMedium),
                                  ],
                                ))
                            .toList(),
                        items: kRegisterTypes
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Row(
                                    children: [
                                      _TypeBadge(type: t),
                                      const SizedBox(width: 8),
                                      Text(_typeDescription(t)),
                                    ],
                                  ),
                                ))
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
                  const SizedBox(height: 10),
                  // Comment
                  TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.colComment,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Register Order
                  _OutlineField(
                    label: l10n.labelRegisterOrder,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _registerOrder,
                        isDense: true,
                        isExpanded: true,
                        items: _kRegisterOrders
                            .map((o) =>
                                DropdownMenuItem(value: o, child: Text(o)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _registerOrder = v;
                              _hasChanges = true;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Byte Order
                  _OutlineField(
                    label: l10n.labelByteOrder,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _byteOrder,
                        isDense: true,
                        isExpanded: true,
                        items: _kByteOrders
                            .map((o) =>
                                DropdownMenuItem(value: o, child: Text(o)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _byteOrder = v;
                              _hasChanges = true;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Interpretations ───────────────────────────────
            if (raw != null) ...[
              const SizedBox(height: 20),
              _SectionHeader(l10n.labelInterpretations),
              const SizedBox(height: 8),
              _OutlinedCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: () {
                    final items = _buildInterpretations(raw);
                    return List.generate(items.length, (i) {
                      final interp = items[i];
                      final isCurrent = interp.typeName == _selectedType;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: cs.outlineVariant,
                            ),
                          Material(
                            color: isCurrent
                                ? cs.primaryContainer.withValues(alpha: 0.35)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: isCurrent
                                  ? null
                                  : () => setState(() {
                                        _selectedType = interp.typeName;
                                        _hasChanges = true;
                                      }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 11),
                                child: Row(
                                  children: [
                                    // Radio indicator
                                    Icon(
                                      isCurrent
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      size: 18,
                                      color: isCurrent
                                          ? cs.primary
                                          : cs.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 10),
                                    // Type badge
                                    _TypeBadge(type: interp.typeName),
                                    const SizedBox(width: 10),
                                    // Type name
                                    Expanded(
                                      child: Text(
                                        _typeDescription(interp.typeName),
                                        style: tt.bodyMedium!.copyWith(
                                          color: isCurrent ? cs.primary : null,
                                          fontWeight: isCurrent
                                              ? FontWeight.w600
                                              : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Value
                                    interp.typeName == 'Bool'
                                        ? _BoolChip(value: interp.value)
                                        : Text(
                                            interp.value,
                                            style: tt.bodyMedium!.copyWith(
                                              color: isCurrent
                                                  ? appColors.valueColor
                                                  : cs.onSurfaceVariant,
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : null,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.writeValue),
      ),
    );
  }
}

// ─── Reusable widgets ──────────────────────────────────────────────────────────

class _OutlinedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _OutlinedCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
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
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: child,
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _typeAbbrev(type),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _BoolChip extends StatelessWidget {
  final String value;
  const _BoolChip({required this.value});

  @override
  Widget build(BuildContext context) {
    final isTrue = value == 'true';
    final color = isTrue ? const Color(0xFF388E3C) : const Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _Interpretation {
  final String typeName;
  final String value;
  const _Interpretation(this.typeName, this.value);
}
