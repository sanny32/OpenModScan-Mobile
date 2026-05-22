import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../../models/device_info.dart';
import '../../models/app_settings.dart';
import '../../models/register_entry.dart';
import '../../models/register_list.dart';
import '../../models/status_entry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/connection_info_bar.dart';
import '../../widgets/connection_status_chip.dart';
import '../../utils/modbus_format.dart';
import '../../widgets/type_badge.dart';
import 'register_list_dialogs.dart';
import 'registers_controller.dart';
import 'register_detail_screen.dart';
import 'status_detail_screen.dart';

part 'registers_list_config.dart';

enum _MenuAction {
  selectDevice,
  removeRegs,
  setAllTypes,
}

class RegistersScreen extends StatefulWidget {
  final RegistersController controller;
  final ValueListenable<String?> returnDeviceId;
  final ValueListenable<bool>? screenActive;
  final VoidCallback onReturnToDevice;

  const RegistersScreen({
    super.key,
    required this.controller,
    required this.returnDeviceId,
    this.screenActive,
    required this.onReturnToDevice,
  });

  @override
  State<RegistersScreen> createState() => _RegistersScreenState();
}

class _RegistersScreenState extends State<RegistersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<_ListConfig> _lists;
  String _listSignature = '';
  int _activeList = 0;
  var _activeTab = 0;

  DeviceInfo? get _selectedDevice => widget.controller.selectedDevice;
  bool get _screenActive => widget.screenActive?.value ?? true;

  List<_ListConfig> _buildListsFromDevice() {
    final lists = widget.controller.lists;
    if (lists.isNotEmpty) {
      return lists
          .map(
            (list) => _ListConfig(
              list,
              onChanged: (updated) => widget.controller.updateList(updated),
            ),
          )
          .toList();
    }
    return [_ListConfig(RegisterList(name: 'List 1'))];
  }

  String get _currentListSignature {
    final listsSignature = widget.controller.lists
        .map((list) {
          final entriesSignature = Object.hashAll(
            list.entries.map(
              (entry) =>
                  Object.hash(entry.address, entry.typeName, entry.comment),
            ),
          );
          final statusEntriesSignature = Object.hashAll(
            list.statusEntries.map(
              (entry) =>
                  Object.hash(entry.statusType, entry.address, entry.comment),
            ),
          );
          return '${list.id}:$entriesSignature:$statusEntriesSignature';
        })
        .join(',');
    return '${widget.controller.selectedDeviceId}:'
        '$listsSignature:'
        '${widget.controller.activeList?.id}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lists = _buildListsFromDevice();
    _listSignature = _currentListSignature;
    _tabController.addListener(_onTabChanged);
    _tabController.animation?.addListener(_onTabAnimationChanged);
    widget.controller.addListener(_onChanged);
    widget.screenActive?.addListener(_onScreenActiveChanged);
    widget.controller.ensureSelectedList();
  }

  @override
  void didUpdateWidget(RegistersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenActive != widget.screenActive) {
      oldWidget.screenActive?.removeListener(_onScreenActiveChanged);
      widget.screenActive?.addListener(_onScreenActiveChanged);
    }
  }

  void _onTabChanged() {
    _setActiveTab(_tabController.index);
  }

  void _onTabAnimationChanged() {
    if (_tabController.indexIsChanging) return;

    final index = _tabController.animation?.value.round();
    if (index != null) {
      _setActiveTab(index.clamp(0, _tabController.length - 1));
    }
  }

  void _onScreenActiveChanged() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    if (!mounted) return;
    final signature = _currentListSignature;
    if (signature != _listSignature) {
      for (final list in _lists) {
        list.dispose();
      }
      _lists = _buildListsFromDevice();
      _activeList = widget.controller.activeListIndex.clamp(
        0,
        _lists.length - 1,
      );
      _listSignature = signature;
      final activeType = _lists[_activeList].data.regType;
      if (activeType == '0xxxx' || activeType == '1xxxx') {
        _tabController.animateTo(1);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.screenActive?.removeListener(_onScreenActiveChanged);
    _tabController.animation?.removeListener(_onTabAnimationChanged);
    _tabController.removeListener(_onTabChanged);
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
      case _MenuAction.removeRegs:
        _removeActiveRegs();
      case _MenuAction.setAllTypes:
        _showSetAllTypesDialog();
    }
  }

  Future<void> _addList() async {
    final result = await showRegisterListDialog(
      context,
      defaultName: 'List ${_lists.length + 1}',
    );

    if (!mounted) return;
    if (result != null) {
      await widget.controller.addList(result);
    }
  }

  Future<void> _removeActiveRegs() async {
    await widget.controller.removeActiveList();
  }

  Future<void> _showSelectDeviceDialog() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final connected = widget.controller.connectedDevices;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.menuSelectDevice),
        children: connected
            .map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d.id),
                child: Row(
                  children: [
                    Icon(Icons.memory, size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(child: Text(d.name)),
                    if (d.id == widget.controller.selectedDeviceId)
                      Icon(Icons.check, size: 18, color: cs.primary),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );

    if (selected != null && selected != widget.controller.selectedDeviceId) {
      await widget.controller.selectDevice(selected);
    }
  }

  Future<void> _onValueWritten(int address, String value) =>
      widget.controller.writeValue(address, value);

  Future<void> _onEntryChanged(int address, String typeName, String? comment) =>
      widget.controller.updateEntry(address, typeName, comment);

  Future<void> _showSetAllTypesDialog() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.menuSetAllTypes),
        children: kRegisterTypes
            .map(
              (t) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, t),
                child: Row(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          AppSettings.instance.showTypeBadgesNotifier,
                      builder: (_, showBadges, _) => showBadges
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TypeBadge(type: t),
                                const SizedBox(width: 10),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: Text(t, style: TextStyle(color: cs.onSurface)),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );

    if (selected != null) {
      await widget.controller.setAllTypes(selected);
    }
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
        leading: ValueListenableBuilder<String?>(
          valueListenable: widget.returnDeviceId,
          builder: (context, returnDeviceId, _) => returnDeviceId == null
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onReturnToDevice,
                ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedDevice?.name ?? l10n.navRegisters,
              style: tt.titleMedium,
            ),
            const SizedBox(height: 2),
            ConnectionStatusChip(
              connected:
                  _selectedDevice != null &&
                  widget.controller.isConnected(_selectedDevice!),
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
              if (_tabController.index == 0) ...[
                PopupMenuItem(
                  value: _MenuAction.setAllTypes,
                  child: Row(
                    children: [
                      Icon(
                        Icons.style_outlined,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
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
                  onRegTypeChanged: (v) =>
                      _updateActiveList(active..regType = v),
                  listNames: _lists.map((l) => l.name).toList(),
                  activeListIndex: _activeList,
                  onListChanged: (i) {
                    setState(() => _activeList = i);
                    widget.controller.selectList(_lists[i].data.id);
                  },
                  onAddList: _addList,
                  autoRefresh: active.autoRefresh,

                  isActive: _screenActive && _activeTab == 0,
                  onAutoRefreshChanged: (v) =>
                      _updateActiveList(active..autoRefresh = v),
                  autoRefreshIntervalMs: active.refreshIntervalMs,
                  refreshIntervalCtrl: active.refreshIntervalCtrl,
                  onRefreshIntervalCommitted: active.commitRefreshInterval,
                  startAddrCtrl: active.startAddrCtrl,
                  countCtrl: active.countCtrl,
                  registerList: active.data,
                  runtimeValues: widget.controller.runtimeValues,
                  lastReadAt: widget.controller.lastRegisterReadAt,
                  referenceRegisters: widget.controller.referenceRegisters,
                  canRead:
                      _selectedDevice != null &&
                      widget.controller.isConnected(_selectedDevice!),
                  onRead: widget.controller.readRegisters,
                  onEntryChanged: _onEntryChanged,
                  onValueWritten: _onValueWritten,
                ),
                _CoilsTab(
                  coilType: active.coilType,
                  onCoilTypeChanged: (v) =>
                      _updateActiveList(active..coilType = v),
                  listNames: _lists.map((l) => l.name).toList(),
                  activeListIndex: _activeList,
                  onListChanged: (i) {
                    setState(() => _activeList = i);
                    widget.controller.selectList(_lists[i].data.id);
                  },
                  onAddList: _addList,
                  autoRefresh: active.coilAutoRefresh,
                  isActive: _screenActive && _activeTab == 1,
                  onAutoRefreshChanged: (v) =>
                      _updateActiveList(active..coilAutoRefresh = v),
                  autoRefreshIntervalMs: active.coilRefreshIntervalMs,
                  refreshIntervalCtrl: active.coilRefreshIntervalCtrl,
                  onRefreshIntervalCommitted: active.commitCoilRefreshInterval,
                  startAddrCtrl: active.coilStartAddrCtrl,
                  countCtrl: active.coilCountCtrl,
                  registerList: active.data,
                  runtimeValues: widget.controller.runtimeStatusValues,
                  lastReadAt: widget.controller.lastStatusReadAt,
                  referenceStatuses: widget.controller.referenceStatuses,
                  canRead:
                      _selectedDevice != null &&
                      widget.controller.isConnected(_selectedDevice!),
                  onRead: widget.controller.readStatuses,
                  onEntryChanged: (address, comment) => widget.controller
                      .updateStatusEntry(active.coilType, address, comment),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateActiveList(_ListConfig active) {
    setState(() {});
    widget.controller.updateList(active.data);
  }

  void _setActiveTab(int index) {
    if (_activeTab != index) {
      setState(() => _activeTab = index);
    }
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
  final List<String> listNames;
  final int activeListIndex;
  final ValueChanged<int> onListChanged;
  final VoidCallback onAddList;
  final bool autoRefresh;
  final bool isActive;
  final ValueChanged<bool> onAutoRefreshChanged;
  final int autoRefreshIntervalMs;
  final TextEditingController refreshIntervalCtrl;
  final VoidCallback onRefreshIntervalCommitted;
  final TextEditingController startAddrCtrl;
  final TextEditingController countCtrl;
  final RegisterList registerList;
  final Map<int, (String, String?, DateTime?)> runtimeValues;
  final DateTime? lastReadAt;
  final List<RegisterEntry> Function(int startAddress, int count)
  referenceRegisters;
  final bool canRead;
  final Future<void> Function({
    required String regType,
    required int startAddress,
    required int count,
  })
  onRead;
  final void Function(int address, String typeName, String? comment)
  onEntryChanged;
  final void Function(int address, String value) onValueWritten;

  const _RegistersTab({
    required this.regType,
    required this.onRegTypeChanged,
    required this.listNames,
    required this.activeListIndex,
    required this.onListChanged,
    required this.onAddList,
    required this.autoRefresh,
    required this.isActive,
    required this.onAutoRefreshChanged,
    required this.autoRefreshIntervalMs,
    required this.refreshIntervalCtrl,
    required this.onRefreshIntervalCommitted,
    required this.startAddrCtrl,
    required this.countCtrl,
    required this.registerList,
    required this.runtimeValues,
    required this.lastReadAt,
    required this.referenceRegisters,
    required this.canRead,
    required this.onRead,
    required this.onEntryChanged,
    required this.onValueWritten,
  });

  @override
  State<_RegistersTab> createState() => _RegistersTabState();
}

class _RegistersTabState extends State<_RegistersTab> {
  var _reading = false;
  var _manualReadInProgress = false;
  Timer? _autoRefreshTimer;

  void _onCtrlChanged() => setState(() {});

  bool get _supportsRegisterRead =>
      widget.regType == '4xxxx' || widget.regType == '3xxxx';

  @override
  void initState() {
    super.initState();
    widget.startAddrCtrl.addListener(_onCtrlChanged);
    widget.countCtrl.addListener(_onCtrlChanged);
    _syncAutoRefresh(readImmediately: true);
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
    if (old.autoRefresh != widget.autoRefresh ||
        old.isActive != widget.isActive ||
        old.autoRefreshIntervalMs != widget.autoRefreshIntervalMs ||
        old.canRead != widget.canRead ||
        old.regType != widget.regType) {
      _syncAutoRefresh(
        readImmediately:
            widget.autoRefresh &&
            (!old.autoRefresh ||
                !old.isActive && widget.isActive ||
                !old.canRead && widget.canRead),
      );
    }
  }

  @override
  void dispose() {
    widget.startAddrCtrl.removeListener(_onCtrlChanged);
    widget.countCtrl.removeListener(_onCtrlChanged);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _syncAutoRefresh({bool readImmediately = false}) {
    _autoRefreshTimer?.cancel();
    if (!widget.autoRefresh || !widget.isActive) return;

    _autoRefreshTimer = Timer.periodic(
      Duration(milliseconds: widget.autoRefreshIntervalMs),
      (_) {
        _read(showErrors: false, showProgress: false);
      },
    );
    if (readImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.autoRefresh && widget.isActive) {
          _read(showErrors: false, showProgress: false);
        }
      });
    }
  }

  Future<void> _read({bool showErrors = true, bool showProgress = true}) async {
    if (_reading ||
        !widget.isActive ||
        !widget.canRead ||
        !_supportsRegisterRead) {
      return;
    }

    final offset = _regTypeOffset(widget.regType);
    final rawStart = int.tryParse(widget.startAddrCtrl.text) ?? 1;
    final rawCount = int.tryParse(widget.countCtrl.text);
    final count = (rawCount == null || rawCount < 1) ? 20 : rawCount;

    _reading = true;
    if (showProgress) {
      setState(() => _manualReadInProgress = true);
    }
    try {
      await widget.onRead(
        regType: widget.regType,
        startAddress: offset + rawStart,
        count: count,
      );
      if (!mounted) return;
    } catch (error) {
      if (!mounted || !showErrors) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      _reading = false;
      if (mounted) {
        if (showProgress) {
          setState(() => _manualReadInProgress = false);
        }
      }
    }
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
    final mockByAddress = {
      for (final e in widget.referenceRegisters(startAddr, count + 3))
        e.address: e,
    };
    final configByAddress = {
      for (final e in widget.registerList.entries) e.address: e,
    };
    // Build raw uint16 map for visible + 3 extra addresses (needed for 64-bit types).
    final rawInts = <int, int>{};
    for (var i = 0; i < count + 3; i++) {
      final addr = startAddr + i;
      final runtime = widget.runtimeValues[addr];
      final mock = mockByAddress[addr];
      rawInts[addr] = int.tryParse(runtime?.$1 ?? mock?.value ?? '') ?? 0;
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
        timestamp: runtime?.$3 == null
            ? mock?.timestamp
            : _formatTimestamp(runtime!.$3!),
        date: runtime?.$3 == null ? mock?.date : _formatDate(runtime!.$3!),
      );
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              _ListDropdown(
                names: widget.listNames,
                activeIndex: widget.activeListIndex,
                onChanged: widget.onListChanged,
                onAdd: widget.onAddList,
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '4xxxx', label: Text('4xxxx')),
                  ButtonSegment(value: '3xxxx', label: Text('3xxxx')),
                ],
                selected: {widget.regType},
                onSelectionChanged: (s) => widget.onRegTypeChanged(s.first),
                style: _segmentedButtonStyle(context),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: _manualReadInProgress
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 15),
                label: Text(l10n.btnRead),
                onPressed:
                    widget.canRead &&
                        _supportsRegisterRead &&
                        !_manualReadInProgress
                    ? _read
                    : null,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
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
              const SizedBox(width: 4),
              SizedBox(
                width: 58,
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
              const SizedBox(width: 8),
              Text(
                l10n.labelCount,
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 42,
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
              Tooltip(
                message: l10n.labelAutoRefresh,
                child: Icon(
                  Icons.update_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 42,
                height: 32,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: widget.autoRefresh,
                    onChanged: widget.onAutoRefreshChanged,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    widget.onRefreshIntervalCommitted();
                  }
                },
                child: SizedBox(
                  width: 58,
                  child: TextField(
                    controller: widget.refreshIntervalCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _MaxCountFormatter(max: kMaxRegisterRefreshIntervalMs),
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
                    onEditingComplete: () {
                      widget.onRefreshIntervalCommitted();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('ms', style: tt.bodyMedium),
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
                  l10n.colComment,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.colValue,
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
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
                l10n.registersLastUpdate(
                  widget.lastReadAt == null
                      ? '--:--:--'
                      : _formatTimestamp(widget.lastReadAt!),
                ),
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatTimestamp(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}:'
    '${value.second.toString().padLeft(2, '0')}';

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.'
    '${value.year.toString().padLeft(4, '0')}';

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
  final List<String> listNames;
  final int activeListIndex;
  final ValueChanged<int> onListChanged;
  final VoidCallback onAddList;
  final bool autoRefresh;
  final bool isActive;
  final ValueChanged<bool> onAutoRefreshChanged;
  final int autoRefreshIntervalMs;
  final TextEditingController refreshIntervalCtrl;
  final VoidCallback onRefreshIntervalCommitted;
  final TextEditingController startAddrCtrl;
  final TextEditingController countCtrl;
  final RegisterList registerList;
  final Map<(String, int), (bool, bool?, DateTime?)> runtimeValues;
  final DateTime? lastReadAt;
  final List<StatusEntry> Function(int startAddress, int count)
  referenceStatuses;
  final bool canRead;
  final Future<void> Function({
    required String statusType,
    required int startAddress,
    required int count,
  })
  onRead;
  final void Function(int address, String? comment) onEntryChanged;

  const _CoilsTab({
    required this.coilType,
    required this.onCoilTypeChanged,
    required this.listNames,
    required this.activeListIndex,
    required this.onListChanged,
    required this.onAddList,
    required this.autoRefresh,
    required this.isActive,
    required this.onAutoRefreshChanged,
    required this.autoRefreshIntervalMs,
    required this.refreshIntervalCtrl,
    required this.onRefreshIntervalCommitted,
    required this.startAddrCtrl,
    required this.countCtrl,
    required this.registerList,
    required this.runtimeValues,
    required this.lastReadAt,
    required this.referenceStatuses,
    required this.canRead,
    required this.onRead,
    required this.onEntryChanged,
  });

  @override
  State<_CoilsTab> createState() => _CoilsTabState();
}

class _CoilsTabState extends State<_CoilsTab> {
  final _manualValues = <int, bool>{};
  var _reading = false;
  var _manualReadInProgress = false;
  Timer? _autoRefreshTimer;

  bool get _canWrite => widget.coilType == '0xxxx';

  bool get _supportsStatusRead =>
      widget.coilType == '0xxxx' || widget.coilType == '1xxxx';

  void _onCtrlChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.startAddrCtrl.addListener(_onCtrlChanged);
    widget.countCtrl.addListener(_onCtrlChanged);
    _syncAutoRefresh(readImmediately: true);
  }

  @override
  void didUpdateWidget(_CoilsTab old) {
    super.didUpdateWidget(old);
    if (old.startAddrCtrl != widget.startAddrCtrl) {
      old.startAddrCtrl.removeListener(_onCtrlChanged);
      widget.startAddrCtrl.addListener(_onCtrlChanged);
    }
    if (old.countCtrl != widget.countCtrl) {
      old.countCtrl.removeListener(_onCtrlChanged);
      widget.countCtrl.addListener(_onCtrlChanged);
    }
    if (old.autoRefresh != widget.autoRefresh ||
        old.isActive != widget.isActive ||
        old.autoRefreshIntervalMs != widget.autoRefreshIntervalMs ||
        old.canRead != widget.canRead ||
        old.coilType != widget.coilType) {
      _syncAutoRefresh(
        readImmediately:
            widget.autoRefresh &&
            (!old.autoRefresh ||
                !old.isActive && widget.isActive ||
                !old.canRead && widget.canRead),
      );
    }
  }

  @override
  void dispose() {
    widget.startAddrCtrl.removeListener(_onCtrlChanged);
    widget.countCtrl.removeListener(_onCtrlChanged);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _syncAutoRefresh({bool readImmediately = false}) {
    _autoRefreshTimer?.cancel();
    if (!widget.autoRefresh || !widget.isActive) return;

    _autoRefreshTimer = Timer.periodic(
      Duration(milliseconds: widget.autoRefreshIntervalMs),
      (_) => _read(showErrors: false, showProgress: false),
    );
    if (readImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.autoRefresh && widget.isActive) {
          _read(showErrors: false, showProgress: false);
        }
      });
    }
  }

  Future<void> _read({bool showErrors = true, bool showProgress = true}) async {
    if (_reading ||
        !widget.isActive ||
        !widget.canRead ||
        !_supportsStatusRead) {
      return;
    }

    final start = int.tryParse(widget.startAddrCtrl.text) ?? 0;
    final rawCount = int.tryParse(widget.countCtrl.text);
    final count = rawCount == null || rawCount < 1 ? 20 : rawCount;

    _reading = true;
    if (showProgress) {
      setState(() => _manualReadInProgress = true);
    }
    try {
      await widget.onRead(
        statusType: widget.coilType,
        startAddress: start,
        count: count,
      );
      if (!mounted) return;
    } catch (error) {
      if (!mounted || !showErrors) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      _reading = false;
      if (mounted && showProgress) {
        setState(() => _manualReadInProgress = false);
      }
    }
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
    final references = {
      for (final e in widget.referenceStatuses(start, count)) e.address: e,
    };
    final configByAddress = {
      for (final e in widget.registerList.statusEntries)
        if (e.statusType == widget.coilType) e.address: e,
    };
    final visibleStatuses = List.generate(count, (i) {
      final address = start + i;
      final reference = references[address];
      final runtime = widget.runtimeValues[(widget.coilType, address)];
      final value =
          runtime?.$1 ?? _manualValues[address] ?? reference?.value ?? false;
      return StatusEntry(
        address: address,
        value: value,
        previousValue: runtime?.$2 ?? reference?.previousValue,
        comment: configByAddress[address]?.comment ?? reference?.comment ?? '',
        timestamp: runtime?.$3 == null
            ? reference?.timestamp
            : _formatTimestamp(runtime!.$3!),
        date: runtime?.$3 == null ? reference?.date : _formatDate(runtime!.$3!),
      );
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              _ListDropdown(
                names: widget.listNames,
                activeIndex: widget.activeListIndex,
                onChanged: widget.onListChanged,
                onAdd: widget.onAddList,
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '0xxxx', label: Text('0xxxx')),
                  ButtonSegment(value: '1xxxx', label: Text('1xxxx')),
                ],
                selected: {widget.coilType},
                onSelectionChanged: (s) => widget.onCoilTypeChanged(s.first),
                style: _segmentedButtonStyle(context),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: _manualReadInProgress
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 15),
                label: Text(l10n.btnRead),
                onPressed:
                    widget.canRead &&
                        _supportsStatusRead &&
                        !_manualReadInProgress
                    ? _read
                    : null,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
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
              const SizedBox(width: 4),
              SizedBox(
                width: 58,
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
              const SizedBox(width: 8),
              Text(
                l10n.labelCount,
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 42,
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
                ),
              ),
              const Spacer(),
              Tooltip(
                message: l10n.labelAutoRefresh,
                child: Icon(
                  Icons.update_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 42,
                height: 32,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: widget.autoRefresh,
                    onChanged: widget.onAutoRefreshChanged,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    widget.onRefreshIntervalCommitted();
                  }
                },
                child: SizedBox(
                  width: 58,
                  child: TextField(
                    controller: widget.refreshIntervalCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _MaxCountFormatter(max: kMaxRegisterRefreshIntervalMs),
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
                    onEditingComplete: () {
                      widget.onRefreshIntervalCommitted();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('ms', style: tt.bodyMedium),
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
                  l10n.colComment,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.colValue,
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),
        Divider(height: 1, color: dividerColor),
        Expanded(
          child: ListView.separated(
            itemCount: visibleStatuses.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: dividerColor),
            itemBuilder: (context, i) => _StatusRow(
              entry: visibleStatuses[i],
              canWrite: _canWrite,
              onEntryChanged: widget.onEntryChanged,
              onChanged: _canWrite
                  ? (value) => setState(() {
                      _manualValues[visibleStatuses[i].address] = value;
                    })
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
                l10n.registersLastUpdate(
                  widget.lastReadAt == null
                      ? '--:--:--'
                      : _formatTimestamp(widget.lastReadAt!),
                ),
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final StatusEntry entry;
  final bool canWrite;
  final ValueChanged<bool>? onChanged;
  final void Function(int address, String? comment)? onEntryChanged;

  const _StatusRow({
    required this.entry,
    required this.canWrite,
    required this.onChanged,
    required this.onEntryChanged,
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
            address: entry.address,
            initialValue: entry.value,
            comment: entry.comment,
            canWrite: canWrite,
            timestamp: entry.timestamp,
            date: entry.date,
            onSaved: onEntryChanged == null
                ? null
                : (comment) => onEntryChanged!(entry.address, comment),
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
                entry.address.toString().padLeft(5, '0'),
                style: tt.bodyLarge,
              ),
            ),
            Expanded(
              child: Text(
                entry.comment,
                style: tt.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Transform.scale(
                scale: 0.82,
                alignment: Alignment.centerRight,
                child: Switch(
                  value: entry.value,
                  onChanged: canWrite ? onChanged : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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

ButtonStyle _segmentedButtonStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  return ButtonStyle(
    textStyle: WidgetStatePropertyAll(tt.bodyMedium),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12),
    ),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return cs.primary;
      return cs.surfaceContainerHighest;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return cs.onPrimary;
      return cs.onSurface;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return cs.onPrimary;
      return cs.onSurface;
    }),
    side: WidgetStatePropertyAll(
      BorderSide(color: Theme.of(context).dividerColor),
    ),
  );
}

class _ListDropdown extends StatelessWidget {
  final List<String> names;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onAdd;
  const _ListDropdown({
    required this.names,
    required this.activeIndex,
    required this.onChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 100),
        child: SizedBox(
          height: 36,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: activeIndex,
                isDense: true,
                dropdownColor: cs.surfaceContainerHighest,
                style: tt.bodyMedium!.copyWith(color: cs.onSurface),
                items: [
                  for (var i = 0; i < names.length; i++)
                    DropdownMenuItem(value: i, child: Text(names[i])),
                  DropdownMenuItem(
                    value: -1,
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          'New List',
                          style: tt.bodyMedium!.copyWith(color: cs.primary),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  if (v == -1) {
                    onAdd();
                  } else {
                    onChanged(v);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  final void Function(int address, String typeName, String? comment)?
  onEntryChanged;
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
                ? (type, comment) =>
                      onEntryChanged!(entry.address, type, comment)
                : null,
            onValueWritten: onValueWritten != null
                ? (v) => onValueWritten!(entry.address, v)
                : null,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${entry.address}', style: tt.bodyLarge),
                  ValueListenableBuilder<bool>(
                    valueListenable: AppSettings.instance.showTypeBadgesNotifier,
                    builder: (_, showBadges, _) => showBadges
                        ? TypeBadge(type: entry.typeName)
                        : Text(
                            entry.typeName,
                            style: tt.bodySmall!.copyWith(
                              color: appColors.typeColor,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                entry.comment ?? '',
                style: tt.bodyMedium!.copyWith(color: cs.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: canWrite
                  ? () => _showWriteRegisterDialog(context, entry)
                  : null,
              borderRadius: BorderRadius.circular(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.displayValue ?? entry.value,
                    style: tt.bodyLarge!.copyWith(
                      color: appColors.valueColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        AppSettings.instance.showLastValuesNotifier,
                    builder: (_, showLastValues, _) {
                      if (!showLastValues || entry.previousValue == null) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        entry.previousValue!,
                        style: tt.bodySmall!.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
