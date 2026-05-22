import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../models/register_list.dart';

Future<RegisterList?> showRegisterListDialog(
  BuildContext context, {
  required String defaultName,
}) async {
  final nameCtrl = TextEditingController(text: defaultName);
  final startCtrl = TextEditingController(text: '1');
  final countCtrl = TextEditingController(text: '20');
  var regType = '4xxxx';

  try {
    return await showDialog<RegisterList>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.menuAddRegs),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.labelName,
                  hintText: context.l10n.dialogListNameHint,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: regType,
                decoration: InputDecoration(
                  labelText: context.l10n.labelRegisterType,
                ),
                items: const [
                  DropdownMenuItem(
                    value: '4xxxx',
                    child: Text('Holding (4xxxx)'),
                  ),
                  DropdownMenuItem(
                    value: '3xxxx',
                    child: Text('Input (3xxxx)'),
                  ),
                  DropdownMenuItem(
                    value: '1xxxx',
                    child: Text('Discrete Input (1xxxx)'),
                  ),
                  DropdownMenuItem(
                    value: '0xxxx',
                    child: Text('Coils (0xxxx)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) regType = value;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: context.l10n.labelStart,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: countCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: context.l10n.labelCount,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                ctx,
                RegisterList(
                  name: name,
                  regType: regType,
                  startAddress: int.tryParse(startCtrl.text) ?? 1,
                  count: int.tryParse(countCtrl.text) ?? 20,
                ),
              );
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  } finally {
    nameCtrl.dispose();
    startCtrl.dispose();
    countCtrl.dispose();
  }
}
