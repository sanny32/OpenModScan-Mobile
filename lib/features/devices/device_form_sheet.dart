import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/device_info.dart';

class DeviceFormSheet extends StatefulWidget {
  /// Null → add mode ("Connect to Device" / "Connect").
  /// Non-null → edit mode ("Edit Device" / "Save").
  /// [addMode] forces add-mode UI even when [initial] is provided (pre-fill from discovery).
  final DeviceInfo? initial;
  final bool addMode;

  const DeviceFormSheet({super.key, this.initial, this.addMode = false});

  @override
  State<DeviceFormSheet> createState() => _DeviceFormSheetState();
}

class _DeviceFormSheetState extends State<DeviceFormSheet> {
  late int _connType;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _timeoutCtrl;
  late final TextEditingController _reconnectCtrl;
  late final TextEditingController _notesCtrl;

  bool get _isEdit => widget.initial != null && !widget.addMode;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _connType = d?.protocol == ProtocolType.modbusRtuIp ? 1 : 0;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _hostCtrl = TextEditingController(text: d?.host ?? '');
    _portCtrl = TextEditingController(text: (d?.port ?? 502).toString());
    _unitCtrl = TextEditingController(text: (d?.unitId ?? 1).toString());
    _timeoutCtrl = TextEditingController(text: (d?.timeout ?? 1000).toString());
    _reconnectCtrl = TextEditingController(
      text: (d?.reconnectDelay ?? 3000).toString(),
    );
    _notesCtrl = TextEditingController(text: d?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _unitCtrl.dispose();
    _timeoutCtrl.dispose();
    _reconnectCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final base =
        widget.initial ??
        DeviceInfo(
          name: '',
          host: '',
          port: 502,
          protocol: ProtocolType.modbusTcp,
          unitId: 1,
        );
    final updated = base.copyWith(
      name: _nameCtrl.text.trim().isEmpty ? base.name : _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim().isEmpty ? base.host : _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text) ?? base.port,
      protocol: _connType == 0
          ? ProtocolType.modbusTcp
          : ProtocolType.modbusRtuIp,
      unitId: int.tryParse(_unitCtrl.text) ?? base.unitId,
      timeout: int.tryParse(_timeoutCtrl.text) ?? base.timeout,
      reconnectDelay: int.tryParse(_reconnectCtrl.text) ?? base.reconnectDelay,
      notes: _notesCtrl.text,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  Expanded(
                    child: Text(
                      _isEdit ? l10n.editDevice : l10n.connectToDevice,
                      textAlign: TextAlign.center,
                      style: tt.titleMedium,
                    ),
                  ),
                  if (!_isEdit)
                    TextButton(onPressed: _submit, child: Text(l10n.save))
                  else
                    const SizedBox(width: 72),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _label(context, l10n.connectionType),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeCard(
                          icon: Icons.lan_outlined,
                          label: l10n.connectTypeTcp,
                          sub: l10n.connectTypeTcpSub,
                          selected: _connType == 0,
                          onTap: () => setState(() => _connType = 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TypeCard(
                          icon: Icons.cable_outlined,
                          label: l10n.connectTypeRtu,
                          sub: l10n.connectTypeRtuSub,
                          selected: _connType == 1,
                          onTap: () => setState(() => _connType = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _label(context, l10n.labelName),
                  const SizedBox(height: 6),
                  _field(_nameCtrl),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(context, l10n.labelHost),
                            const SizedBox(height: 6),
                            _field(_hostCtrl, type: TextInputType.url),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(context, l10n.labelPort),
                            const SizedBox(height: 6),
                            _field(_portCtrl, type: TextInputType.number),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label(context, l10n.labelUnitIdField),
                  const SizedBox(height: 6),
                  _field(_unitCtrl, type: TextInputType.number),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(context, l10n.labelTimeout),
                            const SizedBox(height: 6),
                            _fieldSuffix(_timeoutCtrl, 'ms', context),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(context, l10n.labelReconnectDelay),
                            const SizedBox(height: 6),
                            _fieldSuffix(_reconnectCtrl, 'ms', context),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label(context, l10n.labelNotes),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.notesHint,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      textStyle: tt.titleMedium,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_isEdit ? l10n.save : l10n.connect),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String t) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(t, style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant));
  }

  Widget _field(TextEditingController c, {TextInputType? type}) => TextField(
    controller: c,
    keyboardType: type,
    decoration: const InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
  );

  Widget _fieldSuffix(
    TextEditingController c,
    String suffix,
    BuildContext context,
  ) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      suffixText: suffix,
      suffixStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                    width: 2,
                  ),
                  color: selected ? cs.primary : Colors.transparent,
                ),
                child: selected
                    ? Icon(Icons.circle, size: 8, color: cs.onPrimary)
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Icon(icon, size: 34, color: cs.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: tt.labelLarge!.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: tt.labelSmall!.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
