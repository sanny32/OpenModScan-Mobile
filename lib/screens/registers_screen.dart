import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../models/device_info.dart';
import '../models/mock_data.dart';
import '../models/app_settings.dart';
import '../models/register_entry.dart';
import '../models/register_list.dart';
import '../services/connection_manager.dart';
import '../services/device_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_info_bar.dart';
import '../widgets/connection_status_chip.dart';
import '../utils/modbus_format.dart';
import '../widgets/type_badge.dart';
import 'register_detail_screen.dart';
import 'status_detail_screen.dart';

enum _MenuAction { selectDevice, addRegs, selectRegsList, removeRegs, setAllTypes }

class _ListConfig {
  final RegisterList data;
  late final TextEditingController startAddrCtrl;
  late final TextEditingController countCtrl;
  late final TextEditingController coilStartAddrCtrl;
  late final TextEditingController coilCountCtrl;

  String get name => data.name;
  set name(String v) => data.name = v;

  String get regType => data.regType;
  set regType(String v) => data.regType = v;

  String get coilType => data.coilType;
  set coilType(String v) => data.coilType = v;

  int get addrMode => data.addrMode;
  set addrMode(int v) => data.addrMode = v;

  bool get autoRefresh => data.autoRefresh;
  set autoRefresh(bool v) => data.autoRefresh = v;

  bool get coilAutoRefresh => data.coilAutoRefresh;
  set coilAutoRefresh(bool v) => data.coilAutoRefresh = v;

  _ListConfig(this.data) {
    startAddrCtrl = TextEditingController(text: data.startAddress.toString());
    countCtrl = TextEditingController(text: data.count.toString());
    coilStartAddrCtrl = TextEditingController(
      text: data.coilStartAddress.toString().padLeft(5, '0'),
    );
    coilCountCtrl = TextEditingController(text: data.coilCount.toString());

    startAddrCtrl.addListener(
        () => data.startAddress = int.tryParse(startAddrCtrl.text) ?? 1);
    countCtrl.addListener(
        () => data.count = int.tryParse(countCtrl.text) ?? 20);
    coilStartAddrCtrl.addListener(
        () => data.coilStartAddress = int.tryParse(coilStartAddrCtrl.text) ?? 0);
    coilCountCtrl.addListener(
        () => data.coilCount = int.tryParse(coilCountCtrl.text) ?? 20);
  }

  void dispose() {
    startAddrCtrl.dispose();
    countCtrl.dispose();
    coilStartAddrCtrl.dispose();
    coilCountCtrl.dispose();
  }
}

class RegistersScreen extends StatefulWidget {
  const RegistersScreen({super.key});

  @override
  State<RegistersScreen> createState() => _RegistersScreenState();
}

