import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';
import '../../models/register_list.dart';
import 'widgets/max_count_formatter.dart';

Future<RegisterList?> showRegisterListDialog(
  BuildContext context, {
  required String defaultName,
  List<String> existingNames = const [],
}) => showDialog<RegisterList>(
  context: context,
  builder: (_) => _RegisterListDialog(
    defaultName: defaultName,
    existingNames: existingNames,
  ),
);

class _RegisterListDialog extends StatefulWidget {
  final String defaultName;
  final List<String> existingNames;

  const _RegisterListDialog({
    required this.defaultName,
    required this.existingNames,
  });

  @override
  State<_RegisterListDialog> createState() => _RegisterListDialogState();
}

class _RegisterListDialogState extends State<_RegisterListDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _startCtrl;
  late final TextEditingController _countCtrl;
  var _regType = '4xxxx';
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final minStart = AppSettings.instance.addressBaseStart;
    _nameCtrl = TextEditingController(text: widget.defaultName);
    _startCtrl = TextEditingController(text: minStart.toString());
    _countCtrl = TextEditingController(
      text: '${AppSettings.instance.defaultReadQty}',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _startCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (widget.existingNames.contains(name)) {
      setState(() => _nameError = context.l10n.nameAlreadyExists);
      return;
    }
    Navigator.pop(
      context,
      RegisterList(
        name: name,
        regType: _regType,
        startAddress: _startAddress(),
        count: _count(),
      ),
    );
  }

  int _startAddress() {
    final minStart = AppSettings.instance.addressBaseStart;
    final value = int.tryParse(_startCtrl.text) ?? minStart;
    final displayStart = value < minStart ? minStart : value;
    return displayStart - minStart;
  }

  int _count() {
    final fallback = AppSettings.instance.defaultReadQty;
    final value = int.tryParse(_countCtrl.text) ?? fallback;
    return value < 1 ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.menuAddRegs),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                labelText: l10n.labelName,
                hintText: l10n.dialogListNameHint,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _regType,
              decoration: InputDecoration(labelText: l10n.labelRegisterType),
              items: const [
                DropdownMenuItem(
                  value: '4xxxx',
                  child: Text('Holding (4xxxx)'),
                ),
                DropdownMenuItem(value: '3xxxx', child: Text('Input (3xxxx)')),
                DropdownMenuItem(
                  value: '1xxxx',
                  child: Text('Discrete Input (1xxxx)'),
                ),
                DropdownMenuItem(value: '0xxxx', child: Text('Coils (0xxxx)')),
              ],
              onChanged: (value) {
                if (value != null) _regType = value;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      MaxCountFormatter(
                        max: null,
                        min: AppSettings.instance.addressBaseStart,
                      ),
                    ],
                    decoration: InputDecoration(labelText: l10n.labelStart),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _countCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      const MaxCountFormatter(max: null, min: 1),
                    ],
                    decoration: InputDecoration(labelText: l10n.labelCount),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
