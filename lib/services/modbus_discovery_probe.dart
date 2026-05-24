import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../models/device_info.dart';
import '../models/modbus_scan.dart';

abstract interface class ModbusDiscoveryProbe {
  Future<bool> probe({
    required String host,
    required int port,
    required ProtocolType protocol,
    required int unitId,
    required ModbusScanRequestType requestType,
    required int requestAddress,
    required Duration timeout,
  });
}

class SocketModbusDiscoveryProbe implements ModbusDiscoveryProbe {
  const SocketModbusDiscoveryProbe();

  @override
  Future<bool> probe({
    required String host,
    required int port,
    required ProtocolType protocol,
    required int unitId,
    required ModbusScanRequestType requestType,
    required int requestAddress,
    required Duration timeout,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      final pdu = _readRequestPdu(requestType, requestAddress);
      final frame = protocol == ProtocolType.modbusTcp
          ? _tcpFrame(unitId, pdu)
          : _rtuFrame(unitId, pdu);
      socket.add(frame);
      await socket.flush();
      final response = await _readResponse(
        socket,
        protocol: protocol,
        unitId: unitId,
        requestType: requestType,
        timeout: timeout,
      );
      return _isValidResponse(
        response,
        protocol: protocol,
        unitId: unitId,
        requestType: requestType,
      );
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  Uint8List _readRequestPdu(ModbusScanRequestType requestType, int address) {
    final data = Uint8List(5);
    ByteData.view(data.buffer)
      ..setUint8(0, requestType.functionCode)
      ..setUint16(1, address)
      ..setUint16(3, 1);
    return data;
  }

  Uint8List _tcpFrame(int unitId, Uint8List pdu) {
    final frame = Uint8List(7 + pdu.length);
    ByteData.view(frame.buffer)
      ..setUint16(0, 1)
      ..setUint16(2, 0)
      ..setUint16(4, pdu.length + 1)
      ..setUint8(6, unitId);
    frame.setAll(7, pdu);
    return frame;
  }

  Uint8List _rtuFrame(int unitId, Uint8List pdu) {
    final frame = Uint8List(1 + pdu.length + 2);
    frame[0] = unitId;
    frame.setAll(1, pdu);
    final crc = _crc16(frame.sublist(0, frame.length - 2));
    frame[frame.length - 2] = crc[0];
    frame[frame.length - 1] = crc[1];
    return frame;
  }

  Future<List<int>> _readResponse(
    Socket socket, {
    required ProtocolType protocol,
    required int unitId,
    required ModbusScanRequestType requestType,
    required Duration timeout,
  }) {
    final completer = Completer<List<int>>();
    final buffer = <int>[];
    late final StreamSubscription<Uint8List> subscription;
    Timer? timer;

    void complete(List<int> value) {
      if (completer.isCompleted) return;
      timer?.cancel();
      subscription.cancel();
      completer.complete(value);
    }

    void fail(Object error) {
      if (completer.isCompleted) return;
      timer?.cancel();
      subscription.cancel();
      completer.completeError(error);
    }

    subscription = socket.listen(
      (data) {
        buffer.addAll(data);
        if (_hasFullResponse(
          buffer,
          protocol: protocol,
          requestType: requestType,
        )) {
          complete(List<int>.of(buffer));
        }
      },
      onError: fail,
      onDone: () {
        if (!completer.isCompleted) fail(const SocketException('closed'));
      },
      cancelOnError: true,
    );
    timer = Timer(timeout, () => fail(TimeoutException('Modbus response')));
    return completer.future;
  }

  bool _hasFullResponse(
    List<int> buffer, {
    required ProtocolType protocol,
    required ModbusScanRequestType requestType,
  }) {
    final dataBytes = requestType.isBitRead ? 1 : 2;
    if (protocol == ProtocolType.modbusTcp) {
      if (buffer.length < 7) return false;
      final length = ByteData.view(
        Uint8List.fromList(buffer).buffer,
      ).getUint16(4);
      return buffer.length >= 6 + length;
    }
    if (buffer.length < 2) return false;
    final code = buffer[1];
    final expected = code == requestType.functionCode + 0x80
        ? 5
        : 5 + dataBytes;
    return buffer.length >= expected;
  }

  bool _isValidResponse(
    List<int> response, {
    required ProtocolType protocol,
    required int unitId,
    required ModbusScanRequestType requestType,
  }) {
    if (protocol == ProtocolType.modbusTcp) {
      if (response.length < 9) return false;
      final view = ByteData.view(Uint8List.fromList(response).buffer);
      final length = view.getUint16(4);
      final totalLength = 6 + length;
      if (response.length < totalLength ||
          view.getUint16(0) != 1 ||
          view.getUint16(2) != 0 ||
          response[6] != unitId) {
        return false;
      }
      return _isValidPdu(response.sublist(7, totalLength), requestType);
    }

    if (response.length < 5 || response[0] != unitId) return false;
    final code = response[1];
    final expectedLength = code == requestType.functionCode + 0x80
        ? 5
        : 5 + (requestType.isBitRead ? 1 : 2);
    if (response.length < expectedLength) return false;
    final frame = response.sublist(0, expectedLength);
    final crc = _crc16(frame.sublist(0, frame.length - 2));
    if (crc[0] != frame[frame.length - 2] ||
        crc[1] != frame[frame.length - 1]) {
      return false;
    }
    return _isValidPdu(frame.sublist(1, frame.length - 2), requestType);
  }

  bool _isValidPdu(List<int> pdu, ModbusScanRequestType requestType) {
    if (pdu.length < 2) return false;
    final code = pdu[0];
    if (code == requestType.functionCode + 0x80) return true;
    if (code != requestType.functionCode) return false;
    final expectedBytes = requestType.isBitRead ? 1 : 2;
    return pdu[1] == expectedBytes && pdu.length >= 2 + expectedBytes;
  }

  Uint8List _crc16(Iterable<int> bytes) {
    var crc = 0xffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        final lsb = crc & 1;
        crc >>= 1;
        if (lsb != 0) crc ^= 0xa001;
      }
    }
    return Uint8List.fromList([crc & 0xff, (crc >> 8) & 0xff]);
  }
}