class _RegistersScreenState extends State<RegistersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<_ListConfig> _lists;
  int _activeList = 0;
  String _deviceName = mockDevice.name;
  final Map<int, (String, String?)> _runtimeValues = {};

  DeviceInfo? get _selectedDevice {
    final devs = DeviceRepository.instance.devices.value;
    for (final d in devs) {
      if (d.name == _deviceName) return d;
    }
    return null;
  }

  List<_ListConfig> _buildListsFromDevice() {
    final device = _selectedDevice;
    if (device != null && device.registerLists.isNotEmpty) {
      return device.registerLists.map(_ListConfig.new).toList();
    }
    final defaultList = RegisterList(name: 'List 1');
    device?.registerLists.add(defaultList);
    return [_ListConfig(defaultList)];
  }

  Future<void> _saveDevice() async {
    final device = _selectedDevice;
    if (device == null) return;
    final all = List.of(DeviceRepository.instance.devices.value);
    final idx = all.indexWhere((d) => d.name == device.name);
    if (idx >= 0) await DeviceRepository.instance.save(all);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lists = _buildListsFromDevice();
    DeviceRepository.instance.devices.addListener(_onChanged);
    ConnectionManager.instance.clients.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DeviceRepository.instance.devices.removeListener(_onChanged);
    ConnectionManager.instance.clients.removeListener(_onChanged);
    _tabController.dispose();
    for (final list in _lists) {
      list.dispose();
    }
    super.dispose();
  }

  void _handleMenu(_MenuAction action) {
    switch (action) {
      case _MenuAction.selectDevice:
        _showSelectDeviceDialog();
      case _MenuAction.addRegs:
        _addRegs();
      case _MenuAction.selectRegsList:
        _showSelectListDialog();
      case _MenuAction.removeRegs:
        _removeActiveRegs();
      case _MenuAction.setAllTypes:
        _showSetAllTypesDialog();
    }
  }

  Future<void> _addRegs() async {
    final defaultName = 'List ${_lists.length + 1}';
    final ctrl = TextEditingController(text: defaultName);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.menuAddRegs),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.dialogListNameHint,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final newList = RegisterList(name: name);
      _selectedDevice?.registerLists.add(newList);
      setState(() {
        _lists.add(_ListConfig(newList));
        _activeList = _lists.length - 1;
      });
      _saveDevice();
    }
  }

  void _removeActiveRegs() {
    if (_lists.length <= 1) return;
    _selectedDevice?.registerLists.removeAt(_activeList);
    setState(() {
      _lists[_activeList].dispose();
      _lists.removeAt(_activeList);
      if (_activeList >= _lists.length) {
        _activeList = _lists.length - 1;
      }
    });
    _saveDevice();
  }

  Future<void> _showSelectDeviceDialog() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final connected = DeviceRepository.instance.devices.value
        .where((d) => ConnectionManager.instance.isConnected(d))
        .toList();

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.menuSelectDevice),
        children: connected
            .map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d.name),
                child: Row(
                  children: [
                    Icon(Icons.memory, size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(child: Text(d.name)),
                    if (d.name == _deviceName)
                      Icon(Icons.check, size: 18, color: cs.primary),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );

    if (selected != null && selected != _deviceName) {
      for (final l in _lists) {
        l.dispose();
      }
      setState(() {
        _deviceName = selected;
        _activeList = 0;
        _lists = _buildListsFromDevice();
      });
    }
  }

  void _onValueWritten(int address, String value) {
    final prev = _runtimeValues[address]?.$1 ?? '';
    setState(() => _runtimeValues[address] = (value, prev.isEmpty ? null : prev));
  }

  void _onEntryChanged(int address, String typeName, String? comment) {
    final list = _lists[_activeList].data;
    final idx = list.entries.indexWhere((e) => e.address == address);
    if (idx >= 0) {
      list.entries[idx] = RegisterConfig(
          address: address, typeName: typeName, comment: comment);
    } else {
      list.entries.add(
          RegisterConfig(address: address, typeName: typeName, comment: comment));
    }
    setState(() {});
    _saveDevice();
  }

  Future<void> _showSelectListDialog() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.menuSelectRegsList),
        children: List.generate(
          _lists.length,
          (i) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, i),
            child: Row(
              children: [
                Icon(Icons.list, size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(_lists[i].name)),
                if (i == _activeList)
                  Icon(Icons.check, size: 18, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _activeList = selected);
    }
  }

  Future<void> _showSetAllTypesDialog() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.menuSetAllTypes),
        children: kRegisterTypes.map((t) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, t),
          child: Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: AppSettings.instance.showTypeBadgesNotifier,
                builder: (_, showBadges, _) => showBadges
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        TypeBadge(type: t),
                        const SizedBox(width: 10),
                      ])
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: Text(t, style: TextStyle(color: cs.onSurface)),
              ),
            ],
          ),
        )).toList(),
      ),
    );

    if (selected != null) _onSetAllTypes(selected);
  }

  void _onSetAllTypes(String typeName) {
    final config = _lists[_activeList];
    final list = config.data;
    final offset = _regTypeOffset(config.regType);
    final startAddr = offset + list.startAddress;

    for (var i = 0; i < list.count; i++) {
      final addr = startAddr + i;
      final idx = list.entries.indexWhere((e) => e.address == addr);
      if (idx >= 0) {
        list.entries[idx] = RegisterConfig(
          address: addr,
          typeName: typeName,
          comment: list.entries[idx].comment,
        );
      } else {
        list.entries.add(RegisterConfig(address: addr, typeName: typeName));
      }
    }
    setState(() {});
    _saveDevice();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final active = _lists[_activeList];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_deviceName, style: tt.titleMedium),
            const SizedBox(height: 2),
            ConnectionStatusChip(
              connected:
                  _selectedDevice != null &&
                  ConnectionManager.instance.isConnected(_selectedDevice!),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_MenuAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenu,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MenuAction.selectDevice,
                child: Row(
                  children: [
                    Icon(Icons.devices, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text(l10n.menuSelectDevice),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _MenuAction.addRegs,
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text(l10n.menuAddRegs),
                  ],
                ),
              ),
              PopupMenuItem(
                enabled: _lists.length > 1,
                value: _MenuAction.selectRegsList,
                child: Row(
                  children: [
                    Icon(Icons.list, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text(l10n.menuSelectRegsList),
                  ],
                ),
              ),
              if (_tabController.index == 0) ...[
                PopupMenuItem(
                  value: _MenuAction.setAllTypes,
                  child: Row(
                    children: [
                      Icon(Icons.style_outlined, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Text(l10n.menuSetAllTypes),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(
                enabled: _lists.length > 1,
                value: _MenuAction.removeRegs,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(l10n.menuRemoveRegs),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDevice != null)
            ConnectionInfoBar(device: _selectedDevice!),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.navRegisters),
              Tab(text: l10n.tabCoils),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RegistersTab(
                  regType: active.regType,
                  onRegTypeChanged: (v) => setState(() => active.regType = v),
                  addrMode: active.addrMode,
                  onAddrModeChanged: (v) => setState(() => active.addrMode = v),
                  autoRefresh: active.autoRefresh,
                  onAutoRefreshChanged: (v) =>
                      setState(() => active.autoRefresh = v),
                  startAddrCtrl: active.startAddrCtrl,
                  countCtrl: active.countCtrl,
                  registerList: active.data,
                  runtimeValues: _runtimeValues,
                  onEntryChanged: _onEntryChanged,
                  onValueWritten: _onValueWritten,
                ),
                _CoilsTab(
                  coilType: active.coilType,
                  onCoilTypeChanged: (v) => setState(() => active.coilType = v),
                  autoRefresh: active.coilAutoRefresh,
                  onAutoRefreshChanged: (v) =>
                      setState(() => active.coilAutoRefresh = v),
                  startAddrCtrl: active.coilStartAddrCtrl,
                  countCtrl: active.coilCountCtrl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _regTypeOffset(String regType) => switch (regType) {
  '4xxxx' => 40000,
  '3xxxx' => 30000,
  '1xxxx' => 10000,
  _ => 0,
};

class _RegistersTab extends StatefulWidget {
  final String regType;
  final ValueChanged<String> onRegTypeChanged;
  final int addrMode;
  final ValueChanged<int> onAddrModeChanged;
  final bool autoRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;
  final TextEditingController startAddrCtrl;
  final TextEditingController countCtrl;
  final RegisterList registerList;
  final Map<int, (String, String?)> runtimeValues;
  final void Function(int address, String typeName, String? comment) onEntryChanged;
  final void Function(int address, String value) onValueWritten;

  const _RegistersTab({
    required this.regType,
    required this.onRegTypeChanged,
    required this.addrMode,
    required this.onAddrModeChanged,
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
    required this.startAddrCtrl,
    required this.countCtrl,
    required this.registerList,
    required this.runtimeValues,
    required this.onEntryChanged,
    required this.onValueWritten,
  });

  @override
  State<_RegistersTab> createState() => _RegistersTabState();
}

class _RegistersTabState extends State<_RegistersTab> {
  void _onCtrlChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.startAddrCtrl.addListener(_onCtrlChanged);
    widget.countCtrl.addListener(_onCtrlChanged);
  }

  @override
  void didUpdateWidget(_RegistersTab old) {
    super.didUpdateWidget(old);
    if (old.startAddrCtrl != widget.startAddrCtrl) {
      old.startAddrCtrl.removeListener(_onCtrlChanged);
      widget.startAddrCtrl.addListener(_onCtrlChanged);
    }
    if (old.countCtrl != widget.countCtrl) {
      old.countCtrl.removeListener(_onCtrlChanged);
      widget.countCtrl.addListener(_onCtrlChanged);
    }
  }

  @override
  void dispose() {
    widget.startAddrCtrl.removeListener(_onCtrlChanged);
    widget.countCtrl.removeListener(_onCtrlChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final dividerColor = Theme.of(context).dividerTheme.color ?? cs.outline;
    final offset = _regTypeOffset(widget.regType);
    final rawStart = int.tryParse(widget.startAddrCtrl.text) ?? 1;
    final startAddr = offset + rawStart;
    final rawCount = int.tryParse(widget.countCtrl.text);
    final count = (rawCount == null || rawCount < 1) ? 20 : rawCount;
    final endAddr = startAddr + count - 1;
    final mockByAddress = {for (final e in mockRegisters) e.address: e};
    final configByAddress = {
      for (final e in widget.registerList.entries) e.address: e
    };
    // Build raw uint16 map for visible + 3 extra addresses (needed for 64-bit types).
    final rawInts = <int, int>{};
    for (var i = 0; i < count + 3; i++) {
      final addr = startAddr + i;
      final runtime = widget.runtimeValues[addr];
      final mock = mockByAddress[addr];
      rawInts[addr] =
          int.tryParse(runtime?.$1 ?? mock?.value ?? '') ?? 0;
    }
    final visibleRegisters = List.generate(count, (i) {
      final addr = startAddr + i;
      final mock = mockByAddress[addr];
      final config = configByAddress[addr];
      final runtime = widget.runtimeValues[addr];
      final typeName = config?.typeName ?? mock?.typeName ?? 'UInt16';
      final rawStr = runtime?.$1 ?? mock?.value ?? '0';
      return RegisterEntry(
        address: addr,
        value: rawStr,
        displayValue: computeDisplayValue(addr, typeName, rawInts),
        previousValue: runtime?.$2 ?? mock?.previousValue,
        typeName: typeName,
        comment: config?.comment ?? mock?.comment,
        timestamp: mock?.timestamp,
        date: mock?.date,
      );
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: _RegTypeDropdown(
                  value: widget.regType,
                  onChanged: widget.onRegTypeChanged,
                ),
              ),
              const SizedBox(width: 8),
              _AddrValueToggle(
                selected: widget.addrMode,
                onChanged: widget.onAddrModeChanged,
              ),
              IconButton(
                icon: const Icon(Icons.filter_list, size: 20),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 15),
                label: Text(l10n.btnRead),
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  textStyle: tt.bodyMedium,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Row(
            children: [
              Text(
                l10n.labelStart,
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: widget.startAddrCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: tt.bodyMedium,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.labelCount,
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 44,
                child: TextField(
                  controller: widget.countCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _MaxCountFormatter(),
                  ],
                  style: tt.bodyMedium,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                l10n.labelAutoRefresh,
                style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: widget.autoRefresh,
                  onChanged: widget.onAutoRefreshChanged,
                ),
              ),
              Text('1.0 s', style: tt.bodyMedium),
            ],
          ),
        ),
        Container(
          color: cs.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  l10n.colAddress,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Text(
                  l10n.colValue,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              SizedBox(
                width: 68,
                child: Text(
                  l10n.colType,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  l10n.colComment,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),
        Divider(height: 1, color: dividerColor),
        Expanded(
          child: ListView.separated(
            itemCount: visibleRegisters.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: dividerColor),
            itemBuilder: (context, i) => _RegisterRow(
              entry: visibleRegisters[i],
              canWrite: widget.regType == '4xxxx',
              onEntryChanged: widget.onEntryChanged,
              onValueWritten: widget.onValueWritten,
            ),
          ),
        ),
        Container(
          color: cs.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.registersShowing(startAddr, endAddr),
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                l10n.registersLastUpdate('10:42:35'),
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _bitRangeLabel(AppLocalizations l10n, int start, int end) {
  final raw = l10n.registersShowing(start, end);
  final startText = '$start';
  final endText = '$end';
  final startIndex = raw.indexOf(startText);
  final endIndex = raw.lastIndexOf(endText);
  if (startIndex < 0 || endIndex < 0) return raw;

  final withEnd = raw.replaceRange(
    endIndex,
    endIndex + endText.length,
    end.toString().padLeft(5, '0'),
  );
  final adjustedStartIndex = startIndex > endIndex
      ? startIndex + 5 - endText.length
      : startIndex;
  return withEnd.replaceRange(
    adjustedStartIndex,
    adjustedStartIndex + startText.length,
    start.toString().padLeft(5, '0'),
  );
}

class _CoilsTab extends StatefulWidget {
  final String coilType;
  final ValueChanged<String> onCoilTypeChanged;
  final bool autoRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;
  final TextEditingController startAddrCtrl;
  final TextEditingController countCtrl;

  const _CoilsTab({
    required this.coilType,
    required this.onCoilTypeChanged,
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
    required this.startAddrCtrl,
    required this.countCtrl,
  });

  @override
  State<_CoilsTab> createState() => _CoilsTabState();
}

class _CoilsTabState extends State<_CoilsTab> {
  late List<BitEntry> _items;

  bool get _canWrite => widget.coilType == '0xxxx';

  @override
  void initState() {
    super.initState();
    _items = List.of(mockStatusEntries);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final dividerColor = Theme.of(context).dividerTheme.color ?? cs.outline;
    final start = int.tryParse(widget.startAddrCtrl.text) ?? 0;
    final rawCount = int.tryParse(widget.countCtrl.text);
    final count = rawCount == null || rawCount < 1 ? 20 : rawCount;
    final end = start + count - 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: _CoilTypeDropdown(
                  value: widget.coilType,
                  onChanged: widget.onCoilTypeChanged,
                ),
              ),
              const SizedBox(width: 8),
              _AddrValueToggle(selected: 0, onChanged: (_) {}),
              IconButton(
                icon: const Icon(Icons.filter_list, size: 20),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 15),
                label: Text(l10n.btnRead),
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  textStyle: tt.bodyMedium,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Row(
            children: [
              Text(
                l10n.labelStart,
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: widget.startAddrCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: tt.bodyMedium,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.labelCount,
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 44,
                child: TextField(
                  controller: widget.countCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _MaxCountFormatter(max: 2000),
                  ],
                  style: tt.bodyMedium,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const Spacer(),
              Text(
                l10n.labelAutoRefresh,
                style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: widget.autoRefresh,
                  onChanged: widget.onAutoRefreshChanged,
                ),
              ),
              Text('1.0 s', style: tt.bodyMedium),
            ],
          ),
        ),
        Container(
          color: cs.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  l10n.colAddress,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              SizedBox(
                width: 124,
                child: Text(
                  l10n.colValue,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Text(
                  l10n.colComment,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),
        Divider(height: 1, color: dividerColor),
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: dividerColor),
            itemBuilder: (context, i) => _BitRow(
              entry: _items[i],
              displayAddress: start + _items[i].address,
              canWrite: _canWrite,
              onChanged: _canWrite
                  ? (value) => setState(
                      () => _items[i] = _items[i].copyWith(value: value),
                    )
                  : null,
            ),
          ),
        ),
        Container(
          color: cs.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _bitRangeLabel(l10n, start, end),
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                l10n.registersLastUpdate('10:42:35'),
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BitRow extends StatelessWidget {
  final BitEntry entry;
  final int displayAddress;
  final bool canWrite;
  final ValueChanged<bool>? onChanged;

  const _BitRow({
    required this.entry,
    required this.displayAddress,
    required this.canWrite,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatusDetailScreen(
            address: displayAddress,
            initialValue: entry.value,
            comment: entry.comment,
            canWrite: canWrite,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                displayAddress.toString().padLeft(5, '0'),
                style: tt.bodyLarge,
              ),
            ),
            SizedBox(
              width: 124,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Transform.scale(
                  scale: 0.82,
                  alignment: Alignment.centerLeft,
                  child: Switch(
                    value: entry.value,
                    onChanged: canWrite ? onChanged : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.comment,
                style: tt.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MaxCountFormatter extends TextInputFormatter {
  final int max;

  const _MaxCountFormatter({this.max = 125});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final n = int.tryParse(newValue.text);
    if (n == null || n > max) return oldValue;
    return newValue;
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
    return SizedBox(
      height: 36,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            isExpanded: true,
            dropdownColor: cs.surfaceContainerHighest,
            style: tt.bodyMedium!.copyWith(color: cs.onSurface),
            items: const [
              DropdownMenuItem(value: '4xxxx', child: Text('Holding (4xxxx)')),
              DropdownMenuItem(value: '3xxxx', child: Text('Input (3xxxx)')),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

class _CoilTypeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CoilTypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      height: 36,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            isExpanded: true,
            dropdownColor: cs.surfaceContainerHighest,
            style: tt.bodyMedium!.copyWith(color: cs.onSurface),
            items: const [
              DropdownMenuItem(value: '0xxxx', child: Text('Coils (0xxxx)')),
              DropdownMenuItem(value: '1xxxx', child: Text('Discrete (1xxxx)')),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
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
          _Btn(
            label: context.l10n.colAddress,
            active: selected == 0,
            onTap: () => onChanged(0),
          ),
          _Btn(
            label: context.l10n.colValue,
            active: selected == 1,
            onTap: () => onChanged(1),
          ),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: tt.bodySmall!.copyWith(
            color: active ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// Register write dialog opened from a row tap.
Future<void> _showWriteRegisterDialog(
  BuildContext context,
  RegisterEntry entry,
) async {
  final l10n = context.l10n;
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final ctrl = TextEditingController(text: entry.value);
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
                  '${entry.address}',
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
                  entry.value,
                  style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                ),
                if (entry.previousValue != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '← ${entry.previousValue}',
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
              onSubmitted: (_) {
                final raw = int.tryParse(ctrl.text);
                if (raw == null || raw < 0 || raw > 65535) {
                  setInnerState(() => error = l10n.writeValueRange);
                  return;
                }
                // TODO: perform actual Modbus write
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final raw = int.tryParse(ctrl.text);
              if (raw == null || raw < 0 || raw > 65535) {
                setInnerState(() => error = l10n.writeValueRange);
                return;
              }
              // TODO: perform actual Modbus write
              Navigator.pop(ctx);
            },
            child: Text(l10n.btnWrite),
          ),
        ],
      ),
    ),
  );
}

class _RegisterRow extends StatelessWidget {
  final RegisterEntry entry;
  final bool canWrite;
  final void Function(int address, String typeName, String? comment)? onEntryChanged;
  final void Function(int address, String value)? onValueWritten;

  const _RegisterRow({
    required this.entry,
    required this.canWrite,
    this.onEntryChanged,
    this.onValueWritten,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterDetailScreen(
            entry: entry,
            canWrite: canWrite,
            onSaved: onEntryChanged != null
                ? (type, comment) => onEntryChanged!(entry.address, type, comment)
                : null,
            onValueWritten: onValueWritten != null
                ? (v) => onValueWritten!(entry.address, v)
                : null,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text('${entry.address}', style: tt.bodyLarge),
            ),
            Expanded(
              child: InkWell(
                onTap: canWrite
                    ? () => _showWriteRegisterDialog(context, entry)
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.displayValue ?? entry.value,
                      style: tt.bodyLarge!.copyWith(
                        color: appColors.valueColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (entry.previousValue != null)
                      Text(
                        entry.previousValue!,
                        style: tt.bodySmall!.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: AppSettings.instance.showTypeBadgesNotifier,
              builder: (_, showBadges, _) => SizedBox(
                width: 68,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: showBadges
                      ? TypeBadge(type: entry.typeName)
                      : Text(
                          entry.typeName,
                          style: tt.bodyMedium!
                              .copyWith(color: appColors.typeColor),
                        ),
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                entry.comment ?? '',
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
