import 'package:modbus_client/modbus_client.dart' as modbus;
import 'package:modbus_client_tcp/modbus_client_tcp.dart' as modbus_tcp;

import '../models/device_info.dart';
import '../models/modbus_exception.dart';

class ModbusClient {
  static const _maxRegistersPerRead = 125;
  static const _maxBitsPerRead = 2000;

  final DeviceInfo device;
  modbus_tcp.ModbusClientTcp? _tcpClient;

  ModbusClient(this.device);

  bool get isConnected => _tcpClient?.isConnected ?? false;

  Future<void> connect() async {
    if (!device.protocol.supportsConnection) {
      throw UnsupportedError(device.protocol.unsupportedConnectionMessage);
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

  Future<List<bool>> readCoils(int startAddress, int quantity) =>
      _readBits(modbus.ModbusElementType.coil, startAddress, quantity);

  Future<List<bool>> readDiscreteInputs(int startAddress, int quantity) =>
      _readBits(modbus.ModbusElementType.discreteInput, startAddress, quantity);

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
      throw _exceptionForResponse(response);
    }

    return [for (final register in registers) _valueFor(register)];
  }

  Future<List<bool>> _readBits(
    modbus.ModbusElementType type,
    int startAddress,
    int quantity,
  ) async {
    _validateBitReadRange(startAddress, quantity);

    final bits = [
      for (var offset = 0; offset < quantity; offset++)
        type == modbus.ModbusElementType.coil
            ? modbus.ModbusCoil(
                name: 'Coil ${startAddress + offset}',
                address: startAddress + offset,
              )
            : modbus.ModbusDiscreteInput(
                name: 'Discrete input ${startAddress + offset}',
                address: startAddress + offset,
              ),
    ];
    final group = modbus.ModbusElementsGroup(bits);
    final response = await _requireTcpClient().send(group.getReadRequest());
    if (response != modbus.ModbusResponseCode.requestSucceed) {
      throw _exceptionForResponse(response);
    }

    return [for (final bit in bits) _bitValueFor(bit)];
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

  bool _bitValueFor(modbus.ModbusBitElement bit) {
    final value = bit.value;
    if (value == null) {
      throw ModbusClientException(
        'Modbus response did not update bit ${bit.address}.',
      );
    }
    return value;
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

  void _validateBitReadRange(int startAddress, int quantity) {
    if (startAddress < 0 || startAddress > 0xffff) {
      throw RangeError.range(startAddress, 0, 0xffff, 'startAddress');
    }
    if (quantity < 1 || quantity > _maxBitsPerRead) {
      throw RangeError.range(quantity, 1, _maxBitsPerRead, 'quantity');
    }
    if (startAddress + quantity > 0x10000) {
      throw RangeError('Read range exceeds Modbus bit address space.');
    }
  }
}

class ModbusClientException implements Exception {
  final String message;
  final ModbusExceptionCode? exceptionCode;

  const ModbusClientException(this.message) : exceptionCode = null;

  ModbusClientException.modbus(ModbusExceptionCode code)
    : message = code.label,
      exceptionCode = code;

  @override
  String toString() => 'ModbusClientException: $message';
}

ModbusClientException _exceptionForResponse(
  modbus.ModbusResponseCode response,
) {
  final exception = ModbusExceptionCode.fromCode(response.code);
  if (exception != null) {
    return ModbusClientException.modbus(exception);
  }
  return ModbusClientException(response.name);
}
