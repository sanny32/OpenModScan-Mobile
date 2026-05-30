import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';
import '../../models/device_info.dart';
import '../../models/modbus_scan.dart';
import '../../services/backup_service.dart';
import 'settings_controller.dart';
import 'about_screen.dart';
import 'widgets/setting_value_sheets.dart';

enum _SettingsSection {
  connection,
  networkScanner,
  readWrite,
  log,
  appearance,
  other,
}

class SettingsScreen extends StatefulWidget {
  final SettingsController controller;
  final _SettingsSection? _section;

  const SettingsScreen({super.key, required this.controller}) : _section = null;

  const SettingsScreen._section({
    required this.controller,
    required this._section,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings get _s => widget.controller.settings;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = widget._section;
    return section == null ? _buildHome() : _buildSection(section);
  }

  Widget _buildHome() {
    final l10n = context.l10n;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(l10n.settingsTitle, style: tt.headlineMedium),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final section in _SettingsSection.values) ...[
                    _sectionTile(section),
                    if (section != _SettingsSection.values.last) _divider(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(_SettingsSection section) {
    final l10n = context.l10n;
    final title = _sectionTitle(l10n, section);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: _sectionChildren(l10n, section)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTile(_SettingsSection section) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(_sectionIcon(section), color: cs.primary),
      title: Text(_sectionTitle(l10n, section)),
      subtitle: Text(_sectionSummary(l10n, section)),
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsScreen._section(
            controller: widget.controller,
            section: section,
          ),
        ),
      ),
    );
  }

  IconData _sectionIcon(_SettingsSection section) {
    return switch (section) {
      _SettingsSection.connection => Icons.wifi,
      _SettingsSection.networkScanner => Icons.sensors,
      _SettingsSection.readWrite => Icons.tune,
      _SettingsSection.log => Icons.receipt_long_outlined,
      _SettingsSection.appearance => Icons.palette_outlined,
      _SettingsSection.other => Icons.more_horiz,
    };
  }

  String _sectionTitle(AppLocalizations l10n, _SettingsSection section) {
    return switch (section) {
      _SettingsSection.connection => l10n.settingsSectionConnection,
      _SettingsSection.networkScanner => l10n.settingsSectionNetworkScan,
      _SettingsSection.readWrite => l10n.settingsSectionReadWrite,
      _SettingsSection.log => l10n.settingsSectionLog,
      _SettingsSection.appearance => l10n.settingsSectionAppearance,
      _SettingsSection.other => l10n.settingsSectionOther,
    };
  }

  String _sectionSummary(AppLocalizations l10n, _SettingsSection section) {
    return switch (section) {
      _SettingsSection.connection =>
        '${_protocolLabel(l10n, _s.connectionType)} · ${l10n.settingsValueMs(_s.timeout)}',
      _SettingsSection.networkScanner =>
        '${_protocolLabel(l10n, _s.scanProtocol)} · /${_s.scanSubnetPrefix} · ${l10n.settingsSummaryPort(_formatRange(_s.scanPortStart, _s.scanPortEnd))}',
      _SettingsSection.readWrite =>
        '${l10n.settingsSummaryAddressBase(_s.addressBase)} · ${_s.registerOrder} · ${_s.byteOrder}',
      _SettingsSection.log => l10n.settingsSummaryEntries(_s.maxLogEntries),
      _SettingsSection.appearance =>
        '${_themeOptionLabel(l10n, _s.theme)} · ${_languageOptionLabel(l10n, _s.language)}',
      _SettingsSection.other => l10n.settingsSummaryResetAndAbout,
    };
  }

