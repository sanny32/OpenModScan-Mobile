import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/devices/device_screen.dart';
import '../features/devices/devices_controller.dart';
import '../features/devices/devices_screen.dart';
import '../features/registers/registers_controller.dart';
import '../features/registers/registers_screen.dart';
import '../features/settings/settings_controller.dart';
import '../features/settings/settings_screen.dart';
import '../features/traffic/traffic_controller.dart';
import '../features/traffic/traffic_screen.dart';
import '../l10n/l10n.dart';
import 'navigation_targets.dart';

/// Route locations for the four bottom-navigation branches plus the device
/// detail sub-route nested under the devices branch.
class AppRoutes {
  static const devices = '/devices';
  static const deviceDetail = '/devices/detail';
  static const registers = '/registers';
  static const traffic = '/traffic';
  static const settings = '/settings';
}

/// Builds the app's [GoRouter] using a [StatefulShellRoute.indexedStack] so each
/// tab keeps an independent navigation stack (the IndexedStack + per-tab
/// Navigator behaviour the app shell used to manage by hand).
GoRouter createAppRouter({
  required DevicesController devicesController,
  required RegistersController registersController,
  required TrafficController trafficController,
  required SettingsController settingsController,
  required ValueNotifier<String?> registersReturnDeviceId,
}) {
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
        ),
        branches: [
          StatefulShellBranch(
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
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
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
            routes: [
              GoRoute(
                path: AppRoutes.traffic,
                builder: (context, state) =>
                    TrafficScreen(controller: trafficController),
              ),
            ],
          ),
          StatefulShellBranch(
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

  const _ShellScaffold({
    required this.navigationShell,
    required this.registersReturnDeviceId,
  });

  void _onTap(int index) {
    // Clear the "return to device" affordance whenever the user picks a tab
    // manually; cross-tab flows set it again as needed.
    registersReturnDeviceId.value = null;
    // Re-tapping the active tab pops that branch back to its root.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Future<void> _handlePop() async {
    final navigator =
        navigationShell.shellRouteContext.navigatorKey.currentState;
    if (await navigator?.maybePop() ?? false) return;
    if (navigationShell.currentIndex == 1 &&
        registersReturnDeviceId.value != null) {
      // Mirror the registers "return to device" gesture.
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
