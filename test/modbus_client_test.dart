import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/modbus_exception.dart';
import 'package:omodscan_mobile/services/modbus_client.dart';

import 'modbus_tcp_test_server.dart';

void main() {
  group('ModbusClient', () {
    test('connects and reads registers and bits', () async {
      final server = await ModbusTcpTestServer.start(
        holdingRegisters: {0: 0x1234, 1: 0xabcd},
        inputRegisters: {3: 0x00ff},
        coils: {4: true, 5: false, 6: true},
        discreteInputs: {7: false, 8: true},
      );
      addTearDown(server.close);
      final client = ModbusClient(_device(server));
      addTearDown(client.disconnect);

      await client.connect();

      expect(client.isConnected, isTrue);
      expect(await client.readHoldingRegisters(0, 2), [0x1234, 0xabcd]);
      expect(await client.readInputRegisters(3, 1), [0x00ff]);
      expect(await client.readCoils(4, 3), [true, false, true]);
      expect(await client.readDiscreteInputs(7, 2), [false, true]);
    });

    test('writes single and multiple holding registers and coils', () async {
      final server = await ModbusTcpTestServer.start();
      addTearDown(server.close);
      final client = ModbusClient(_device(server));
      addTearDown(client.disconnect);
      await client.connect();

      await client.writeHoldingRegister(2, 0x4567);
      final usedFallback = await client.writeHoldingRegisters(3, [
        0x0102,
        0x0304,
      ]);
      await client.writeCoil(9, true);

      expect(usedFallback, isFalse);
      expect(server.holdingRegisters[2], 0x4567);
      expect(server.holdingRegisters[3], 0x0102);
      expect(server.holdingRegisters[4], 0x0304);
      expect(server.coils[9], isTrue);
      expect(server.singleRegisterWrites, [2]);
      expect(server.multipleRegisterWriteAttempts, 1);
      expect(server.coilWrites, [9]);
    });

    test('falls back from multiple-register write to single-register writes',
        () async {
      final server = await ModbusTcpTestServer.start(
        illegalMultipleRegisterWrite: true,
      );
      addTearDown(server.close);
      final client = ModbusClient(_device(server));
      addTearDown(client.disconnect);
      await client.connect();

      final usedFallback = await client.writeHoldingRegisters(8, [
        0x1111,
        0x2222,
      ]);

      expect(usedFallback, isTrue);
      expect(server.multipleRegisterWriteAttempts, 1);
      expect(server.singleRegisterWrites, [8, 9]);
      expect(server.holdingRegisters[8], 0x1111);
      expect(server.holdingRegisters[9], 0x2222);
    });

    test('maps Modbus exception responses to ModbusClientException', () async {
      final server = await ModbusTcpTestServer.start(
        exceptionByFunction: {0x03: 0x02},
      );
      addTearDown(server.close);
      final client = ModbusClient(_device(server));
      addTearDown(client.disconnect);
      await client.connect();

      expect(
        () => client.readHoldingRegisters(0, 1),
        throwsA(
          isA<ModbusClientException>().having(
            (error) => error.exceptionCode,
            'exceptionCode',
            ModbusExceptionCode.illegalDataAddress,
          ),
        ),
      );
    });

    test('validates ranges before sending requests', () async {
      final client = ModbusClient(
        DeviceInfo(
          name: 'PLC',
          host: '127.0.0.1',
          port: 502,
          protocol: ProtocolType.modbusTcp,
          unitId: 1,
        ),
      );

      expect(
        () => client.readHoldingRegisters(-1, 1),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => client.readHoldingRegisters(0, 126),
        throwsA(isA<RangeError>()),
      );
      expect(() => client.readCoils(0, 2001), throwsA(isA<RangeError>()));
      expect(
        () => client.writeHoldingRegister(0, 0x10000),
        throwsA(isA<RangeError>()),
      );
      expect(() => client.writeCoil(0x10000, true), throwsA(isA<RangeError>()));
    });

    test('disconnect clears connection state', () async {
      final server = await ModbusTcpTestServer.start();
      addTearDown(server.close);
      final client = ModbusClient(_device(server));

      await client.connect();
      await client.disconnect();

      expect(client.isConnected, isFalse);
    });
  });
}

DeviceInfo _device(ModbusTcpTestServer server) => DeviceInfo(
  name: 'PLC',
  host: server.host,
  port: server.port,
  protocol: ProtocolType.modbusTcp,
  unitId: 1,
);
