import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../models/device_info.dart';
import '../models/modbus_scan.dart';

abstract interface class ModbusDiscoveryProbe {
  /// Opens a single connection to ([host], [port]) and probes each unit id in
  /// [unitIds] over that connection, returning the unit ids that answered with
  /// a valid Modbus response.
  ///
  /// If the connection cannot be established within [connectTimeout] the
  /// endpoint is considered dead and an empty list is returned after paying for
  /// only one connect attempt — the cost no longer scales with the number of
  /// unit ids.
  ///
  /// For Modbus TCP the requests are pipelined over one connection using the
  /// MBAP transaction id, so a whole unit-id range costs roughly a single
  /// [responseTimeout] even when most of the units are absent. Each individual
  /// read is otherwise bounded by [responseTimeout].
  ///
  /// [isCancelled] is polled so a long range can be aborted promptly when the
  /// surrounding scan is stopped.
  Future<List<int>> probeEndpoint({
    required String host,
    required int port,
    required ProtocolType protocol,
    required Iterable<int> unitIds,
    required ModbusScanRequestType requestType,
    required int requestAddress,
    required Duration connectTimeout,
    required Duration responseTimeout,
    bool Function()? isCancelled,
  });
}

class SocketModbusDiscoveryProbe implements ModbusDiscoveryProbe {
  const SocketModbusDiscoveryProbe();

  @override
  Future<List<int>> probeEndpoint({
    required String host,
    required int port,
    required ProtocolType protocol,
    required Iterable<int> unitIds,
    required ModbusScanRequestType requestType,
    required int requestAddress,
    required Duration connectTimeout,
    required Duration responseTimeout,
    bool Function()? isCancelled,
  }) {
    final pdu = _readRequestPdu(requestType, requestAddress);
    final ids = unitIds.toList(growable: false);
    if (ids.isEmpty) return Future.value(const []);

    return protocol == ProtocolType.modbusTcp
        ? _probeTcpPipelined(
            host: host,
            port: port,
            pdu: pdu,
            ids: ids,
            requestType: requestType,
            connectTimeout: connectTimeout,
            responseTimeout: responseTimeout,
            isCancelled: isCancelled,
          )
        : _probeRtuSequential(
            host: host,
            port: port,
            pdu: pdu,
            ids: ids,
            requestType: requestType,
            connectTimeout: connectTimeout,
            responseTimeout: responseTimeout,
            isCancelled: isCancelled,
          );
  }

  /// TCP path: send a request for every (still-)pending unit id over one
  /// connection, tagging each with `transactionId == unitId`, then drain
  /// responses until every unit answered or the connection goes idle for
  /// [responseTimeout]. Absent unit ids cost one shared idle wait instead of
  /// one timeout each. A serial gateway that closes after a single response is
  /// handled by reconnecting for whatever is still pending.
  Future<List<int>> _probeTcpPipelined({
    required String host,
    required int port,
    required Uint8List pdu,
    required List<int> ids,
    required ModbusScanRequestType requestType,
    required Duration connectTimeout,
    required Duration responseTimeout,
    bool Function()? isCancelled,
  }) async {
    final found = <int>[];
    final pending = ids.toSet();
    var rounds = ids.length;

    while (pending.isNotEmpty && rounds-- > 0) {
      if (isCancelled?.call() ?? false) break;

      final socket = await _connect(host, port, connectTimeout);
      if (socket == null) break;

      final completer = Completer<bool>();
      final buffer = <int>[];
      var gotResponseThisRound = false;
      Timer? idle;
      Timer? cancelPoll;
      late final StreamSubscription<Uint8List> sub;

      void finish(bool closed) {
        if (completer.isCompleted) return;
        idle?.cancel();
        cancelPoll?.cancel();
        completer.complete(closed);
      }

      void bumpIdle() {
        idle?.cancel();
        idle = Timer(responseTimeout, () => finish(false));
      }

      void onData(Uint8List data) {
        buffer.addAll(data);
        while (buffer.length >= 7) {
          final length = (buffer[4] << 8) | buffer[5];
          final total = 6 + length;
          if (buffer.length < total) break;
          final frame = buffer.sublist(0, total);
          buffer.removeRange(0, total);
          final txn = (frame[0] << 8) | frame[1];
          if (pending.contains(txn)) {
            gotResponseThisRound = true;
            pending.remove(txn);
            if (_isValidResponse(
              frame,
              protocol: ProtocolType.modbusTcp,
              unitId: txn,
              requestType: requestType,
              expectedTransactionId: txn,
            )) {
              found.add(txn);
            }
          }
        }
        if (pending.isEmpty) {
          finish(false);
        } else {
          bumpIdle();
        }
      }

      sub = socket.listen(
        onData,
        onError: (_) => finish(true),
        onDone: () => finish(true),
        cancelOnError: false,
      );

      for (final unitId in pending) {
        socket.add(_tcpFrame(unitId, pdu, transactionId: unitId));
      }
      unawaited(socket.flush());
      bumpIdle();
      cancelPoll = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (isCancelled?.call() ?? false) finish(false);
      });

