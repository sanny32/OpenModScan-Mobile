import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/registers/registers_controller.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/register_list.dart';
import 'package:omodscan_mobile/navigation/navigation_targets.dart';
import 'package:omodscan_mobile/runtime/fakes/demo_runtime.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.resetToDefaults();
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
      AppSettings.instance,
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

  test('setAllTypes still writes multi-word types to every address', () async {
    final repository = DeviceRepository.instance;
    await repository.replaceAll([
      DeviceInfo(
        id: 'device-set-all',
        name: 'PLC Set All',
        host: '127.0.0.12',
        port: 502,
        protocol: ProtocolType.modbusTcp,
        unitId: 1,
        registerLists: [
          RegisterList(
            id: 'list-set-all',
            name: 'List 1',
            startAddress: 1,
            count: 3,
          ),
        ],
      ),
    ]);
    final controller = RegistersController(
      repository,
      _TestConnectionRuntime(),
      DemoRegisterRuntime(),
      AppSettings.instance,
    );

    await controller.selectTarget(
      const RegistersRouteArgs(
        deviceId: 'device-set-all',
        registerListId: 'list-set-all',
      ),
    );
    await controller.setAllTypes('UInt32');

    final entries = repository
        .findById('device-set-all')!
        .registerLists
        .single
        .entries;
    expect(entries.map((entry) => entry.address), [40001, 40002, 40003]);
    expect(entries.every((entry) => entry.typeName == 'UInt32'), isTrue);

    controller.dispose();
  });

  test('demo runtime can expose an empty non-demo mode', () {
    const registers = DemoRegisterRuntime(enabled: false);
    final logs = DemoTrafficLogSource(enabled: false);

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
      AppSettings.instance,
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

    expect(connections.lastHoldingStartAddress, 1);
    expect(connections.lastHoldingCount, 2);
    expect(controller.runtimeValues[40001]?.value, '17');
    expect(controller.runtimeValues[40001]?.previous, isNull);
    final readAt = controller.runtimeValues[40001]?.readAt;
    expect(readAt, isNotNull);
    expect(readAt!.isBefore(beforeRead), isFalse);
    expect(readAt.isAfter(afterRead), isFalse);
    expect(controller.lastRegisterReadAt, readAt);
    expect(controller.runtimeValues[40002]?.value, '23');
    expect(controller.runtimeValues[40002]?.readAt, readAt);

    connections.holdingValues = [19, 29];
    await controller.readRegisters(
      regType: '4xxxx',
      startAddress: 40001,
      count: 2,
    );
    expect(controller.runtimeValues[40001]?.value, '19');
    expect(controller.runtimeValues[40001]?.previous, '17');

    controller.dispose();
  });

  test('reads input registers using register address type mapping', () async {
    final repository = DeviceRepository.instance;
    final device = DeviceInfo(
      id: 'device-input',
      name: 'PLC Input',
      host: '127.0.0.8',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'list-input', name: 'List 1')],
    );
    await repository.replaceAll([device]);

    final connections = _TestConnectionRuntime()..inputValues = [31, 37];
    await connections.connect(device);
    final controller = RegistersController(
      repository,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
    );
    await controller.selectTarget(
      const RegistersRouteArgs(
        deviceId: 'device-input',
        registerListId: 'list-input',
      ),
    );

    await controller.readRegisters(
      regType: '3xxxx',
      startAddress: 30001,
      count: 2,
    );

    expect(connections.lastInputStartAddress, 1);
    expect(connections.lastInputCount, 2);
    expect(controller.runtimeValues[30001]?.value, '31');
    expect(controller.runtimeValues[30002]?.value, '37');

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
      AppSettings.instance,
    );
    await controller.selectTarget(
      const RegistersRouteArgs(deviceId: 'device-d', registerListId: 'list-d'),
    );

    final beforeRead = DateTime.now();
    await controller.readStatuses(
      statusType: '0xxxx',
      startAddress: 0,
      count: 2,
    );
    final afterRead = DateTime.now();

    expect(connections.lastCoilStartAddress, 0);
    expect(connections.lastCoilCount, 2);
    final first = controller.runtimeStatusValues[('0xxxx', 0)];
    expect(first?.value, isTrue);
    expect(first?.previous, isNull);
    expect(first?.readAt, isNotNull);
    expect(first!.readAt!.isBefore(beforeRead), isFalse);
    expect(first.readAt!.isAfter(afterRead), isFalse);
    expect(controller.lastStatusReadAt, first.readAt);
    expect(controller.runtimeStatusValues[('0xxxx', 1)]?.value, isFalse);

    connections.coilValues = [false, true];
    await controller.readStatuses(
      statusType: '0xxxx',
      startAddress: 0,
      count: 2,
    );
    expect(controller.runtimeStatusValues[('0xxxx', 0)]?.value, isFalse);
    expect(controller.runtimeStatusValues[('0xxxx', 0)]?.previous, isTrue);

    controller.dispose();
  });

  test('reads discrete inputs using status address type mapping', () async {
    final repository = DeviceRepository.instance;
    final device = DeviceInfo(
      id: 'device-discrete',
      name: 'PLC Discrete',
      host: '127.0.0.9',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'list-discrete', name: 'List 1')],
    );
    await repository.replaceAll([device]);

    final connections = _TestConnectionRuntime()
      ..discreteInputValues = [false, true];
    await connections.connect(device);
    final controller = RegistersController(
      repository,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
    );
    await controller.selectTarget(
      const RegistersRouteArgs(
        deviceId: 'device-discrete',
        registerListId: 'list-discrete',
      ),
    );

    await controller.readStatuses(
      statusType: '1xxxx',
      startAddress: 10012,
      count: 2,
    );

    expect(connections.lastDiscreteInputStartAddress, 12);
    expect(connections.lastDiscreteInputCount, 2);
    expect(controller.runtimeStatusValues[('1xxxx', 10012)]?.value, isFalse);
    expect(controller.runtimeStatusValues[('1xxxx', 10013)]?.value, isTrue);

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
      AppSettings.instance,
    );
    await controller.selectTarget(
      const RegistersRouteArgs(deviceId: 'device-e', registerListId: 'list-e'),
    );

    await controller.updateStatusEntry('1xxxx', 10013, 'Line ready');

    final entry = repository
        .findById('device-e')!
        .registerLists
        .single
        .statusEntries
        .single;
    expect(entry.statusType, '1xxxx');
    expect(entry.address, 10013);
    expect(entry.comment, 'Line ready');

    controller.dispose();
  });

  test('writes holding register through connected runtime', () async {
    final repository = DeviceRepository.instance;
    final device = DeviceInfo(
      id: 'device-write-holding',
      name: 'PLC Write Holding',
      host: '127.0.0.13',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'list-write-holding', name: 'List 1')],
    );
    await repository.replaceAll([device]);

    final connections = _TestConnectionRuntime();
    await connections.connect(device);
    final controller = RegistersController(
      repository,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
    );
    await controller.selectTarget(
      const RegistersRouteArgs(
        deviceId: 'device-write-holding',
        registerListId: 'list-write-holding',
      ),
    );

    await controller.writeValue(40001, '42');

    expect(connections.lastWriteHoldingAddress, 1);
    expect(connections.lastWriteHoldingValue, 42);
    expect(controller.runtimeValues[40001]?.value, '42');
    expect(controller.runtimeValues[40001]?.previous, isNull);
    expect(controller.runtimeValues[40001]?.readAt, isNotNull);

    await controller.writeValue(40001, '43');
    expect(controller.runtimeValues[40001]?.value, '43');
    expect(controller.runtimeValues[40001]?.previous, '42');

    controller.dispose();
  });

  test('writes coil through connected runtime', () async {
    final repository = DeviceRepository.instance;
    final device = DeviceInfo(
      id: 'device-write-coil',
      name: 'PLC Write Coil',
      host: '127.0.0.14',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'list-write-coil', name: 'List 1')],
    );
    await repository.replaceAll([device]);

    final connections = _TestConnectionRuntime();
    await connections.connect(device);
    final controller = RegistersController(
      repository,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
    );
    await controller.selectTarget(
      const RegistersRouteArgs(
        deviceId: 'device-write-coil',
        registerListId: 'list-write-coil',
      ),
    );

    await controller.writeStatusValue(
      statusType: '0xxxx',
      address: 0,
      value: true,
    );

    expect(connections.lastWriteCoilAddress, 0);
    expect(connections.lastWriteCoilValue, isTrue);
    expect(controller.runtimeStatusValues[('0xxxx', 0)]?.value, isTrue);
    expect(controller.runtimeStatusValues[('0xxxx', 0)]?.previous, isNull);
    expect(controller.runtimeStatusValues[('0xxxx', 0)]?.readAt, isNotNull);

    await controller.writeStatusValue(
      statusType: '0xxxx',
      address: 0,
      value: false,
    );
    expect(controller.runtimeStatusValues[('0xxxx', 0)]?.value, isFalse);
    expect(controller.runtimeStatusValues[('0xxxx', 0)]?.previous, isTrue);

    controller.dispose();
  });

  test('write disabled setting prevents runtime write calls', () async {
    final repository = DeviceRepository.instance;
    final device = DeviceInfo(
      id: 'device-write-disabled',
      name: 'PLC Write Disabled',
      host: '127.0.0.15',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'list-write-disabled', name: 'List 1')],
    );
    await repository.replaceAll([device]);

    final connections = _TestConnectionRuntime();
    await connections.connect(device);
    final controller = RegistersController(
      repository,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
    );
    await controller.selectTarget(
      const RegistersRouteArgs(
        deviceId: 'device-write-disabled',
        registerListId: 'list-write-disabled',
      ),
    );

    await AppSettings.instance.setWriteEnabled(false);
    await controller.writeValue(40001, '42');
    await controller.writeStatusValue(
      statusType: '0xxxx',
      address: 0,
      value: true,
    );

    expect(connections.lastWriteHoldingAddress, isNull);
    expect(connections.lastWriteCoilAddress, isNull);
    expect(controller.runtimeValues[40001], isNull);
    expect(controller.runtimeStatusValues[('0xxxx', 0)], isNull);

    controller.dispose();
  });

  test('honors injected addressBase when computing modbus address', () async {
    final repository = DeviceRepository.instance;
    final device = DeviceInfo(
      id: 'device-base',
      name: 'PLC Base',
      host: '127.0.0.16',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [RegisterList(id: 'list-base', name: 'List 1')],
    );
    await repository.replaceAll([device]);

    final connections = _TestConnectionRuntime();
    await connections.connect(device);
    final controller = RegistersController(
      repository,
      connections,
      const DemoRegisterRuntime(enabled: false),
      AppSettings.instance,
    );
    await controller.selectTarget(
      const RegistersRouteArgs(
        deviceId: 'device-base',
        registerListId: 'list-base',
      ),
    );

    // 0-based (default): display 40001 maps to modbus offset 1.
    await controller.writeValue(40001, '7');
    expect(connections.lastWriteHoldingAddress, 1);

    // 1-based: the injected setting shifts the same display address to 0.
    await AppSettings.instance.setAddressBase(AppSettings.addressBases[1]);
    await controller.writeValue(40001, '7');
    expect(connections.lastWriteHoldingAddress, 0);

    controller.dispose();
  });
}

