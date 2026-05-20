import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Expanded(
                    child: Text('Connect to device',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable body
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _label('Connection type'),
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
                  _label('Name'),
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
                            _label('Host / IP address'),
                            const SizedBox(height: 6),
                            _field(_hostCtrl,
                                keyboardType: TextInputType.url),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Port'),
                            const SizedBox(height: 6),
                            _field(_portCtrl,
                                keyboardType: TextInputType.number),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Unit ID (Slave ID)'),
                  const SizedBox(height: 6),
                  _field(_unitCtrl, keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Timeout'),
                            const SizedBox(height: 6),
                            _fieldSuffix(_timeoutCtrl, 'ms'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Reconnect delay'),
                            const SizedBox(height: 6),
                            _fieldSuffix(_reconnectCtrl, 'ms'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Notes (optional)'),
                  const SizedBox(height: 6),
                  _textArea(_notesCtrl),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Connect',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _label(String text) =>
      Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13));

  Widget _field(TextEditingController ctrl,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _fieldSuffix(TextEditingController ctrl, String suffix) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _textArea(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: 'Add any notes about this connection',
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: AppTheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(12),
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
    required this.icon,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF1976D2);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade800,
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
                    color: selected ? color : Colors.grey,
                    width: 2,
                  ),
                  color: selected ? color : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.circle, size: 8, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Icon(icon, size: 34, color: color),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(sub,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