      final closed = await completer.future;
      await sub.cancel();
      socket.destroy();

      if (!(closed && gotResponseThisRound)) break;
    }

    found.sort();
    return found;
  }

  /// RTU path: one connection, strict request/response. A unit that does not
  /// answer within [responseTimeout] is recorded as absent and the loop moves
  /// on over the *same* socket (a timeout is not a socket failure). Only an
  /// actual socket error/close triggers a bounded reconnect-and-retry.
  Future<List<int>> _probeRtuSequential({
    required String host,
    required int port,
    required Uint8List pdu,
    required List<int> ids,
    required ModbusScanRequestType requestType,
    required Duration connectTimeout,
    required Duration responseTimeout,
    bool Function()? isCancelled,
  }) async {
    final found = <int>[];
    _SocketReader? reader;
    var reconnectBudget = ids.length;

    try {
      var i = 0;
      while (i < ids.length) {
        if (isCancelled?.call() ?? false) break;
        final unitId = ids[i];

        if (reader == null) {
          final socket = await _connect(host, port, connectTimeout);
          if (socket == null) break;
          reader = _SocketReader(socket);
        }

        final frame = _rtuFrame(unitId, pdu);
        List<int> response;
        try {
          response = await reader.exchange(
            frame,
            protocol: ProtocolType.modbusRtuIp,
            requestType: requestType,
            timeout: responseTimeout,
          );
        } on TimeoutException {
          i++;
          continue;
        } catch (_) {
          reader.dispose();
          reader = null;
          if (reconnectBudget-- <= 0) break;
          continue;
        }

        if (_isValidResponse(
          response,
          protocol: ProtocolType.modbusRtuIp,
          unitId: unitId,
          requestType: requestType,
        )) {
          found.add(unitId);
        }
        i++;
      }
    } finally {
      reader?.dispose();
    }

    return found;
  }

  Future<Socket?> _connect(
    String host,
    int port,
    Duration connectTimeout,
  ) async {
    try {
      return await Socket.connect(host, port, timeout: connectTimeout);
    } catch (_) {
      return null;
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

  Uint8List _tcpFrame(int unitId, Uint8List pdu, {int transactionId = 1}) {
    final frame = Uint8List(7 + pdu.length);
    ByteData.view(frame.buffer)
      ..setUint16(0, transactionId)
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

  bool _isValidResponse(
    List<int> response, {
    required ProtocolType protocol,
    required int unitId,
    required ModbusScanRequestType requestType,
    int expectedTransactionId = 1,
  }) {
    if (protocol == ProtocolType.modbusTcp) {
      if (response.length < 9) return false;
      final view = ByteData.view(Uint8List.fromList(response).buffer);
      final length = view.getUint16(4);
      final totalLength = 6 + length;
      if (response.length < totalLength ||
          view.getUint16(0) != expectedTransactionId ||
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

/// Wraps a [Socket] with a single long-lived subscription so multiple Modbus
/// RTU requests can be issued over one connection without losing bytes or
/// recreating listeners between unit ids.
class _SocketReader {
  final Socket socket;
  final List<int> _buffer = <int>[];
  late final StreamSubscription<Uint8List> _subscription;

  Completer<List<int>>? _pending;
  ProtocolType _protocol = ProtocolType.modbusTcp;
  ModbusScanRequestType _requestType = ModbusScanRequestType.holdingRegisters;
  bool _closed = false;
  Object? _error;

  _SocketReader(this.socket) {
    _subscription = socket.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  /// Sends [frame] and resolves when a full Modbus response for [requestType]
  /// has arrived, or rejects on timeout / socket failure.
  ///
  /// The pending read is registered and the buffer cleared *before* the frame
  /// is written, and no `await` sits between the two, so a fast device whose
  /// reply lands while [Socket.flush] is still settling is matched against this
  /// read instead of being discarded by a later buffer clear.
  Future<List<int>> exchange(
    List<int> frame, {
    required ProtocolType protocol,
    required ModbusScanRequestType requestType,
    required Duration timeout,
  }) {
    if (_error != null) return Future.error(_error!);
    if (_closed) return Future.error(const SocketException('closed'));

    _buffer.clear();
    _protocol = protocol;
    _requestType = requestType;
    final completer = Completer<List<int>>();
    _pending = completer;

    socket.add(frame);
    unawaited(socket.flush());

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending = null;
        throw TimeoutException('Modbus response');
      },
    );
  }

  void _onData(Uint8List data) {
    _buffer.addAll(data);
    _tryComplete();
  }

  void _tryComplete() {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    if (_hasFullResponse(
      _buffer,
      protocol: _protocol,
      requestType: _requestType,
    )) {
      _pending = null;
      pending.complete(List<int>.of(_buffer));
    }
  }

  void _onError(Object error) {
    _error = error;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.completeError(error);
  }

  void _onDone() {
    _closed = true;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const SocketException('closed'));
    }
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

  void dispose() {
    _subscription.cancel();
    socket.destroy();
  }
}
