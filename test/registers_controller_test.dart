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

    final beforeRead = DateTime.now();
    await controller.readRegisters(
      regType: '4xxxx',
      startAddress: 40001,
      count: 2,
    );
    final afterRead = DateTime.now();

    expect(connections.lastHoldingStartAddress, 0);
    expect(connections.lastHoldingCount, 2);
    expect(controller.runtimeValues[40001]?.$1, '17');
    expect(controller.runtimeValues[40001]?.$2, isNull);
    final readAt = controller.runtimeValues[40001]?.$3;
    expect(readAt, isNotNull);
    expect(readAt!.isBefore(beforeRead), isFalse);
    expect(readAt.isAfter(afterRead), isFalse);
    expect(controller.lastRegisterReadAt, readAt);
    expect(controller.runtimeValues[40002]?.$1, '23');
    expect(controller.runtimeValues[40002]?.$3, readAt);

    connections.holdingValues = [19, 29];
    await controller.readRegisters(
      regType: '4xxxx',
      startAddress: 40001,
      count: 2,
    );
    expect(controller.runtimeValues[40001]?.$1, '19');
    expect(controller.runtimeValues[40001]?.$2, '17');

    controller.dispose();
  });

  test('reads coils into runtime status values', () async {
    final repository = DeviceRepository.instance;
    final device = DeviceInfo(
      id: 'device-d',
      name: 'PLC D',
      host: '127.0.0.4',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'list-d', name: 'List 1')],
    );
    await repository.replaceAll([device]);

    final connections = _TestConnectionRuntime()..coilValues = [true, false];
    await connections.connect(device);
    final controller = RegistersController(
      repository,
      connections,
      const DemoRegisterRuntime(enabled: false),
    );
    await controller.selectTarget(
      const RegistersRouteArgs(deviceId: 'device-d', registerListId: 'list-d'),
    );

    final beforeRead = DateTime.now();
    await controller.readStatuses(
      statusType: '0xxxx',
      startAddress: 7,
      count: 2,
    );
    final afterRead = DateTime.now();

    expect(connections.lastCoilStartAddress, 7);
    expect(connections.lastCoilCount, 2);
    final first = controller.runtimeStatusValues[('0xxxx', 7)];
    expect(first?.$1, isTrue);
    expect(first?.$2, isNull);
    expect(first?.$3, isNotNull);
    expect(first!.$3!.isBefore(beforeRead), isFalse);
    expect(first.$3!.isAfter(afterRead), isFalse);
    expect(controller.lastStatusReadAt, first.$3);
    expect(controller.runtimeStatusValues[('0xxxx', 8)]?.$1, isFalse);

    connections.coilValues = [false, true];
    await controller.readStatuses(
      statusType: '0xxxx',
      startAddress: 7,
      count: 2,
    );
    expect(controller.runtimeStatusValues[('0xxxx', 7)]?.$1, isFalse);
    expect(controller.runtimeStatusValues[('0xxxx', 7)]?.$2, isTrue);

    controller.dispose();
  });

  test('updates status comment through repository', () async {
    final repository = DeviceRepository.instance;
    await repository.replaceAll([
      DeviceInfo(
        id: 'device-e',
        name: 'PLC E',
        host: '127.0.0.5',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        registerLists: [RegisterList(id: 'list-e', name: 'List 1')],
      ),
    ]);
    final controller = RegistersController(
      repository,
      _TestConnectionRuntime(),
      const DemoRegisterRuntime(enabled: false),
    );
    await controller.selectTarget(
      const RegistersRouteArgs(deviceId: 'device-e', registerListId: 'list-e'),
    );

    await controller.updateStatusEntry('1xxxx', 12, 'Line ready');

    final entry = repository
        .findById('device-e')!
        .registerLists
        .single
        .statusEntries
        .single;
    expect(entry.statusType, '1xxxx');
    expect(entry.address, 12);
    expect(entry.comment, 'Line ready');

    controller.dispose();
  });
}

class _TestConnectionRuntime implements ConnectionRuntime {
  final _ids = ValueNotifier<Set<String>>(const {});
  var holdingValues = <int>[];
  var coilValues = <bool>[];
  int? lastHoldingStartAddress;
  int? lastHoldingCount;
  int? lastCoilStartAddress;
  int? lastCoilCount;

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

  @override
  Future<List<bool>> readCoils(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    lastCoilStartAddress = startAddress;
    lastCoilCount = count;
    return coilValues.take(count).toList();
  }

  @override
  Future<List<bool>> readDiscreteInputs(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async => const [];
}
