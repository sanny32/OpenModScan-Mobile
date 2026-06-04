import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class ModbusTcpTestServer {
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

  ModbusTcpTestServer._(
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

  static Future<ModbusTcpTestServer> start({
    Map<int, int> holdingRegisters = const {},
    Map<int, int> inputRegisters = const {},
    Map<int, bool> coils = const {},
    Map<int, bool> discreteInputs = const {},
    Map<int, int> exceptionByFunction = const {},
    bool illegalMultipleRegisterWrite = false,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    return ModbusTcpTestServer._(
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
      while (buffer.length >= 7) {
        final length = (buffer[4] << 8) | buffer[5];
        final total = 6 + length;
        if (buffer.length < total) break;
        final request = buffer.sublist(0, total);
        buffer.removeRange(0, total);
        final response = _responseFor(request);
        socket.add(response);
      }
    });
  }

  Uint8List _responseFor(List<int> request) {
    final transactionId = (request[0] << 8) | request[1];
    final unitId = request[6];
    final pdu = request.sublist(7);
    final function = pdu.first;
    final configuredException = exceptionByFunction[function];
    if (configuredException != null) {
      return _adu(transactionId, unitId, [function | 0x80, configuredException]);
    }

    return switch (function) {
      0x01 => _readBits(transactionId, unitId, function, pdu, coils),
      0x02 => _readBits(transactionId, unitId, function, pdu, discreteInputs),
      0x03 => _readRegisters(
        transactionId,
        unitId,
        function,
        pdu,
        holdingRegisters,
      ),
      0x04 => _readRegisters(
        transactionId,
        unitId,
        function,
        pdu,
        inputRegisters,
      ),
      0x05 => _writeCoil(transactionId, unitId, pdu),
      0x06 => _writeSingleRegister(transactionId, unitId, pdu),
      0x10 => _writeMultipleRegisters(transactionId, unitId, pdu),
      _ => _adu(transactionId, unitId, [function | 0x80, 0x01]),
    };
  }

  Uint8List _readRegisters(
    int transactionId,
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
    return _adu(transactionId, unitId, payload);
  }

  Uint8List _readBits(
    int transactionId,
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
    return _adu(transactionId, unitId, payload);
  }

  Uint8List _writeCoil(int transactionId, int unitId, List<int> pdu) {
    final address = _word(pdu, 1);
    coils[address] = _word(pdu, 3) == 0xff00;
    coilWrites.add(address);
    return _adu(transactionId, unitId, pdu);
  }

  Uint8List _writeSingleRegister(int transactionId, int unitId, List<int> pdu) {
    final address = _word(pdu, 1);
    holdingRegisters[address] = _word(pdu, 3);
    singleRegisterWrites.add(address);
    return _adu(transactionId, unitId, pdu);
  }

  Uint8List _writeMultipleRegisters(
    int transactionId,
    int unitId,
    List<int> pdu,
  ) {
    multipleRegisterWriteAttempts++;
    if (illegalMultipleRegisterWrite) {
      return _adu(transactionId, unitId, [0x90, 0x01]);
    }
    final start = _word(pdu, 1);
    final count = _word(pdu, 3);
    for (var offset = 0; offset < count; offset++) {
      holdingRegisters[start + offset] = _word(pdu, 6 + offset * 2);
    }
    return _adu(transactionId, unitId, [
      0x10,
      (start >> 8) & 0xff,
      start & 0xff,
      (count >> 8) & 0xff,
      count & 0xff,
    ]);
  }

  Uint8List _adu(int transactionId, int unitId, List<int> pdu) {
    final length = pdu.length + 1;
    return Uint8List.fromList([
      (transactionId >> 8) & 0xff,
      transactionId & 0xff,
      0x00,
      0x00,
      (length >> 8) & 0xff,
      length & 0xff,
      unitId,
      ...pdu,
    ]);
  }

  int _word(List<int> bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];
}
