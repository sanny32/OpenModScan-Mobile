import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

class StatusDetailScreen extends StatefulWidget {
  final int address;
  final bool initialValue;
  final String comment;
  final bool canWrite;
  final String? timestamp;
  final String? date;
  final ValueChanged<String?>? onSaved;

  const StatusDetailScreen({
    super.key,
    required this.address,
    required this.initialValue,
    required this.comment,
    required this.canWrite,
    this.timestamp,
    this.date,
    this.onSaved,
  });

  @override
  State<StatusDetailScreen> createState() => _StatusDetailScreenState();
}

class _StatusDetailScreenState extends State<StatusDetailScreen> {
  late bool _value;
  late final TextEditingController _commentCtrl;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _commentCtrl = TextEditingController(text: widget.comment);
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

  void _setValue(bool value) {
    if (!widget.canWrite) return;
    setState(() {
      _value = value;
      _hasChanges = true;
    });
  }

  void _save() {
    final comment = _commentCtrl.text.trim();
    widget.onSaved?.call(comment.isEmpty ? null : comment);
    setState(() => _hasChanges = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final valueColor = _value ? cs.primary : cs.onSurfaceVariant;

    return Scaffold(
      backgroundColor: cs.surfaceContainerHighest,
      appBar: AppBar(
        toolbarHeight: 56,
        title: Text(
          widget.address.toString().padLeft(5, '0'),
          style: tt.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_hasChanges) ...[
            TextButton(onPressed: _save, child: Text(l10n.save)),
            const SizedBox(width: 6),
          ],
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
          const SizedBox(width: 2),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusCard(
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
                      if (widget.timestamp != null) ...[
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
                            if (widget.date != null) ...[
                              Text(
                                widget.date!,
                                maxLines: 1,
                                softWrap: false,
                                style: tt.bodyLarge!.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 5),
                            ],
                            Text(
                              '${widget.timestamp!}.000',
                              maxLines: 1,
                              softWrap: false,
                              style: tt.bodyLarge!.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _value ? 'ON' : 'OFF',
                    style: tt.headlineMedium!.copyWith(
                      color: valueColor,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _value ? 'True' : 'False',
                    style: tt.bodyMedium!.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _StatusSectionHeader(l10n.labelProperties),
            const SizedBox(height: 7),
            _StatusCard(
              child: TextField(
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
            ),
          ],
        ),
      ),
      floatingActionButton: widget.canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _setValue(!_value),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(
                _value ? 'Set OFF' : 'Set ON',
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

class _StatusCard extends StatelessWidget {
  final Widget child;

  const _StatusCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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

class _StatusSectionHeader extends StatelessWidget {
  final String title;

  const _StatusSectionHeader(this.title);

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
