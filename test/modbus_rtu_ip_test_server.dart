import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:omodscan_mobile/utils/modbus_crc.dart';

class ModbusRtuIpTestServer {
  final ServerSocket _server;
  final Map<int, int> holdingRegisters;
  final Map<int, int> inputRegisters;
  final Map<int, bool> coils;
  final Map<int, bool> discreteInputs;
  final Map<int, int> exceptionByFunction;
  final bool illegalMultipleRegisterWrite;

  int acceptedConnections = 0;
  int multipleRegisterWriteAttempts = 0;
  final singleRegisterWrites = <int>[];
  final coilWrites = <int>[];
  final receivedFrames = <Uint8List>[];

  ModbusRtuIpTestServer._(
    this._server, {
    required this.holdingRegisters,
    required this.inputRegisters,
    required this.coils,
    required this.discreteInputs,
    required this.exceptionByFunction,
    required this.illegalMultipleRegisterWrite,
  }) {
    _server.listen(_handleSocket);
  }

  static Future<ModbusRtuIpTestServer> start({
    Map<int, int> holdingRegisters = const {},
    Map<int, int> inputRegisters = const {},
    Map<int, bool> coils = const {},
    Map<int, bool> discreteInputs = const {},
    Map<int, int> exceptionByFunction = const {},
    bool illegalMultipleRegisterWrite = false,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    return ModbusRtuIpTestServer._(
      server,
      holdingRegisters: Map.of(holdingRegisters),
      inputRegisters: Map.of(inputRegisters),
      coils: Map.of(coils),
      discreteInputs: Map.of(discreteInputs),
      exceptionByFunction: Map.of(exceptionByFunction),
      illegalMultipleRegisterWrite: illegalMultipleRegisterWrite,
    );
  }

  String get host => InternetAddress.loopbackIPv4.address;
  int get port => _server.port;

  Future<void> close() => _server.close();

  void _handleSocket(Socket socket) {
    acceptedConnections++;
    final buffer = <int>[];
    socket.listen((data) {
      buffer.addAll(data);
      while (true) {
        final length = _requestLength(buffer);
        if (length == null || buffer.length < length) break;
        final request = Uint8List.fromList(buffer.sublist(0, length));
        buffer.removeRange(0, length);
        receivedFrames.add(request);
        if (!rtuCrcValid(request)) {
          socket.destroy();
          return;
        }
        socket.add(_responseFor(request));
      }
    });
  }

  int? _requestLength(List<int> buffer) {
    if (buffer.length < 2) return null;
    final function = buffer[1];
    if (function == 0x0F || function == 0x10) {
      if (buffer.length < 7) return null;
      return 9 + buffer[6];
    }
    return 8;
  }

  Uint8List _responseFor(List<int> request) {
    final unitId = request[0];
    final pdu = request.sublist(1, request.length - 2);
    final function = pdu.first;
    final configuredException = exceptionByFunction[function];
    if (configuredException != null) {
      return _adu(unitId, [function | 0x80, configuredException]);
    }

    return switch (function) {
      0x01 => _readBits(unitId, function, pdu, coils),
      0x02 => _readBits(unitId, function, pdu, discreteInputs),
      0x03 => _readRegisters(unitId, function, pdu, holdingRegisters),
      0x04 => _readRegisters(unitId, function, pdu, inputRegisters),
      0x05 => _writeCoil(unitId, pdu),
      0x06 => _writeSingleRegister(unitId, pdu),
      0x10 => _writeMultipleRegisters(unitId, pdu),
      _ => _adu(unitId, [function | 0x80, 0x01]),
    };
  }

  Uint8List _readRegisters(
    int unitId,
    int function,
    List<int> pdu,
    Map<int, int> values,
  ) {
    final start = _word(pdu, 1);
    final count = _word(pdu, 3);
    final payload = <int>[function, count * 2];
    for (var offset = 0; offset < count; offset++) {
      final value = values[start + offset] ?? 0;
      payload.addAll([(value >> 8) & 0xff, value & 0xff]);
    }
    return _adu(unitId, payload);
  }

  Uint8List _readBits(
    int unitId,
    int function,
    List<int> pdu,
    Map<int, bool> values,
  ) {
    final start = _word(pdu, 1);
    final count = _word(pdu, 3);
    final byteCount = (count + 7) ~/ 8;
    final payload = <int>[function, byteCount, ...List.filled(byteCount, 0)];
    for (var offset = 0; offset < count; offset++) {
      if (values[start + offset] ?? false) {
        payload[2 + (offset ~/ 8)] |= 1 << (offset % 8);
      }
    }
    return _adu(unitId, payload);
  }

  Uint8List _writeCoil(int unitId, List<int> pdu) {
    final address = _word(pdu, 1);
    coils[address] = _word(pdu, 3) == 0xff00;
    coilWrites.add(address);
    return _adu(unitId, pdu);
  }

  Uint8List _writeSingleRegister(int unitId, List<int> pdu) {
    final address = _word(pdu, 1);
    holdingRegisters[address] = _word(pdu, 3);
    singleRegisterWrites.add(address);
    return _adu(unitId, pdu);
  }

  Uint8List _writeMultipleRegisters(int unitId, List<int> pdu) {
    multipleRegisterWriteAttempts++;
    if (illegalMultipleRegisterWrite) {
      return _adu(unitId, [0x90, 0x01]);
    }
    final start = _word(pdu, 1);
    final count = _word(pdu, 3);
    for (var offset = 0; offset < count; offset++) {
      holdingRegisters[start + offset] = _word(pdu, 6 + offset * 2);
    }
    return _adu(unitId, [
      0x10,
      (start >> 8) & 0xff,
      start & 0xff,
      (count >> 8) & 0xff,
      count & 0xff,
    ]);
  }

  Uint8List _adu(int unitId, List<int> pdu) {
    final frame = <int>[unitId, ...pdu];
    frame.addAll(modbusCrc16(frame));
    return Uint8List.fromList(frame);
  }

  int _word(List<int> bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];
}
