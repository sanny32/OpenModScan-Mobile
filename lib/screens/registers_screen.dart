import 'package:flutter/material.dart';
import '../models/device_info.dart';
import '../models/register_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_info_bar.dart';
import '../widgets/connection_status_chip.dart';

class RegistersScreen extends StatefulWidget {
  const RegistersScreen({super.key});

  @override
  State<RegistersScreen> createState() => _RegistersScreenState();
}

class _RegistersScreenState extends State<RegistersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _regType = 'Holding Registers (4xxxx)';
  int _addrMode = 0;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const device = mockDevice;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(device.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            ConnectionStatusChip(connected: device.connected),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          ConnectionInfoBar(device: device),
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Registers'), Tab(text: 'Coils')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RegistersTab(
                  regType: _regType,
                  onRegTypeChanged: (v) => setState(() => _regType = v),
                  addrMode: _addrMode,
                  onAddrModeChanged: (v) => setState(() => _addrMode = v),
                  autoRefresh: _autoRefresh,
                  onAutoRefreshChanged: (v) =>
                      setState(() => _autoRefresh = v),
                ),
                const Center(
                  child: Text('Coils',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistersTab extends StatelessWidget {
  final String regType;
  final ValueChanged<String> onRegTypeChanged;
  final int addrMode;
  final ValueChanged<int> onAddrModeChanged;
  final bool autoRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;

  const _RegistersTab({
    required this.regType,
    required this.onRegTypeChanged,
    required this.addrMode,
    required this.onAddrModeChanged,
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Expanded(child: _RegTypeDropdown(value: regType, onChanged: onRegTypeChanged)),
              const SizedBox(width: 8),
              _AddrValueToggle(selected: addrMode, onChanged: onAddrModeChanged),
              IconButton(
                icon: const Icon(Icons.filter_list, size: 20),
                onPressed: () {},
                tooltip: 'Filter',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Read', style: TextStyle(fontSize: 13)),
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        // Quantity + auto refresh row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              const Text('Quantity: ',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const Text('20',
                  style: TextStyle(
                      color: Color(0xFF1976D2),
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('Auto refresh',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: autoRefresh,
                  onChanged: onAutoRefreshChanged,
                ),
              ),
              const Text('1.0 s',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        // Table header
        Container(
          color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              SizedBox(
                  width: 72,
                  child: Text('Address',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12))),
              Expanded(
                  child: Text('Value',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12))),
              SizedBox(
                  width: 68,
                  child: Text('Type',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12))),
              SizedBox(
                  width: 56,
                  child: Text('Quality',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12))),
              SizedBox(width: 24),
            ],
          ),
        ),
        const Divider(height: 1),
        // Rows
        Expanded(
          child: ListView.separated(
            itemCount: mockRegisters.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) =>
                _RegisterRow(entry: mockRegisters[i]),
          ),
        ),
        // Footer
        Container(
          color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Showing 40001 – 40020',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text('Last update: 10:42:35',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RegTypeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _RegTypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF252525),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: const [
            DropdownMenuItem(
                value: 'Holding Registers (4xxxx)',
                child: Text('Holding Registers (4xxxx)')),
            DropdownMenuItem(
                value: 'Input Registers (3xxxx)',
                child: Text('Input Registers (3xxxx)')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _AddrValueToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _AddrValueToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(label: 'Address', active: selected == 0, onTap: () => onChanged(0)),
          _Btn(label: 'Value', active: selected == 1, onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1976D2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.grey,
                fontSize: 12)),
      ),
    );
  }
}

class _RegisterRow extends StatelessWidget {
  final RegisterEntry entry;
  const _RegisterRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text('${entry.address}',
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            Expanded(
              child: Text(entry.value,
                  style: const TextStyle(
                      color: AppTheme.valueColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              width: 68,
              child: Text(entry.typeName,
                  style: const TextStyle(
                      color: AppTheme.typeColor, fontSize: 13)),
            ),
            SizedBox(
              width: 56,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppTheme.qualityGood, shape: BoxShape.circle),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
