import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/registers/registers_controller.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/register_list.dart';
import 'package:omodscan_mobile/navigation/navigation_targets.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.resetToDefaults();
  });

  test('controller operates over an arbitrary DeviceRepositoryPort', () async {
    // Build a controller backed by an in-memory port (not DeviceRepository),
    // proving the controllers depend on the abstraction rather than the
    // concrete SharedPreferences-backed implementation.
    final repository = FakeDeviceRepository([
      DeviceInfo(
        id: 'device-port',
        name: 'PLC Port',
        host: '127.0.0.50',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        registerLists: [RegisterList(id: 'list-port', name: 'List 1')],
      ),
    ]);
    final controller = RegistersController(
      repository,
      PollingConnectionRuntime(),
      DemoRegisterRuntime(),
      AppSettings.instance,
    );

    await controller.selectTarget(
      const RegistersRouteArgs(
        deviceId: 'device-port',
        registerListId: 'list-port',
      ),
    );
    await controller.updateEntry(40001, 'UInt32', 'Flow');

    final entry = repository
        .findById('device-port')!
        .registerLists
        .single
        .entries
        .single;
    expect(entry.address, 40001);
    expect(entry.typeName, 'UInt32');
    expect(entry.comment, 'Flow');

    controller.dispose();
  });
}
