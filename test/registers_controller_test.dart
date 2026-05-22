import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/registers/registers_controller.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/register_list.dart';
import 'package:omodscan_mobile/navigation/navigation_targets.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_runtime.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('updates register config through repository', () async {
    final repository = DeviceRepository.instance;
    await repository.replaceAll([
      DeviceInfo(
        id: 'device-b',
        name: 'PLC B',
        host: '127.0.0.2',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        registerLists: [RegisterList(id: 'list-b', name: 'List 1')],
      ),
    ]);
    final controller = RegistersController(
      repository,
      _TestConnectionRuntime(),
      DemoRegisterRuntime(),
    );

    await controller.selectTarget(
      const RegistersRouteArgs(deviceId: 'device-b', registerListId: 'list-b'),
    );
    await controller.updateEntry(40001, 'UInt32', 'Flow');

    final entry = repository
        .findById('device-b')!
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

class _TestConnectionRuntime implements ConnectionRuntime {
  final _ids = ValueNotifier<Set<String>>(const {});

  @override
  ValueListenable<Set<String>> get connectedDeviceIds => _ids;

  @override
  Future<void> connect(DeviceInfo device) async {
    _ids.value = {..._ids.value, device.id};
  }

  @override
  Future<void> disconnect(DeviceInfo device) async {
    _ids.value = Set.of(_ids.value)..remove(device.id);
  }

  @override
  bool isConnected(DeviceInfo device) => _ids.value.contains(device.id);
}
