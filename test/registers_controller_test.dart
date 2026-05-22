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

  test('demo runtime can expose an empty non-demo mode', () {
    const registers = DemoRegisterRuntime(enabled: false);
    const logs = DemoTrafficLogSource(enabled: false);

    expect(registers.registersForRange(40001, 10), isEmpty);
    expect(registers.statusesForRange(0, 10), isEmpty);
    expect(logs.entriesFor('device-b'), isEmpty);
  });

  test('reads holding registers into runtime values', () async {
    final repository = DeviceRepository.instance;
    final device = DeviceInfo(
      id: 'device-c',
      name: 'PLC C',
      host: '127.0.0.3',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'list-c', name: 'List 1')],
    );
    await repository.replaceAll([device]);

    final connections = _TestConnectionRuntime()..holdingValues = [17, 23];
    await connections.connect(device);
    final controller = RegistersController(
      repository,
      connections,
      const DemoRegisterRuntime(enabled: false),
    );
    await controller.selectTarget(
      const RegistersRouteArgs(deviceId: 'device-c', registerListId: 'list-c'),
    );

    await controller.readRegisters(
      regType: '4xxxx',
      startAddress: 40001,
      count: 2,
    );

    expect(connections.lastHoldingStartAddress, 0);
    expect(connections.lastHoldingCount, 2);
    expect(controller.runtimeValues[40001], ('17', null));
    expect(controller.runtimeValues[40002], ('23', null));

    connections.holdingValues = [19, 29];
    await controller.readRegisters(
      regType: '4xxxx',
      startAddress: 40001,
      count: 2,
    );
    expect(controller.runtimeValues[40001], ('19', '17'));

    controller.dispose();
  });
}

class _TestConnectionRuntime implements ConnectionRuntime {
  final _ids = ValueNotifier<Set<String>>(const {});
  var holdingValues = <int>[];
  int? lastHoldingStartAddress;
  int? lastHoldingCount;

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

  @override
  Future<List<int>> readHoldingRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    lastHoldingStartAddress = startAddress;
    lastHoldingCount = count;
    return holdingValues.take(count).toList();
  }

  @override
  Future<List<int>> readInputRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async => const [];
}
