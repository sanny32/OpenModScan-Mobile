import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';
import '../../models/device_info.dart';
import '../../models/modbus_scan.dart';
import 'settings_controller.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsController controller;

  const SettingsScreen({super.key, required this.controller});

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
            _section(
              label: l10n.settingsSectionConnection,
              children: [
                _navTile(
                  icon: Icons.wifi,
                  label: l10n.settingsDefaultConnectionType,
                  value: _s.connectionType,
                ),
                _divider(),
                _navTile(
                  icon: Icons.timer_outlined,
                  label: l10n.settingsDefaultTimeout,
                  value: l10n.settingsValueMs(_s.timeout),
                ),
                _divider(),
                _navTile(
                  icon: Icons.sync,
                  label: l10n.settingsReconnectDelay,
                  value: l10n.settingsValueMs(_s.reconnectDelay),
                ),
                _divider(),
                _navTile(
                  icon: Icons.warning_amber_outlined,
                  label: 'Read failure attempts',
                  value: '${_s.readFailureAttempts}',
                  onTap: () => _showChoiceSheet(
                    title: 'Read failure attempts',
                    options: AppSettings.readFailureAttemptOptions
                        .map((value) => '$value')
                        .toList(),
                    selected: '${_s.readFailureAttempts}',
                    onSelected: (value) => widget.controller
                        .setReadFailureAttempts(int.parse(value)),
                  ),
                ),
                _divider(),
                _navTile(
                  icon: Icons.tag,
                  label: l10n.settingsDefaultUnitId,
                  value: '${_s.defaultUnitId}',
                ),
              ],
            ),
            _section(
              label: l10n.settingsSectionNetworkScan,
              children: [
                _navTile(
                  icon: Icons.hub_outlined,
                  label: l10n.settingsScanProtocol,
                  value: _protocolLabel(l10n, _s.scanProtocol),
                  onTap: () => _showChoiceSheet(
                    title: l10n.settingsScanProtocol,
                    options: ProtocolType.values
                        .map((value) => value.name)
                        .toList(),
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
                  onTap: () => _showNumberSheet(
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
                  onTap: () => _showRangeSheet(
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
                  onTap: () => _showRangeSheet(
                    title: l10n.settingsScanUnitIdRange,
                    startValue: _s.scanUnitIdStart,
                    endValue: _s.scanUnitIdEnd,
                    min: 1,
                    max: 247,
                    onSubmitted: widget.controller.setScanUnitIdRange,
                  ),
                ),
                _divider(),
                _navTile(
                  icon: Icons.call_received,
                  label: l10n.settingsScanRequestType,
                  value: _scanRequestTypeLabel(l10n, _s.scanRequestType),
                  onTap: () => _showChoiceSheet(
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
                  onTap: () => _showNumberSheet(
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
            ),
            _section(
              label: l10n.settingsSectionReadWrite,
              children: [
                _navTile(
                  icon: Icons.dashboard_outlined,
                  label: l10n.settingsDefaultReadQty,
                  value: '${_s.defaultReadQty}',
                ),
                _divider(),
                _navTile(
                  icon: Icons.pin_outlined,
                  label: 'AddressBase',
                  value: _s.addressBase,
                  onTap: () => _showChoiceSheet(
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
                  onTap: () => _showChoiceSheet(
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
                  onTap: () => _showChoiceSheet(
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
            ),
            _section(
              label: l10n.settingsSectionLog,
              children: [
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
                ),
              ],
            ),
            _section(
              label: l10n.settingsSectionAppearance,
              children: [
                _navTile(
                  icon: Icons.light_mode_outlined,
                  label: l10n.settingsTheme,
                  value: _themeOptionLabel(l10n, _s.theme),
                  onTap: () => _showChoiceSheet(
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
                  onTap: () => _showChoiceSheet(
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
            ),
            _section(
              label: l10n.settingsSectionOther,
              children: [
                _navTile(
                  icon: Icons.backup_outlined,
                  label: l10n.settingsBackupRestore,
                  value: '',
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
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _section({required String label, required List<Widget> children}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
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

  Future<void> _showChoiceSheet({
    required String title,
    required List<String> options,
    required String selected,
    String Function(String)? optionLabel,
    required FutureOr<void> Function(String) onSelected,
  }) async {
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                title: Text(optionLabel?.call(option) ?? option),
                trailing: option == selected
                    ? Icon(Icons.check, color: cs.primary)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await onSelected(option);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNumberSheet({
    required String title,
    required int initialValue,
    required int min,
    required int max,
    required FutureOr<void> Function(int) onSubmitted,
  }) async {
    await _showTextSheet(
      title: title,
      initialValue: '$initialValue',
      keyboardType: TextInputType.number,
      onSubmitted: (value) async {
        final parsed = int.tryParse(value) ?? initialValue;
        await onSubmitted(parsed.clamp(min, max).toInt());
      },
    );
  }

  Future<void> _showTextSheet({
    required String title,
    required String initialValue,
    required TextInputType keyboardType,
    required FutureOr<void> Function(String) onSubmitted,
  }) async {
    final controller = TextEditingController(text: initialValue);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                autofocus: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await onSubmitted(controller.text.trim());
                },
                child: Text(context.l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _showRangeSheet({
    required String title,
    required int startValue,
    required int endValue,
    required int min,
    required int max,
    required FutureOr<void> Function(int, int) onSubmitted,
  }) async {
    final startController = TextEditingController(text: '$startValue');
    final endController = TextEditingController(text: '$endValue');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.settingsRangeStart,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: endController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.settingsRangeEnd,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final start =
                      int.tryParse(startController.text) ?? startValue;
                  final end = int.tryParse(endController.text) ?? endValue;
                  Navigator.pop(ctx);
                  await onSubmitted(
                    start.clamp(min, max).toInt(),
                    end.clamp(min, max).toInt(),
                  );
                },
                child: Text(context.l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
    startController.dispose();
    endController.dispose();
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
}
