import 'package:modbus_client/modbus_client.dart' as modbus;
import 'package:modbus_client_tcp/modbus_client_tcp.dart' as modbus_tcp;

import '../models/device_info.dart';

class ModbusClient {
  static const _maxRegistersPerRead = 125;

  final DeviceInfo device;
  modbus_tcp.ModbusClientTcp? _tcpClient;

  ModbusClient(this.device);

  bool get isConnected => _tcpClient?.isConnected ?? false;

  Future<void> connect() async {
    if (device.protocol != ProtocolType.modbusTcp) {
      throw UnsupportedError('Only Modbus TCP connections are implemented.');
    }

    final timeout = Duration(milliseconds: device.timeout);
    final client =
        _tcpClient ??
        modbus_tcp.ModbusClientTcp(
          device.host,
          serverPort: device.port,
          unitId: device.unitId,
          connectionTimeout: timeout,
          responseTimeout: timeout,
        );
    if (!await client.connect()) {
      throw ModbusClientException('Could not connect to ${device.address}.');
    }
    _tcpClient = client;
  }

  Future<void> disconnect() async {
    await _tcpClient?.disconnect();
    _tcpClient = null;
  }

  Future<List<int>> readHoldingRegisters(int startAddress, int quantity) =>
      _readRegisters(
        modbus.ModbusElementType.holdingRegister,
        startAddress,
        quantity,
      );

  Future<List<int>> readInputRegisters(int startAddress, int quantity) =>
      _readRegisters(
        modbus.ModbusElementType.inputRegister,
        startAddress,
        quantity,
      );

  Future<List<int>> _readRegisters(
    modbus.ModbusElementType type,
    int startAddress,
    int quantity,
  ) async {
    _validateReadRange(startAddress, quantity);

    final registers = [
      for (var offset = 0; offset < quantity; offset++)
        modbus.ModbusUint16Register(
          name: 'Register ${startAddress + offset}',
          address: startAddress + offset,
          type: type,
        ),
    ];
    final group = modbus.ModbusElementsGroup(registers);
    final response = await _requireTcpClient().send(group.getReadRequest());
    if (response != modbus.ModbusResponseCode.requestSucceed) {
      throw ModbusClientException('Modbus read failed: ${response.name}.');
    }

    return [for (final register in registers) _valueFor(register)];
  }

  modbus_tcp.ModbusClientTcp _requireTcpClient() {
    final client = _tcpClient;
    if (client == null) {
      throw StateError('Modbus client is not connected.');
    }
    return client;
  }

  int _valueFor(modbus.ModbusUint16Register register) {
    final value = register.value;
    if (value == null) {
      throw ModbusClientException(
        'Modbus response did not update register ${register.address}.',
      );
    }
    return value.toInt();
  }

  void _validateReadRange(int startAddress, int quantity) {
    if (startAddress < 0 || startAddress > 0xffff) {
      throw RangeError.range(startAddress, 0, 0xffff, 'startAddress');
    }
    if (quantity < 1 || quantity > _maxRegistersPerRead) {
      throw RangeError.range(quantity, 1, _maxRegistersPerRead, 'quantity');
    }
    if (startAddress + quantity > 0x10000) {
      throw RangeError('Read range exceeds Modbus register address space.');
    }
  }
}

class ModbusClientException implements Exception {
  final String message;

  const ModbusClientException(this.message);

  @override
  String toString() => 'ModbusClientException: $message';
}
