import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/devices/device_screen.dart';
import '../features/devices/device_write_screen.dart';
import '../features/devices/devices_controller.dart';
import '../features/devices/devices_screen.dart';
import '../features/registers/registers_controller.dart';
import '../features/registers/registers_screen.dart';
import '../features/settings/settings_controller.dart';
import '../features/settings/settings_screen.dart';
import '../features/traffic/traffic_controller.dart';
import '../features/traffic/traffic_screen.dart';
import '../l10n/l10n.dart';
import '../widgets/app_test_keys.dart';
import 'navigation_targets.dart';

/// Route locations for the four bottom-navigation branches plus the device
/// detail sub-route nested under the devices branch.
class AppRoutes {
  static const devices = '/devices';
  static const deviceDetail = '/devices/detail';
  static const deviceWrite = '/devices/detail/write';
  static const registers = '/registers';
  static const traffic = '/traffic';
  static const settings = '/settings';
}

/// Builds the app's [GoRouter] with an independent navigation stack per tab.
GoRouter createAppRouter({
  required DevicesController devicesController,
  required RegistersController registersController,
  required TrafficController trafficController,
  required SettingsController settingsController,
  required ValueNotifier<String?> registersReturnDeviceId,
}) {
  final branchNavigatorKeys = [
    GlobalKey<NavigatorState>(debugLabel: 'devicesBranch'),
    GlobalKey<NavigatorState>(debugLabel: 'registersBranch'),
    GlobalKey<NavigatorState>(debugLabel: 'trafficBranch'),
    GlobalKey<NavigatorState>(debugLabel: 'settingsBranch'),
  ];

  Future<void> openRegisters(
    BuildContext context,
    RegistersRouteArgs target,
  ) async {
    await registersController.selectTarget(target);
    if (!context.mounted) return;
    registersReturnDeviceId.value = target.deviceId;
    context.go(AppRoutes.registers);
  }

  void openTraffic(BuildContext context, TrafficRouteArgs target) {
    trafficController.selectTarget(target);
    context.go(AppRoutes.traffic);
  }

  void returnFromRegisters(BuildContext context) {
    final deviceId = registersReturnDeviceId.value;
    registersReturnDeviceId.value = null;
    context.go(AppRoutes.deviceDetail, extra: deviceId);
  }

  return GoRouter(
    initialLocation: AppRoutes.devices,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _ShellScaffold(
          navigationShell: navigationShell,
          registersReturnDeviceId: registersReturnDeviceId,
          branchNavigatorKeys: branchNavigatorKeys,
        ),
        branches: [
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[0],
            routes: [
              GoRoute(
                path: AppRoutes.devices,
                builder: (context, state) => DevicesScreen(
                  controller: devicesController,
                  onOpenDevice: (deviceId) =>
                      context.go(AppRoutes.deviceDetail, extra: deviceId),
                ),
                routes: [
                  GoRoute(
                    path: 'detail',
                    builder: (context, state) => DeviceScreen(
                      deviceId: state.extra! as String,
                      controller: devicesController,
                      onOpenRegisters: (target) =>
                          openRegisters(context, target),
                      onOpenTraffic: (target) => openTraffic(context, target),
                      onOpenWrite: () => context.push(
                        AppRoutes.deviceWrite,
                        extra: state.extra! as String,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'write',
                        builder: (context, state) => DeviceWriteScreen(
                          deviceId: state.extra! as String,
                          controller: devicesController,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[1],
            routes: [
              GoRoute(
                path: AppRoutes.registers,
                builder: (context, state) => RegistersScreen(
                  controller: registersController,
                  returnDeviceId: registersReturnDeviceId,
                  onReturnToDevice: () => returnFromRegisters(context),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[2],
            routes: [
              GoRoute(
                path: AppRoutes.traffic,
                builder: (context, state) =>
                    TrafficScreen(controller: trafficController),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[3],
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) =>
                    SettingsScreen(controller: settingsController),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _ShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final ValueNotifier<String?> registersReturnDeviceId;
  final List<GlobalKey<NavigatorState>> branchNavigatorKeys;

  const _ShellScaffold({
    required this.navigationShell,
    required this.registersReturnDeviceId,
    required this.branchNavigatorKeys,
  });

  void _onTap(int index) {
    final isActiveTab = index == navigationShell.currentIndex;
    registersReturnDeviceId.value = null;
    if (isActiveTab) {
      branchNavigatorKeys[index].currentState?.popUntil(
        (route) => route.isFirst,
      );
    }
    navigationShell.goBranch(index, initialLocation: isActiveTab);
  }

  Future<void> _handlePop() async {
    final navigator =
        navigationShell.shellRouteContext.navigatorKey.currentState;
    if (await navigator?.maybePop() ?? false) return;
    if (navigationShell.currentIndex == 1 &&
        registersReturnDeviceId.value != null) {
      registersReturnDeviceId.value = null;
      navigationShell.goBranch(0);
    } else if (navigationShell.currentIndex != 0) {
      navigationShell.goBranch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTap,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(
                Icons.devices_outlined,
                key: AppTestKeys.navDevicesTab,
              ),
              activeIcon: const Icon(
                Icons.devices,
                key: AppTestKeys.navDevicesTab,
              ),
              label: l10n.navDevices,
            ),
            BottomNavigationBarItem(
              icon: const Icon(
                Icons.grid_on_outlined,
                key: AppTestKeys.navRegistersTab,
              ),
              activeIcon: const Icon(
                Icons.grid_on,
                key: AppTestKeys.navRegistersTab,
              ),
              label: l10n.navRegisters,
            ),
            BottomNavigationBarItem(
              icon: const Icon(
                Icons.list_alt_outlined,
                key: AppTestKeys.navLogTab,
              ),
              activeIcon: const Icon(
                Icons.list_alt,
                key: AppTestKeys.navLogTab,
              ),
              label: l10n.navLog,
            ),
            BottomNavigationBarItem(
              icon: const Icon(
                Icons.settings_outlined,
                key: AppTestKeys.navSettingsTab,
              ),
              activeIcon: const Icon(
                Icons.settings,
                key: AppTestKeys.navSettingsTab,
              ),
              label: l10n.settingsTitle,
            ),
          ],
        ),
      ),
    );
  }
}
