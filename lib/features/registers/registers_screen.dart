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
  addRegs,
  selectRegsList,
  removeRegs,
  setAllTypes,
}

class RegistersScreen extends StatefulWidget {
  final RegistersController controller;
  final ValueListenable<String?> returnDeviceId;
  final VoidCallback onReturnToDevice;

  const RegistersScreen({
    super.key,
    required this.controller,
    required this.returnDeviceId,
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

  DeviceInfo? get _selectedDevice => widget.controller.selectedDevice;

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

  String get _currentListSignature =>
      '${widget.controller.selectedDeviceId}:'
      '${widget.controller.lists.map((list) => list.id).join(',')}:'
      '${widget.controller.activeList?.id}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lists = _buildListsFromDevice();
    _listSignature = _currentListSignature;
    widget.controller.addListener(_onChanged);
    widget.controller.ensureSelectedList();
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
      widget.controller.selectList(_lists[selected].data.id);
    }
  }

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
                  addrMode: active.addrMode,
                  onAddrModeChanged: (v) =>
                      _updateActiveList(active..addrMode = v),
                  autoRefresh: active.autoRefresh,
                  onAutoRefreshChanged: (v) =>
                      _updateActiveList(active..autoRefresh = v),
                  autoRefreshIntervalMs: active.refreshIntervalMs,
                  refreshIntervalCtrl: active.refreshIntervalCtrl,
                  onRefreshIntervalCommitted: active.commitRefreshInterval,
                  startAddrCtrl: active.startAddrCtrl,
                  countCtrl: active.countCtrl,
                  registerList: active.data,
                  runtimeValues: widget.controller.runtimeValues,
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
                  autoRefresh: active.coilAutoRefresh,
                  onAutoRefreshChanged: (v) =>
                      _updateActiveList(active..coilAutoRefresh = v),
                  startAddrCtrl: active.coilStartAddrCtrl,
                  countCtrl: active.coilCountCtrl,
                  referenceStatuses: widget.controller.referenceStatuses,
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
  final int autoRefreshIntervalMs;
  final TextEditingController refreshIntervalCtrl;
  final VoidCallback onRefreshIntervalCommitted;
  final TextEditingController startAddrCtrl;
  final TextEditingController countCtrl;
  final RegisterList registerList;
  final Map<int, (String, String?, DateTime?)> runtimeValues;
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
    required this.addrMode,
    required this.onAddrModeChanged,
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
    required this.autoRefreshIntervalMs,
    required this.refreshIntervalCtrl,
    required this.onRefreshIntervalCommitted,
    required this.startAddrCtrl,
    required this.countCtrl,
    required this.registerList,
    required this.runtimeValues,
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
  String? _lastUpdateTime;
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
        old.autoRefreshIntervalMs != widget.autoRefreshIntervalMs ||
        old.canRead != widget.canRead ||
        old.regType != widget.regType) {
      _syncAutoRefresh(
        readImmediately:
            widget.autoRefresh &&
            (!old.autoRefresh || !old.canRead && widget.canRead),
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
    if (!widget.autoRefresh) return;

    _autoRefreshTimer = Timer.periodic(
      Duration(milliseconds: widget.autoRefreshIntervalMs),
      (_) {
        _read(showErrors: false, showProgress: false);
      },
    );
    if (readImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.autoRefresh) {
          _read(showErrors: false, showProgress: false);
        }
      });
    }
  }

  Future<void> _read({bool showErrors = true, bool showProgress = true}) async {
    if (_reading || !widget.canRead || !_supportsRegisterRead) return;

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
      final now = DateTime.now();
      setState(() {
        _lastUpdateTime =
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}:'
            '${now.second.toString().padLeft(2, '0')}';
      });
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
                l10n.registersLastUpdate(_lastUpdateTime ?? '--:--:--'),
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
  final bool autoRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;
  final TextEditingController startAddrCtrl;
  final TextEditingController countCtrl;
  final List<StatusEntry> Function(int startAddress, int count)
  referenceStatuses;

  const _CoilsTab({
    required this.coilType,
    required this.onCoilTypeChanged,
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
    required this.startAddrCtrl,
    required this.countCtrl,
    required this.referenceStatuses,
  });

  @override
  State<_CoilsTab> createState() => _CoilsTabState();
}

class _CoilsTabState extends State<_CoilsTab> {
  late List<StatusEntry> _items;

  bool get _canWrite => widget.coilType == '0xxxx';

  @override
  void initState() {
    super.initState();
    final start = int.tryParse(widget.startAddrCtrl.text) ?? 0;
    final count = int.tryParse(widget.countCtrl.text) ?? 20;
    _items = List.of(widget.referenceStatuses(start, count));
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
            itemBuilder: (context, i) => _StatusRow(
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

class _StatusRow extends StatelessWidget {
  final StatusEntry entry;
  final int displayAddress;
  final bool canWrite;
  final ValueChanged<bool>? onChanged;

  const _StatusRow({
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
              DropdownMenuItem(value: '1xxxx', child: Text('Discrete (1xxxx)')),
              DropdownMenuItem(value: '0xxxx', child: Text('Coils (0xxxx)')),
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
                          style: tt.bodyMedium!.copyWith(
                            color: appColors.typeColor,
                          ),
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