  List<Widget> _sectionChildren(
    AppLocalizations l10n,
    _SettingsSection section,
  ) {
    return switch (section) {
      _SettingsSection.connection => [
        _navTile(
          icon: Icons.wifi,
          label: l10n.settingsDefaultConnectionType,
          value: _protocolLabel(l10n, _s.connectionType),
          onTap: () => showSettingChoiceSheet(
            context,
            title: l10n.settingsDefaultConnectionType,
            options: ProtocolType.values.map((value) => value.name).toList(),
            selected: _s.connectionType.name,
            optionLabel: (value) => _protocolLabel(
              l10n,
              ProtocolType.values.firstWhere(
                (protocol) => protocol.name == value,
              ),
            ),
            onSelected: (value) => widget.controller.setConnectionType(
              ProtocolType.values.firstWhere(
                (protocol) => protocol.name == value,
              ),
            ),
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.timer_outlined,
          label: l10n.settingsDefaultTimeout,
          value: l10n.settingsValueMs(_s.timeout),
          onTap: () => showSettingNumberSheet(
            context,
            title: l10n.settingsDefaultTimeout,
            initialValue: _s.timeout,
            min: 100,
            max: 60000,
            onSubmitted: widget.controller.setTimeout,
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.sync,
          label: l10n.settingsReconnectDelay,
          value: l10n.settingsValueMs(_s.reconnectDelay),
          onTap: () => showSettingNumberSheet(
            context,
            title: l10n.settingsReconnectDelay,
            initialValue: _s.reconnectDelay,
            min: 500,
            max: 60000,
            onSubmitted: widget.controller.setReconnectDelay,
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.warning_amber_outlined,
          label: 'Read failure attempts',
          value: '${_s.readFailureAttempts}',
          onTap: () => showSettingChoiceSheet(
            context,
            title: 'Read failure attempts',
            options: AppSettings.readFailureAttemptOptions
                .map((value) => '$value')
                .toList(),
            selected: '${_s.readFailureAttempts}',
            onSelected: (value) =>
                widget.controller.setReadFailureAttempts(int.parse(value)),
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.tag,
          label: l10n.settingsDefaultUnitId,
          value: '${_s.defaultUnitId}',
          onTap: () => showSettingNumberSheet(
            context,
            title: l10n.settingsDefaultUnitId,
            initialValue: _s.defaultUnitId,
            min: 0,
            max: 255,
            onSubmitted: widget.controller.setDefaultUnitId,
          ),
        ),
      ],
      _SettingsSection.networkScanner => [
        _navTile(
          icon: Icons.hub_outlined,
          label: l10n.settingsScanProtocol,
          value: _protocolLabel(l10n, _s.scanProtocol),
          onTap: () => showSettingChoiceSheet(
            context,
            title: l10n.settingsScanProtocol,
            options: ProtocolType.values.map((value) => value.name).toList(),
            selected: _s.scanProtocol.name,
            optionLabel: (value) => _protocolLabel(
              l10n,
              ProtocolType.values.firstWhere(
                (protocol) => protocol.name == value,
              ),
            ),
            onSelected: (value) => widget.controller.setScanProtocol(
              ProtocolType.values.firstWhere(
                (protocol) => protocol.name == value,
              ),
            ),
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.account_tree_outlined,
          label: l10n.settingsScanSubnetPrefix,
          value: '/${_s.scanSubnetPrefix}',
          onTap: () => showSettingNumberSheet(
            context,
            title: l10n.settingsScanSubnetPrefix,
            initialValue: _s.scanSubnetPrefix,
            min: 16,
            max: 30,
            onSubmitted: widget.controller.setScanSubnetPrefix,
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.settings_ethernet,
          label: l10n.settingsScanPortRange,
          value: _formatRange(_s.scanPortStart, _s.scanPortEnd),
          onTap: () => showSettingRangeSheet(
            context,
            title: l10n.settingsScanPortRange,
            startValue: _s.scanPortStart,
            endValue: _s.scanPortEnd,
            min: 1,
            max: 65535,
            onSubmitted: widget.controller.setScanPortRange,
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.tag,
          label: l10n.settingsScanUnitIdRange,
          value: _formatRange(_s.scanUnitIdStart, _s.scanUnitIdEnd),
          onTap: () => showSettingRangeSheet(
            context,
            title: l10n.settingsScanUnitIdRange,
            startValue: _s.scanUnitIdStart,
            endValue: _s.scanUnitIdEnd,
            min: 0,
            max: 255,
            onSubmitted: widget.controller.setScanUnitIdRange,
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.call_received,
          label: l10n.settingsScanRequestType,
          value: _scanRequestTypeLabel(l10n, _s.scanRequestType),
          onTap: () => showSettingChoiceSheet(
            context,
            title: l10n.settingsScanRequestType,
            options: ModbusScanRequestType.values
                .map((value) => value.name)
                .toList(),
            selected: _s.scanRequestType.name,
            optionLabel: (value) => _scanRequestTypeLabel(
              l10n,
              ModbusScanRequestType.values.firstWhere(
                (type) => type.name == value,
              ),
            ),
            onSelected: (value) => widget.controller.setScanRequestType(
              ModbusScanRequestType.values.firstWhere(
                (type) => type.name == value,
              ),
            ),
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.pin_outlined,
          label: l10n.settingsScanRequestAddress,
          value: '${_s.scanRequestAddress}',
          onTap: () => showSettingNumberSheet(
            context,
            title: l10n.settingsScanRequestAddress,
            initialValue: _s.scanRequestAddress,
            min: 0,
            max: 65535,
            onSubmitted: widget.controller.setScanRequestAddress,
          ),
        ),
        _divider(),
        _toggleTile(
          icon: Icons.cleaning_services_outlined,
          label: l10n.settingsScanClearOnStart,
          value: _s.scanClearOnStart,
          onChanged: widget.controller.setScanClearOnStart,
        ),
      ],
      _SettingsSection.readWrite => [
        _navTile(
          icon: Icons.dashboard_outlined,
          label: l10n.settingsDefaultReadQty,
          value: '${_s.defaultReadQty}',
          onTap: () => showSettingNumberSheet(
            context,
            title: l10n.settingsDefaultReadQty,
            initialValue: _s.defaultReadQty,
            min: 1,
            max: 125,
            onSubmitted: widget.controller.setDefaultReadQty,
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.pin_outlined,
          label: 'AddressBase',
          value: _s.addressBase,
          onTap: () => showSettingChoiceSheet(
            context,
            title: 'AddressBase',
            options: AppSettings.addressBases,
            selected: _s.addressBase,
            onSelected: widget.controller.setAddressBase,
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.swap_vert_rounded,
          label: l10n.labelRegisterOrder,
          value: _s.registerOrder,
          onTap: () => showSettingChoiceSheet(
            context,
            title: l10n.labelRegisterOrder,
            options: AppSettings.registerOrders,
            selected: _s.registerOrder,
            onSelected: widget.controller.setRegisterOrder,
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.swap_horiz_rounded,
          label: l10n.labelByteOrder,
          value: _s.byteOrder,
          onTap: () => showSettingChoiceSheet(
            context,
            title: l10n.labelByteOrder,
            options: AppSettings.byteOrders,
            selected: _s.byteOrder,
            onSelected: widget.controller.setByteOrder,
          ),
        ),
        _divider(),
        _toggleTile(
          icon: Icons.edit_note_outlined,
          label: l10n.settingsWriteEnabled,
          value: _s.writeEnabled,
          onChanged: widget.controller.setWriteEnabled,
        ),
        _divider(),
        _toggleTile(
          icon: Icons.edit_outlined,
          label: l10n.settingsConfirmBeforeCoilWrite,
          value: _s.confirmBeforeWrite,
          onChanged: widget.controller.setConfirmBeforeWrite,
        ),
        _divider(),
        _toggleTile(
          icon: Icons.show_chart,
          label: l10n.settingsShowLastValues,
          value: _s.showLastValues,
          onChanged: widget.controller.setShowLastValues,
        ),
        _divider(),
        _toggleTile(
          icon: Icons.label_outline,
          label: l10n.settingsShowTypeBadges,
          value: _s.showTypeBadges,
          onChanged: widget.controller.setShowTypeBadges,
        ),
      ],
      _SettingsSection.log => [
        _toggleTile(
          icon: Icons.save_outlined,
          label: l10n.settingsSaveLogToFile,
          value: _s.saveLogToFile,
          onChanged: widget.controller.setSaveLogToFile,
        ),
        _divider(),
        _toggleTile(
          icon: Icons.delete_outline,
          label: l10n.settingsClearLogOnDisconnect,
          value: _s.clearLogOnDisconnect,
          onChanged: widget.controller.setClearLogOnDisconnect,
        ),
        _divider(),
        _navTile(
          icon: Icons.zoom_out_map,
          label: l10n.settingsMaxLogEntries,
          value: '${_s.maxLogEntries}',
          onTap: () => showSettingNumberSheet(
            context,
            title: l10n.settingsMaxLogEntries,
            initialValue: _s.maxLogEntries,
            min: 50,
            max: 100000,
            onSubmitted: widget.controller.setMaxLogEntries,
          ),
        ),
      ],
      _SettingsSection.appearance => [
        _navTile(
          icon: Icons.light_mode_outlined,
          label: l10n.settingsTheme,
          value: _themeOptionLabel(l10n, _s.theme),
          onTap: () => showSettingChoiceSheet(
            context,
            title: l10n.settingsTheme,
            options: AppSettings.themeOptions,
            selected: _s.theme,
            optionLabel: (value) => _themeOptionLabel(l10n, value),
            onSelected: (value) async {
              await widget.controller.setTheme(value);
            },
          ),
        ),
        _divider(),
        _navTile(
          icon: Icons.language,
          label: l10n.settingsLanguage,
          value: _languageOptionLabel(l10n, _s.language),
          onTap: () => showSettingChoiceSheet(
            context,
            title: l10n.settingsLanguage,
            options: AppSettings.languageOptions,
            selected: _s.language,
            optionLabel: (value) => _languageOptionLabel(l10n, value),
            onSelected: (value) async {
              await widget.controller.setLanguage(value);
            },
          ),
        ),
      ],
      _SettingsSection.other => [
        _navTile(
          icon: Icons.backup_outlined,
          label: l10n.settingsBackupRestore,
          value: '',
          onTap: _showBackupRestoreSheet,
        ),
        _divider(),
        _navTile(
          icon: Icons.settings_backup_restore,
          label: l10n.settingsResetDefaults,
          value: '',
          onTap: _confirmReset,
        ),
        _divider(),
        _navTile(
          icon: Icons.info_outline,
          label: l10n.aboutTitle,
          value: '',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ),
        ),
      ],
    };
  }

  Widget _divider() => Divider(
    height: 1,
    indent: 56,
    endIndent: 0,
    color: Theme.of(context).dividerTheme.color,
  );

  Widget _navTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(value, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
      onTap: onTap ?? () {},
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }

  String _themeOptionLabel(AppLocalizations l10n, String option) {
    switch (option) {
      case 'Light':
        return l10n.settingsThemeLight;
      case 'Dark':
        return l10n.settingsThemeDark;
      case 'System':
      default:
        return l10n.settingsThemeSystem;
    }
  }

  String _languageOptionLabel(AppLocalizations l10n, String option) {
    switch (option) {
      case 'English':
        return l10n.settingsLanguageEnglish;
      case 'Russian':
        return l10n.settingsLanguageRussian;
      case 'System':
      default:
        return l10n.settingsLanguageSystem;
    }
  }

  String _protocolLabel(AppLocalizations l10n, ProtocolType protocol) {
    return switch (protocol) {
      ProtocolType.modbusTcp => l10n.connectTypeTcp,
      ProtocolType.modbusRtuIp => l10n.connectTypeRtu,
    };
  }

  String _formatRange(int start, int end) {
    return start == end ? '$start' : '$start-$end';
  }

  String _scanRequestTypeLabel(
    AppLocalizations l10n,
    ModbusScanRequestType type,
  ) {
    return switch (type) {
      ModbusScanRequestType.coils => l10n.settingsScanRequestCoils,
      ModbusScanRequestType.discreteInputs =>
        l10n.settingsScanRequestDiscreteInputs,
      ModbusScanRequestType.holdingRegisters =>
        l10n.settingsScanRequestHoldingRegisters,
      ModbusScanRequestType.inputRegisters =>
        l10n.settingsScanRequestInputRegisters,
    };
  }

  void _confirmReset() {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsResetDefaults),
        content: Text(l10n.settingsResetConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.controller.resetToDefaults();
            },
            child: Text(l10n.settingsResetDefaults),
          ),
        ],
      ),
    );
  }

  void _showBackupRestoreSheet() {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l10n.settingsBackupExport),
              onTap: () {
                Navigator.pop(ctx);
                _exportBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.settingsBackupImport),
              onTap: () {
                Navigator.pop(ctx);
                _confirmImportBackup();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    final l10n = context.l10n;
    final result = await widget.controller.exportBackup(
      dialogTitle: l10n.settingsBackupExport,
    );
    _showBackupResult(
      result,
      successMessage: l10n.settingsBackupExportSuccess,
    );
  }

  void _confirmImportBackup() {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsBackupImport),
        content: Text(l10n.settingsBackupImportConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _importBackup();
            },
            child: Text(l10n.settingsBackupImport),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackup() async {
    final l10n = context.l10n;
    final result = await widget.controller.importBackup(
      dialogTitle: l10n.settingsBackupImport,
    );
    _showBackupResult(
      result,
      successMessage: l10n.settingsBackupImportSuccess,
    );
  }

  void _showBackupResult(
    BackupResult result, {
    required String successMessage,
  }) {
    if (!mounted || result == BackupResult.cancelled) return;
    final l10n = context.l10n;
    final message = result == BackupResult.success
        ? successMessage
        : l10n.settingsBackupFailure;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
