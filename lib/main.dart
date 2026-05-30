import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_flags.dart';
import 'features/devices/devices_controller.dart';
import 'features/registers/registers_controller.dart';
import 'features/settings/settings_controller.dart';
import 'features/traffic/traffic_controller.dart';
import 'l10n/l10n.dart';
import 'models/app_settings.dart';
import 'navigation/app_router.dart';
import 'runtime/fakes/demo_fixtures.dart';
import 'runtime/fakes/demo_runtime.dart';
import 'runtime/runtime_ports.dart';
import 'services/connection_manager.dart';
import 'services/device_repository.dart';
import 'services/device_scanner.dart';
import 'services/traffic_log.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  await DeviceRepository.instance.initialize(
    seedDevices: AppFlags.demoData ? demoDevices : const [],
  );
  if (!AppFlags.demoData) {
    TrafficLog.instance.install();
  }
  runApp(const OModScanApp());
}

class OModScanApp extends StatefulWidget {
  const OModScanApp({super.key});

  @override
  State<OModScanApp> createState() => _OModScanAppState();
}

class _OModScanAppState extends State<OModScanApp> {
  final _registersReturnDeviceId = ValueNotifier<String?>(null);

  late final DevicesController _devicesController;
  late final RegistersController _registersController;
  late final TrafficController _trafficController;
  late final SettingsController _settingsController;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final registerRuntime = DemoRegisterRuntime(enabled: AppFlags.demoData);
    final TrafficLogSource trafficLogs = AppFlags.demoData
        ? DemoTrafficLogSource(enabled: true)
        : TrafficLog.instance;

    _devicesController = DevicesController(
      DeviceRepository.instance,
      ConnectionManager.instance,
      DeviceScanner.instance,
      AppSettings.instance,
    );
    _registersController = RegistersController(
      DeviceRepository.instance,
      ConnectionManager.instance,
      registerRuntime,
      AppSettings.instance,
    );
    _trafficController = TrafficController(
      DeviceRepository.instance,
      ConnectionManager.instance,
      trafficLogs,
    );
    _settingsController = SettingsController(AppSettings.instance);

    _router = createAppRouter(
      devicesController: _devicesController,
      registersController: _registersController,
      trafficController: _trafficController,
      settingsController: _settingsController,
      registersReturnDeviceId: _registersReturnDeviceId,
    );
  }

  @override
  void dispose() {
    _registersReturnDeviceId.dispose();
    _devicesController.dispose();
    _registersController.dispose();
    _trafficController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.instance.themeModeNotifier,
      builder: (context, themeMode, child) => ValueListenableBuilder<Locale?>(
        valueListenable: AppSettings.instance.localeNotifier,
        builder: (context, locale, child) => MaterialApp.router(
          title: 'OpenModScan Mobile',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
