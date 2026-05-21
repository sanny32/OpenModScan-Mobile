import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../models/register_entry.dart';
import '../theme/app_theme.dart';

class RegisterDetailScreen extends StatefulWidget {
  final RegisterEntry entry;

  const RegisterDetailScreen({super.key, required this.entry});

  @override
  State<RegisterDetailScreen> createState() => _RegisterDetailScreenState();
}

class _RegisterDetailScreenState extends State<RegisterDetailScreen> {
  late String _selectedType;
  late TextEditingController _commentCtrl;
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

  int? get _rawUInt16 {
    final v = int.tryParse(widget.entry.value);
    if (v != null && v >= 0 && v <= 65535) return v;
    return null;
  }

  List<_Interpretation> _buildInterpretations(int raw) {
    final signed = raw > 32767 ? raw - 65536 : raw;
    final hex = '0x${raw.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final bin = raw.toRadixString(2).padLeft(16, '0');
    final binFormatted =
        '${bin.substring(0, 4)} ${bin.substring(4, 8)} '
        '${bin.substring(8, 12)} ${bin.substring(12)}';
    return [
      _Interpretation('UInt16', raw.toString()),
      _Interpretation('Int16', signed.toString()),
      _Interpretation('Hex', hex),
      _Interpretation('Binary', binFormatted),
    ];
  }

  void _save() {
    // TODO: persist type and comment
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
    // TODO: perform actual Modbus write
    Navigator.pop(ctx);
  }

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
            FilledButton.tonal(
              onPressed: _save,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(l10n.save),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Value card ──────────────────────────────────
            Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.colValue.toUpperCase(),
                          style: tt.labelSmall!.copyWith(
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        if (entry.timestamp != null) ...[
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.timestamp!,
                            style: tt.labelSmall!.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
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
                          Icon(
                            Icons.arrow_back_rounded,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.labelPreviousValue,
                            style: tt.bodySmall!.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.previousValue!,
                            style: tt.bodyMedium!.copyWith(
                              color: cs.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Properties ──────────────────────────────────
            _SectionHeader(l10n.labelProperties),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.colType,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          isDense: true,
                          isExpanded: true,
                          items: kRegisterTypes
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: _commentCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.colComment,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Interpretations ─────────────────────────────
            if (raw != null) ...[
              const SizedBox(height: 20),
              _SectionHeader(l10n.labelInterpretations),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                color: cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Column(
                  children: () {
                    final items = _buildInterpretations(raw);
                    return List.generate(items.length, (i) {
                      final interp = items[i];
                      final isCurrent = interp.typeName == _selectedType;
                      final isSelectable =
                          kRegisterTypes.contains(interp.typeName);
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
                              onTap: isSelectable && !isCurrent
                                  ? () => setState(() {
                                        _selectedType = interp.typeName;
                                        _hasChanges = true;
                                      })
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 13,
                                ),
                                child: Row(
                              children: [
                                if (isCurrent)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.radio_button_checked,
                                      size: 14,
                                      color: cs.primary,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 20),
                                Text(
                                  interp.typeName,
                                  style: tt.bodyMedium!.copyWith(
                                    color: isCurrent ? cs.primary : null,
                                    fontWeight: isCurrent
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  interp.value,
                                  style: tt.bodyLarge!.copyWith(
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        color: cs.onSurfaceVariant,
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
