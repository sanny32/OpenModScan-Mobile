import 'package:flutter/material.dart';
import 'l10n/l10n.dart';
import 'screens/devices_screen.dart';
import 'screens/log_screen.dart';
import 'screens/registers_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const OModScanApp());
}

class OModScanApp extends StatelessWidget {
  const OModScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenModScan Mobile',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [DevicesScreen(), RegistersScreen(), LogScreen()];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.devices),
            label: l10n.navDevices,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.grid_on),
            label: l10n.navRegisters,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.list_alt),
            label: l10n.navLog,
          ),
        ],
      ),
    );
  }
}
