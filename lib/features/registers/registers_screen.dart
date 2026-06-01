import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/device_info.dart';
import '../../models/app_settings.dart';
import '../../models/register_address_type.dart';
import '../../models/register_entry.dart';
import '../../models/register_list.dart';
import '../../models/status_entry.dart';
import '../../services/modbus_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/connection_info_bar.dart';
import '../../widgets/connection_status_chip.dart';
import '../../widgets/device_select_sheet.dart';
import '../../widgets/error_feedback.dart';
import '../../utils/modbus_format.dart';
import '../../widgets/type_badge.dart';
import 'register_list_dialogs.dart';
import 'register_runtime_value.dart';
import 'registers_controller.dart';
import 'widgets/register_list_dropdown.dart';
import 'widgets/register_row.dart';
import 'widgets/registers_range_controls.dart';
import 'widgets/registers_tab_toolbar.dart';
import 'widgets/status_row.dart';

part 'registers_list_config.dart';
part 'registers_tab_helpers.dart';
part 'registers_tab.dart';
part 'status_tab.dart';

enum _MenuAction { selectDevice, removeRegs, setAllTypes }

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
  var _activeTab = 0;
  var _deviceValueState = RegisterValueState.received;
  String? _deviceValueStatusLabel;
  var _registerValueState = RegisterValueState.received;
  String? _registerValueStatusLabel;
  var _statusValueState = RegisterValueState.received;
  String? _statusValueStatusLabel;
  var _connectionBusy = false;

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
        '${AppSettings.instance.addressBaseStart}:'
        '$listsSignature:'
        '${widget.controller.activeList?.id}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lists = _buildListsFromDevice();
    _activeList = widget.controller.activeListIndex.clamp(0, _lists.length - 1);
    _listSignature = _currentListSignature;
    _tabController.addListener(_onTabChanged);
    _tabController.animation?.addListener(_onTabAnimationChanged);
    widget.controller.addListener(_onChanged);
    widget.controller.ensureSelectedList();
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

  void _onChanged() {
    if (!mounted) return;
    final signature = _currentListSignature;
    if (signature != _listSignature) {
      _deviceValueState = RegisterValueState.received;
      _deviceValueStatusLabel = null;
      _registerValueState = RegisterValueState.received;
      _registerValueStatusLabel = null;
      _statusValueState = RegisterValueState.received;
      _statusValueStatusLabel = null;
      for (final list in _lists) {
        list.dispose();
      }
      _lists = _buildListsFromDevice();
      _activeList = widget.controller.activeListIndex.clamp(
        0,
        _lists.length - 1,
      );
      _listSignature = signature;
      final activeType = RegisterAddressType.fromCode(
        _lists[_activeList].data.regType,
      );
      if (activeType.isBit) {
        _tabController.animateTo(1);
      }
    }
    if (_selectedDevice != null &&
        !widget.controller.isConnected(_selectedDevice!)) {
      _deviceValueState = RegisterValueState.unavailable;
      _deviceValueStatusLabel = null;
      _registerValueState = RegisterValueState.received;
      _registerValueStatusLabel = null;
      _statusValueState = RegisterValueState.received;
      _statusValueStatusLabel = null;
    } else if (_deviceValueState == RegisterValueState.unavailable) {
      _deviceValueState = RegisterValueState.received;
      _deviceValueStatusLabel = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
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

  Future<void> _toggleSelectedConnection() async {
    final device = _selectedDevice;
    if (device == null || _connectionBusy) return;

    setState(() => _connectionBusy = true);
    try {
      await widget.controller.toggleConnection(device);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _connectionBusy = false);
      }
    }
  }

  Future<void> _addList() async {
    final result = await showRegisterListDialog(
      context,
      defaultName: 'List ${_lists.length + 1}',
      existingNames: _lists.map((l) => l.name).toList(),
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
    final selected = await showDeviceSelectSheet(
      context,
      devices: widget.controller.devices,
      selectedId: widget.controller.selectedDeviceId,
      isConnected: widget.controller.isConnected,
    );

    if (selected != null && selected != widget.controller.selectedDeviceId) {
      await widget.controller.selectDevice(selected);
    }
  }

  Future<String?> _onValueWritten(int address, String value, String typeName) =>
      widget.controller.writeValue(address, value, typeName);

  Future<bool?> _onStatusValueWritten({
    required String statusType,
    required int address,
    required bool value,
  }) => widget.controller.writeStatusValue(
    statusType: statusType,
    address: address,
    value: value,
  );

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
    final selectedDeviceConnected =
        _selectedDevice != null &&
        widget.controller.isConnected(_selectedDevice!);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final effectiveRegisterValueState = _effectiveValueState(
      _registerValueState,
    );
    final effectiveStatusValueState = _effectiveValueState(_statusValueState);
    final activeValueState = _activeTab == 1
        ? effectiveStatusValueState
        : effectiveRegisterValueState;
    final activeValueStatusLabel = _activeTab == 1
        ? _effectiveValueStatusLabel(_statusValueStatusLabel)
        : _effectiveValueStatusLabel(_registerValueStatusLabel);
    final showValueException =
        selectedDeviceConnected &&
        activeValueState == RegisterValueState.exception;

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
              connected: selectedDeviceConnected,
              label: showValueException
                  ? activeValueStatusLabel ?? 'Modbus exception'
                  : null,
              color: showValueException ? appColors.exceptionValueColor : null,
            ),
          ],
        ),
        actions: [
          if (_selectedDevice != null)
            IconButton(
              icon: Icon(
                Icons.power_settings_new,
                color: selectedDeviceConnected
                    ? appColors.connectedColor
                    : cs.onSurfaceVariant,
              ),
              tooltip: selectedDeviceConnected ? l10n.disconnect : l10n.connect,
              onPressed: _connectionBusy ? null : _toggleSelectedConnection,
            ),
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
                  listSelector: _buildListSelector(),
                  autoRefresh: active.autoRefresh,

                  isActive: _activeTab == 0,
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
                  isConnected: selectedDeviceConnected,
                  canRead: selectedDeviceConnected,
                  valueState: effectiveRegisterValueState,
                  onValueStateChanged: _onRegisterValueStateChanged,
                  onRead: widget.controller.readRegisters,
                  onEntryChanged: _onEntryChanged,
                  onValueWritten: _onValueWritten,
                  valuesListenable: widget.controller,
                  liveValueAt: (address) =>
                      widget.controller.runtimeValues[address],
                ),
                _StatusTab(
                  statusType: active.coilType,
                  onStatusTypeChanged: (v) =>
                      _updateActiveList(active..coilType = v),
                  listSelector: _buildListSelector(),
                  autoRefresh: active.coilAutoRefresh,
                  isActive: _activeTab == 1,
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
                  canRead: selectedDeviceConnected,
                  valueState: effectiveStatusValueState,
                  onValueStateChanged: _onStatusValueStateChanged,
                  onRead: widget.controller.readStatuses,
                  onEntryChanged: (address, comment) => widget.controller
                      .updateStatusEntry(active.coilType, address, comment),
                  onValueWritten: _onStatusValueWritten,
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

  Widget _buildListSelector() {
    return RegisterListDropdown(
      names: _lists.map((l) => l.name).toList(),
      activeIndex: _activeList,
      onChanged: (i) {
        setState(() => _activeList = i);
        widget.controller.selectList(_lists[i].data.id);
      },
      onAdd: _addList,
    );
  }

  void _setActiveTab(int index) {
    if (_activeTab != index) {
      setState(() => _activeTab = index);
    }
  }

  RegisterValueState _effectiveValueState(RegisterValueState localState) =>
      _deviceValueState == RegisterValueState.received
      ? localState
      : _deviceValueState;

  String? _effectiveValueStatusLabel(String? localLabel) =>
      _deviceValueState == RegisterValueState.exception
      ? _deviceValueStatusLabel
      : localLabel;

  void _onRegisterValueStateChanged(
    RegisterValueState state,
    String? label, {
    required bool shared,
  }) {
    _setValueState(
      state: state,
      label: label,
      shared: shared,
      updateLocal: () {
        _registerValueState = state;
        _registerValueStatusLabel = label;
      },
    );
  }

  void _onStatusValueStateChanged(
    RegisterValueState state,
    String? label, {
    required bool shared,
  }) {
    _setValueState(
      state: state,
      label: label,
      shared: shared,
      updateLocal: () {
        _statusValueState = state;
        _statusValueStatusLabel = label;
      },
    );
  }

  void _setValueState({
    required RegisterValueState state,
    required String? label,
    required bool shared,
    required VoidCallback updateLocal,
  }) {
    setState(() {
      if (shared) {
        _deviceValueState = state;
        _deviceValueStatusLabel = label;
      } else {
        _deviceValueState = RegisterValueState.received;
        _deviceValueStatusLabel = null;
        updateLocal();
      }
    });
  }
}
