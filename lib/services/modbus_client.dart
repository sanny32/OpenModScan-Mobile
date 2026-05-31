import 'dart:typed_data';

import 'package:modbus_client/modbus_client.dart' as modbus;
import 'package:modbus_client_tcp/modbus_client_tcp.dart' as modbus_tcp;

import '../models/device_info.dart';
import '../models/modbus_exception.dart';
import 'traffic_log.dart';

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
    TrafficLog.instance.setActiveDevice(device.id);
    try {
      if (!await client.connect()) {
        throw ModbusClientException('Could not connect to ${device.address}.');
      }
    } finally {
      TrafficLog.instance.setActiveDevice(null);
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

  Future<void> writeHoldingRegister(int address, int value) async {
    _validateWriteAddress(address);
    if (value < 0 || value > 0xffff) {
      throw RangeError.range(value, 0, 0xffff, 'value');
    }

    final register = modbus.ModbusUint16Register(
      name: 'Register $address',
      address: address,
      type: modbus.ModbusElementType.holdingRegister,
    );
    final response = await _send(
      register.getWriteRequest(value, rawValue: true),
    );
    if (response != modbus.ModbusResponseCode.requestSucceed) {
      throw _exceptionForResponse(response);
    }
  }

  Future<bool> writeHoldingRegisters(int startAddress, List<int> values) async {
    _validateReadRange(startAddress, values.length);
    for (final value in values) {
      if (value < 0 || value > 0xffff) {
        throw RangeError.range(value, 0, 0xffff, 'value');
      }
    }
    if (values.length == 1) {
      await writeHoldingRegister(startAddress, values.single);
      return false;
    }

    final bytes = Uint8List(values.length * 2);
    final data = ByteData.view(bytes.buffer);
    for (var i = 0; i < values.length; i++) {
      data.setUint16(i * 2, values[i], Endian.big);
    }

    final register = modbus.ModbusBytesRegister(
      name: 'Registers $startAddress',
      address: startAddress,
      byteCount: bytes.length,
      type: modbus.ModbusElementType.holdingRegister,
    );

    try {
      final response = await _send(register.getWriteRequest(bytes));
      if (response != modbus.ModbusResponseCode.requestSucceed) {
        throw _exceptionForResponse(response);
      }
      return false;
    } on ModbusClientException catch (error) {
      if (error.exceptionCode != ModbusExceptionCode.illegalFunction) {
        rethrow;
      }
      for (var i = 0; i < values.length; i++) {
        await writeHoldingRegister(startAddress + i, values[i]);
      }
      return true;
    }
  }

  Future<void> writeCoil(int address, bool value) async {
    _validateWriteAddress(address);

    final coil = modbus.ModbusCoil(name: 'Coil $address', address: address);
    final response = await _send(coil.getWriteRequest(value));
    if (response != modbus.ModbusResponseCode.requestSucceed) {
      throw _exceptionForResponse(response);
    }
  }

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
    final response = await _send(group.getReadRequest());
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
    final response = await _send(group.getReadRequest());
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

  /// Sends [request] while tagging the traffic log with this device, so the
  /// global library logs (TX/RX frames) are attributed to the right device.
  Future<modbus.ModbusResponseCode> _send(modbus.ModbusRequest request) async {
    TrafficLog.instance.setActiveDevice(device.id);
    try {
      return await _requireTcpClient().send(request);
    } finally {
      TrafficLog.instance.setActiveDevice(null);
    }
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

  void _validateWriteAddress(int address) {
    if (address < 0 || address > 0xffff) {
      throw RangeError.range(address, 0, 0xffff, 'address');
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
