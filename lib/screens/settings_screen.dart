import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _s = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
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
                icon: Icons.tag,
                label: l10n.settingsDefaultUnitId,
                value: '${_s.defaultUnitId}',
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
              _toggleTile(
                icon: Icons.edit_outlined,
                label: l10n.settingsConfirmBeforeWrite,
                value: _s.confirmBeforeWrite,
                onChanged: (v) => setState(() => _s.confirmBeforeWrite = v),
              ),
              _divider(),
              _toggleTile(
                icon: Icons.show_chart,
                label: l10n.settingsShowLastValues,
                value: _s.showLastValues,
                onChanged: (v) => setState(() => _s.showLastValues = v),
              ),
            ],
          ),
          _section(
            label: l10n.settingsSectionLog,
            children: [
              _navTile(
                icon: Icons.description_outlined,
                label: l10n.settingsLogLevel,
                value: _s.logLevel,
              ),
              _divider(),
              _toggleTile(
                icon: Icons.save_outlined,
                label: l10n.settingsSaveLogToFile,
                value: _s.saveLogToFile,
                onChanged: (v) => setState(() => _s.saveLogToFile = v),
              ),
              _divider(),
              _toggleTile(
                icon: Icons.delete_outline,
                label: l10n.settingsClearLogOnDisconnect,
                value: _s.clearLogOnDisconnect,
                onChanged: (v) => setState(() => _s.clearLogOnDisconnect = v),
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
                value: _s.theme,
              ),
              _divider(),
              _navTile(
                icon: Icons.language,
                label: l10n.settingsLanguage,
                value: _s.language,
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
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => AppSettings.instance.resetToDefaults());
            },
            child: Text(l10n.settingsResetDefaults),
          ),
        ],
      ),
    );
  }
}
