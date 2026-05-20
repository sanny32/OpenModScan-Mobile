import 'package:flutter/material.dart';

class ConnectDeviceSheet extends StatefulWidget {
  const ConnectDeviceSheet({super.key});

  @override
  State<ConnectDeviceSheet> createState() => _ConnectDeviceSheetState();
}

class _ConnectDeviceSheetState extends State<ConnectDeviceSheet> {
  int _connType = 0;
  final _nameCtrl = TextEditingController(text: 'PLC #1');
  final _hostCtrl = TextEditingController(text: '192.168.0.10');
  final _portCtrl = TextEditingController(text: '502');
  final _unitCtrl = TextEditingController(text: '1');
  final _timeoutCtrl = TextEditingController(text: '1000');
  final _reconnectCtrl = TextEditingController(text: '3000');
  final _notesCtrl = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Expanded(
                    child: Text('Connect to device',
                        textAlign: TextAlign.center,
                        style: tt.titleMedium),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _label(context, 'Connection type'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeCard(
                          icon: Icons.lan_outlined,
                          label: 'Modbus TCP',
                          sub: 'Standard Modbus TCP',
                          selected: _connType == 0,
                          onTap: () => setState(() => _connType = 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TypeCard(
                          icon: Icons.cable_outlined,
                          label: 'RTU over TCP/IP',
                          sub: 'Modbus RTU over TCP',
                          selected: _connType == 1,
                          onTap: () => setState(() => _connType = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _label(context, 'Name'),
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
                            _label(context, 'Host / IP address'),
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
                            _label(context, 'Port'),
                            const SizedBox(height: 6),
                            _field(_portCtrl, type: TextInputType.number),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label(context, 'Unit ID (Slave ID)'),
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
                            _label(context, 'Timeout'),
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
                            _label(context, 'Reconnect delay'),
                            const SizedBox(height: 6),
                            _fieldSuffix(_reconnectCtrl, 'ms', context),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label(context, 'Notes (optional)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Add any notes about this connection',
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      textStyle: tt.titleMedium,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Connect'),
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
    return Text(t,
        style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant));
  }

  Widget _field(TextEditingController c, {TextInputType? type}) =>
      TextField(
        controller: c,
        keyboardType: type,
        decoration: const InputDecoration(
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      );

  Widget _fieldSuffix(
          TextEditingController c, String suffix, BuildContext context) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixText: suffix,
          suffixStyle: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            Text(label,
                style: tt.labelLarge!.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(sub,
                style:
                    tt.labelSmall!.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
