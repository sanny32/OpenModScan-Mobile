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
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(device.name, style: tt.titleMedium),
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
                Center(
                  child: Text('Coils',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dividerColor = Theme.of(context).dividerTheme.color ?? cs.outline;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                  child: _RegTypeDropdown(
                      value: regType, onChanged: onRegTypeChanged)),
              const SizedBox(width: 8),
              _AddrValueToggle(
                  selected: addrMode, onChanged: onAddrModeChanged),
              IconButton(
                icon: const Icon(Icons.filter_list, size: 20),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Read'),
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  textStyle: tt.bodyMedium,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Text('Quantity: ',
                  style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant)),
              Text('20',
                  style: tt.bodyMedium!.copyWith(
                      color: cs.primary, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('Auto refresh',
                  style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant)),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                    value: autoRefresh, onChanged: onAutoRefreshChanged),
              ),
              Text('1.0 s', style: tt.bodyMedium),
            ],
          ),
        ),
        Container(
          color: cs.surfaceContainer,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                  width: 72,
                  child: Text('Address',
                      style: tt.bodySmall!
                          .copyWith(color: cs.onSurfaceVariant))),
              Expanded(
                  child: Text('Value',
                      style: tt.bodySmall!
                          .copyWith(color: cs.onSurfaceVariant))),
              SizedBox(
                  width: 68,
                  child: Text('Type',
                      style: tt.bodySmall!
                          .copyWith(color: cs.onSurfaceVariant))),
              SizedBox(
                  width: 56,
                  child: Text('Quality',
                      style: tt.bodySmall!
                          .copyWith(color: cs.onSurfaceVariant))),
              const SizedBox(width: 24),
            ],
          ),
        ),
        Divider(height: 1, color: dividerColor),
        Expanded(
          child: ListView.separated(
            itemCount: mockRegisters.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: dividerColor),
            itemBuilder: (context, i) =>
                _RegisterRow(entry: mockRegisters[i]),
          ),
        ),
        Container(
          color: cs.surfaceContainer,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Showing 40001 – 40020',
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
              Text('Last update: 10:42:35',
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: cs.surfaceContainerHighest,
          style: tt.bodyMedium!.copyWith(color: cs.onSurface),
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
  const _AddrValueToggle(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(label: 'Address', active: selected == 0,
              onTap: () => onChanged(0)),
          _Btn(label: 'Value', active: selected == 1,
              onTap: () => onChanged(1)),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Btn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: tt.bodySmall!.copyWith(
                color: active ? cs.onPrimary : cs.onSurfaceVariant)),
      ),
    );
  }
}

class _RegisterRow extends StatelessWidget {
  final RegisterEntry entry;
  const _RegisterRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    return InkWell(
      onTap: () {},
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text('${entry.address}', style: tt.bodyLarge),
            ),
            Expanded(
              child: Text(entry.value,
                  style: tt.bodyLarge!.copyWith(
                      color: appColors.valueColor,
                      fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              width: 68,
              child: Text(entry.typeName,
                  style: tt.bodyMedium!.copyWith(color: appColors.typeColor)),
            ),
            SizedBox(
              width: 56,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: appColors.qualityGood,
                    shape: BoxShape.circle),
              ),
            ),
            Icon(Icons.chevron_right,
                color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
