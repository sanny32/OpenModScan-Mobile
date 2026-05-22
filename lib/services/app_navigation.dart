import 'package:flutter/material.dart';

class _NavBackEntry {
  final int tabIndex;
  final WidgetBuilder? backRouteBuilder;
  const _NavBackEntry({required this.tabIndex, this.backRouteBuilder});
}

class AppNavigationService {
  static final instance = AppNavigationService._();
  AppNavigationService._();

  final tabIndex = ValueNotifier<int>(0);

  /// Non-null means RegistersScreen should switch to this device and start reading.
  final pendingDevice = ValueNotifier<String?>(null);

  /// Non-null means RegistersScreen should activate the list with this id.
  final pendingListId = ValueNotifier<String?>(null);

  /// True when there is a back entry to return to.
  final canGoBack = ValueNotifier<bool>(false);

  final _backStack = <_NavBackEntry>[];

  /// Switch to [tab], optionally storing a [backRoute] to push when the user
  /// presses back from that tab.
  void pushTab({required int tab, WidgetBuilder? backRoute}) {
    _backStack.add(_NavBackEntry(tabIndex: tabIndex.value, backRouteBuilder: backRoute));
    canGoBack.value = true;
    tabIndex.value = tab;
  }

  void goToRegisters(String deviceName, {String? listId, WidgetBuilder? backRoute}) {
    pendingListId.value = listId;
    pendingDevice.value = deviceName;
    pushTab(tab: 1, backRoute: backRoute);
  }

  /// Pop the back stack and navigate to the previous screen.
  void navigateBack(BuildContext context) {
    if (_backStack.isEmpty) return;
    final entry = _backStack.removeLast();
    canGoBack.value = _backStack.isNotEmpty;
    tabIndex.value = entry.tabIndex;
    if (entry.backRouteBuilder != null) {
      Navigator.push(context, MaterialPageRoute(builder: entry.backRouteBuilder!));
    }
  }

  /// Navigate directly to a tab from the bottom nav bar — clears the back stack.
  void selectTab(int index) {
    _backStack.clear();
    canGoBack.value = false;
    tabIndex.value = index;
  }
}