class _TestConnectionRuntime implements ConnectionRuntime {
  final _ids = ValueNotifier<Set<String>>(const {});
  var holdingValues = <int>[];
  var inputValues = <int>[];
  var coilValues = <bool>[];
  var discreteInputValues = <bool>[];
  int? lastHoldingStartAddress;
  int? lastHoldingCount;
  int? lastInputStartAddress;
  int? lastInputCount;
  int? lastCoilStartAddress;
  int? lastCoilCount;
  int? lastDiscreteInputStartAddress;
  int? lastDiscreteInputCount;
  int? lastWriteHoldingAddress;
  int? lastWriteHoldingValue;
  int? lastWriteCoilAddress;
  bool? lastWriteCoilValue;

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
  }) async {
    lastInputStartAddress = startAddress;
    lastInputCount = count;
    return inputValues.take(count).toList();
  }

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
  }) async {
    lastDiscreteInputStartAddress = startAddress;
    lastDiscreteInputCount = count;
    return discreteInputValues.take(count).toList();
  }

  @override
  Future<void> writeHoldingRegister(
    DeviceInfo device, {
    required int address,
    required int value,
  }) async {
    lastWriteHoldingAddress = address;
    lastWriteHoldingValue = value;
  }

  @override
  Future<void> writeCoil(
    DeviceInfo device, {
    required int address,
    required bool value,
  }) async {
    lastWriteCoilAddress = address;
    lastWriteCoilValue = value;
  }
}
