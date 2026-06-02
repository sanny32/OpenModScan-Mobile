import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/services/connection_manager.dart';

import 'helpers.dart';
import 'modbus_tcp_test_server.dart';

void main() {
  late ConnectionManager manager;

  setUp(() async {
    await resetAppTestState();
    manager = ConnectionManager.instance;
    await manager.resetForTesting();
  });

  tearDown(() => manager.resetForTesting());

  test('connect and disconnect update connected device ids', () async {
    final server = await ModbusTcpTestServer.start();
    addTearDown(server.close);
    final device = _device(server);

    await manager.connect(device);

    expect(manager.isConnected(device), isTrue);
    expect(manager.connectedDeviceIds.value, {device.id});

    await manager.disconnect(device);

    expect(manager.isConnected(device), isFalse);
    expect(manager.connectedDeviceIds.value, isEmpty);
  });

  test('read and write operations delegate to the connected client', () async {
    final server = await ModbusTcpTestServer.start(
      holdingRegisters: {1: 7},
      inputRegisters: {2: 8},
      coils: {3: true},
      discreteInputs: {4: false},
    );
    addTearDown(server.close);
    final device = _device(server);
    await manager.connect(device);

    expect(
      await manager.readHoldingRegisters(device, startAddress: 1, count: 1),
      [7],
    );
    expect(
      await manager.readInputRegisters(device, startAddress: 2, count: 1),
      [8],
    );
    expect(await manager.readCoils(device, startAddress: 3, count: 1), [true]);
    expect(
      await manager.readDiscreteInputs(device, startAddress: 4, count: 1),
      [false],
    );

    await manager.writeHoldingRegister(device, address: 5, value: 0x1234);
    final usedFallback = await manager.writeHoldingRegisters(
      device,
      startAddress: 6,
      values: [0x1111, 0x2222],
    );
    await manager.writeCoil(device, address: 8, value: true);

    expect(usedFallback, isFalse);
    expect(server.holdingRegisters[5], 0x1234);
    expect(server.holdingRegisters[6], 0x1111);
    expect(server.holdingRegisters[7], 0x2222);
    expect(server.coils[8], isTrue);
  });

  test('operations on disconnected devices throw clear state errors', () {
    final device = DeviceInfo(
      id: 'disconnected',
      name: 'Disconnected PLC',
      host: '127.0.0.1',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
    );

    expect(
      () => manager.readHoldingRegisters(device, startAddress: 0, count: 1),
      throwsA(isA<StateError>()),
    );
    expect(
      () => manager.writeCoil(device, address: 0, value: true),
      throwsA(isA<StateError>()),
    );
  });
}

DeviceInfo _device(ModbusTcpTestServer server) => DeviceInfo(
  id: 'plc',
  name: 'PLC',
  host: server.host,
  port: server.port,
  protocol: ProtocolType.modbusTcp,
  unitId: 1,
);
