import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';
import '../../models/device_info.dart';
import '../../widgets/app_test_keys.dart';
import '../../widgets/keyboard_done_bar.dart';
import 'device_marker_color_palette.dart';

class DeviceFormResult {
  final DeviceInfo device;
  final bool connectAfterSave;

  const DeviceFormResult(this.device, {this.connectAfterSave = false});
}

class DeviceFormSheet extends StatefulWidget {
  /// Null → add mode ("Connect to Device" / "Connect").
  /// Non-null → edit mode ("Edit Device" / "Save").
  /// [addMode] forces add-mode UI even when [initial] is provided (pre-fill from discovery).
  final DeviceInfo? initial;
  final bool addMode;
  final List<String> existingNames;

  const DeviceFormSheet({
    super.key,
    this.initial,
    this.addMode = false,
    this.existingNames = const [],
  });

  @override
  State<DeviceFormSheet> createState() => _DeviceFormSheetState();
}

class _DeviceFormSheetState extends State<DeviceFormSheet> {
  late int _connType;
  late DeviceMarkerColor _markerColor;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _timeoutCtrl;
  late final TextEditingController _reconnectCtrl;
  late final TextEditingController _notesCtrl;
  String? _nameError;

  bool get _isEdit => widget.initial != null && !widget.addMode;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    final defaults = AppSettings.instance;
    _connType =
        (d?.protocol ?? defaults.connectionType) == ProtocolType.modbusRtuIp
        ? 1
        : 0;
    _markerColor = d?.markerColor ?? DeviceMarkerColor.blue;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _hostCtrl = TextEditingController(text: d?.host ?? '');
    _portCtrl = TextEditingController(text: (d?.port ?? 502).toString());
    _unitCtrl = TextEditingController(
      text: (d?.unitId ?? defaults.defaultUnitId).toString(),
    );
    _timeoutCtrl = TextEditingController(
      text: (d?.timeout ?? defaults.timeout).toString(),
    );
    _reconnectCtrl = TextEditingController(
      text: (d?.reconnectDelay ?? defaults.reconnectDelay).toString(),
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

  void _submit({bool connectAfterSave = false}) {
    final name = _nameCtrl.text.trim();
    final l10n = context.l10n;
    if (name.isEmpty) {
      setState(() => _nameError = l10n.nameRequired);
      return;
    }
    if (widget.existingNames.contains(name)) {
      setState(() => _nameError = l10n.nameAlreadyExists);
      return;
    }

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
      name: name,
      host: _hostCtrl.text.trim().isEmpty ? base.host : _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text) ?? base.port,
      protocol: _connType == 0
          ? ProtocolType.modbusTcp
          : ProtocolType.modbusRtuIp,
      unitId: int.tryParse(_unitCtrl.text) ?? base.unitId,
      timeout: int.tryParse(_timeoutCtrl.text) ?? base.timeout,
      reconnectDelay: int.tryParse(_reconnectCtrl.text) ?? base.reconnectDelay,
      notes: _notesCtrl.text,
      markerColor: _markerColor,
    );
    Navigator.pop(
      context,
      DeviceFormResult(updated, connectAfterSave: connectAfterSave),
    );
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
                      _isEdit ? l10n.editDevice : l10n.addDevice,
                      textAlign: TextAlign.center,
                      style: tt.titleMedium,
                    ),
                  ),
                  if (!_isEdit)
                    TextButton(
                      key: AppTestKeys.deviceFormSaveButton,
                      onPressed: _submit,
                      child: Text(l10n.save),
                    )
                  else
                    const SizedBox(width: 72),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                key: AppTestKeys.deviceFormScrollable,
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _label(context, l10n.connectionType),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeCard(
                          key: const ValueKey(
                            'device-connection-type-modbusTcp',
                          ),
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
                          key: const ValueKey(
                            'device-connection-type-modbusRtuIp',
                          ),
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
                  _field(
                    _nameCtrl,
                    key: AppTestKeys.deviceFormNameField,
                    label: l10n.labelName,
                    errorText: _nameError,
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),
                  const SizedBox(height: 16),
                  _label(context, l10n.deviceMarkerColor),
                  const SizedBox(height: 8),
                  _MarkerColorPicker(
                    selected: _markerColor,
                    onSelected: (value) => setState(() {
                      _markerColor = value;
                    }),
                  ),
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
                            _field(
                              _hostCtrl,
                              label: l10n.labelHost,
                              type: TextInputType.url,
                            ),
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
                            _field(
                              _portCtrl,
                              label: l10n.labelPort,
                              type: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label(context, l10n.labelUnitIdField),
                  const SizedBox(height: 6),
                  _field(
                    _unitCtrl,
                    label: l10n.labelUnitIdField,
                    type: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _label(context, l10n.labelTimeout)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _label(context, l10n.labelReconnectDelay),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _fieldSuffix(
                          _timeoutCtrl,
                          'ms',
                          context,
                          label: l10n.labelTimeout,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _fieldSuffix(
                          _reconnectCtrl,
                          'ms',
                          context,
                          label: l10n.labelReconnectDelay,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label(context, l10n.labelNotes),
                  const SizedBox(height: 6),
                  KeyboardDoneField(
                    label: l10n.labelNotes,
                    builder: (focusNode) => TextField(
                      controller: _notesCtrl,
                      focusNode: focusNode,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: l10n.notesHint,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    // In edit mode the top save action is hidden, so this is the
                    // only save control — expose the save key here for tests.
                    key: _isEdit ? AppTestKeys.deviceFormSaveButton : null,
                    onPressed: () => _submit(connectAfterSave: !_isEdit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 0,
                      shadowColor: Colors.transparent,
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

  Widget _field(
    TextEditingController c, {
    Key? key,
    required String label,
    TextInputType? type,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) => KeyboardDoneField(
    label: label,
    builder: (focusNode) => TextField(
      key: key,
      controller: c,
      focusNode: focusNode,
      keyboardType: type,
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        errorText: errorText,
      ),
    ),
  );

  Widget _fieldSuffix(
    TextEditingController c,
    String suffix,
    BuildContext context, {
    required String label,
  }) => KeyboardDoneField(
    label: label,
    builder: (focusNode) => TextField(
      controller: c,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        suffixText: suffix,
        suffixStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _MarkerColorPicker extends StatelessWidget {
  final DeviceMarkerColor selected;
  final ValueChanged<DeviceMarkerColor> onSelected;

  const _MarkerColorPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final markerColor in DeviceMarkerColor.values)
          _MarkerColorSwatch(
            markerColor: markerColor,
            color: markerColor.resolve(cs),
            label: markerColor.label(l10n),
            selected: markerColor == selected,
            onTap: () => onSelected(markerColor),
          ),
      ],
    );
  }
}

class _MarkerColorSwatch extends StatelessWidget {
  final DeviceMarkerColor markerColor;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MarkerColorSwatch({
    required this.markerColor,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: ValueKey('device-marker-color-${markerColor.name}'),
          onTap: onTap,
          radius: 24,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).dividerColor,
                width: selected ? 3 : 1,
              ),
            ),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: selected
                    ? Icon(Icons.check, size: 18, color: checkColor)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    super.key,
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
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
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
      ),
    );
  }
}
