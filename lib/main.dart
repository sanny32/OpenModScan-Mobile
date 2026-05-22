import 'package:flutter/material.dart';
import 'features/devices/devices_controller.dart';
import 'features/devices/device_screen.dart';
import 'features/devices/devices_screen.dart';
import 'features/registers/registers_controller.dart';
import 'features/registers/registers_screen.dart';
import 'features/settings/settings_controller.dart';
import 'features/settings/settings_screen.dart';
import 'features/traffic/traffic_controller.dart';
import 'features/traffic/traffic_screen.dart';
import 'l10n/l10n.dart';
import 'models/app_settings.dart';
import 'navigation/navigation_targets.dart';
import 'runtime/fakes/demo_fixtures.dart';
import 'runtime/fakes/demo_runtime.dart';
import 'services/connection_manager.dart';
import 'services/device_repository.dart';
import 'services/device_scanner.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  await DeviceRepository.instance.initialize(seedDevices: demoDevices);
  runApp(const OModScanApp());
}

class OModScanApp extends StatelessWidget {
  const OModScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.instance.themeModeNotifier,
      builder: (context, themeMode, child) => ValueListenableBuilder<Locale?>(
        valueListenable: AppSettings.instance.localeNotifier,
        builder: (context, locale, child) => MaterialApp(
          title: 'OpenModScan Mobile',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppShell(),
          debugShowCheckedModeBanner: false,
        ),
      ),
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
  static const _deviceDetailRoute = '/device';

  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  late final DevicesController _devicesController;
  late final RegistersController _registersController;
  late final TrafficController _trafficController;
  late final SettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    final registerRuntime = DemoRegisterRuntime();
    final trafficLogs = DemoTrafficLogSource();

    _devicesController = DevicesController(
      DeviceRepository.instance,
      ConnectionManager.instance,
      DeviceScanner.instance,
    );
    _registersController = RegistersController(
      DeviceRepository.instance,
      ConnectionManager.instance,
      registerRuntime,
    );
    _trafficController = TrafficController(
      DeviceRepository.instance,
      ConnectionManager.instance,
      trafficLogs,
    );
    _settingsController = SettingsController(AppSettings.instance);
  }

  @override
  void dispose() {
    _devicesController.dispose();
    _registersController.dispose();
    _trafficController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  Future<void> _openRegisters(RegistersRouteArgs target) async {
    await _registersController.selectTarget(target);
    if (mounted) setState(() => _index = 1);
  }

  void _openTraffic(TrafficRouteArgs target) {
    _trafficController.selectTarget(target);
    setState(() => _index = 2);
  }

  void _openDevice(String deviceId) {
    _navigatorKeys[0].currentState?.pushNamed(
      _deviceDetailRoute,
      arguments: DeviceRouteArgs(deviceId),
    );
  }

  Route<dynamic> _buildRoute(int tab, RouteSettings settings) {
    if (tab == 0 && settings.name == _deviceDetailRoute) {
      final args = settings.arguments! as DeviceRouteArgs;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => DeviceScreen(
          deviceId: args.deviceId,
          controller: _devicesController,
          onOpenRegisters: _openRegisters,
          onOpenTraffic: _openTraffic,
        ),
      );
    }

    final root = switch (tab) {
      0 => DevicesScreen(
        controller: _devicesController,
        onOpenDevice: _openDevice,
      ),
      1 => RegistersScreen(controller: _registersController),
      2 => TrafficScreen(controller: _trafficController),
      _ => SettingsScreen(controller: _settingsController),
    };

    return MaterialPageRoute<void>(settings: settings, builder: (_) => root);
  }

  Widget _tabNavigator(int tab) => Navigator(
    key: _navigatorKeys[tab],
    onGenerateRoute: (settings) => _buildRoute(tab, settings),
  );

  Future<void> _handlePop() async {
    final popped =
        await _navigatorKeys[_index].currentState?.maybePop() ?? false;
    if (!popped && _index != 0 && mounted) {
      setState(() => _index = 0);
    }
  }

  static const _tabCount = 4;

  List<Widget> get _tabNavigators => [
    for (var tab = 0; tab < _tabCount; tab++) _tabNavigator(tab),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _tabNavigators),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (index) => setState(() => _index = index),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.devices_outlined),
              activeIcon: const Icon(Icons.devices),
              label: l10n.navDevices,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.grid_on_outlined),
              activeIcon: const Icon(Icons.grid_on),
              label: l10n.navRegisters,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.list_alt_outlined),
              activeIcon: const Icon(Icons.list_alt),
              label: l10n.navLog,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: l10n.settingsTitle,
            ),
          ],
        ),
      ),
    );
  }
}
