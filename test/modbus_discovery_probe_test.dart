import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/modbus_scan.dart';
import 'package:omodscan_mobile/services/modbus_discovery_probe.dart';

void main() {
  const probe = SocketModbusDiscoveryProbe();

  test('one connection probes the whole unit id range', () async {
    final server = await _ModbusTestServer.start();
    addTearDown(server.close);

    final found = await probe.probeEndpoint(
      host: server.host,
      port: server.port,
      protocol: ProtocolType.modbusTcp,
      unitIds: const [1, 2, 3],
      requestType: ModbusScanRequestType.holdingRegisters,
      requestAddress: 0,
      connectTimeout: const Duration(seconds: 1),
      responseTimeout: const Duration(seconds: 1),
    );

    expect(found, [1, 2, 3]);
    expect(server.acceptedConnections, 1);
  });

  test('unreachable port returns empty quickly without per-unit waits', () async {
    // Bind then immediately release the port so nothing is listening on it.
    final probeSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = probeSocket.port;
    await probeSocket.close();

    final stopwatch = Stopwatch()..start();
    final found = await probe.probeEndpoint(
      host: InternetAddress.loopbackIPv4.address,
      port: deadPort,
      protocol: ProtocolType.modbusTcp,
      unitIds: const [1, 2, 3, 4, 5],
      requestType: ModbusScanRequestType.holdingRegisters,
      requestAddress: 0,
      connectTimeout: const Duration(milliseconds: 300),
      responseTimeout: const Duration(seconds: 5),
    );
    stopwatch.stop();

    expect(found, isEmpty);
    // A single connect attempt, not connectTimeout * unitIds, and never the
    // long responseTimeout.
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('reconnects to finish the range when peer closes after each response',
      () async {
    final server = await _ModbusTestServer.start(closeAfterEachResponse: true);
    addTearDown(server.close);

    final found = await probe.probeEndpoint(
      host: server.host,
      port: server.port,
      protocol: ProtocolType.modbusTcp,
      unitIds: const [1, 2, 3],
      requestType: ModbusScanRequestType.holdingRegisters,
      requestAddress: 0,
      connectTimeout: const Duration(seconds: 1),
      responseTimeout: const Duration(seconds: 1),
    );

    expect(found, [1, 2, 3]);
    expect(server.acceptedConnections, greaterThan(1));
  });

  test('absent unit ids share one idle wait instead of one timeout each',
      () async {
    // Server only answers units 2 and 5 out of a 1..8 scan.
    final server = await _ModbusTestServer.start(respondOnlyTo: {2, 5});
    addTearDown(server.close);

    const responseTimeout = Duration(milliseconds: 400);
    final stopwatch = Stopwatch()..start();
    final found = await probe.probeEndpoint(
      host: server.host,
      port: server.port,
      protocol: ProtocolType.modbusTcp,
      unitIds: const [1, 2, 3, 4, 5, 6, 7, 8],
      requestType: ModbusScanRequestType.holdingRegisters,
      requestAddress: 0,
      connectTimeout: const Duration(seconds: 1),
      responseTimeout: responseTimeout,
    );
    stopwatch.stop();

    expect(found, [2, 5]);
    expect(server.acceptedConnections, 1);
    // Six absent units must not cost 6 * responseTimeout; the pipelined drain
    // waits out a single shared idle window.
    expect(stopwatch.elapsed, lessThan(responseTimeout * 3));
  });

  test('reassembles a response delivered in multiple chunks', () async {
    final server = await _ModbusTestServer.start(splitResponse: true);
    addTearDown(server.close);

    final found = await probe.probeEndpoint(
      host: server.host,
      port: server.port,
      protocol: ProtocolType.modbusTcp,
      unitIds: const [1],
      requestType: ModbusScanRequestType.holdingRegisters,
      requestAddress: 0,
      connectTimeout: const Duration(seconds: 1),
      responseTimeout: const Duration(seconds: 1),
    );

    expect(found, [1]);
  });

  test('invalid/foreign responses are not counted as found', () async {
    final server = await _ModbusTestServer.start(replyWithGarbage: true);
    addTearDown(server.close);

    final found = await probe.probeEndpoint(
      host: server.host,
      port: server.port,
      protocol: ProtocolType.modbusTcp,
      unitIds: const [1, 2],
      requestType: ModbusScanRequestType.holdingRegisters,
      requestAddress: 0,
      connectTimeout: const Duration(seconds: 1),
      responseTimeout: const Duration(milliseconds: 300),
    );

    expect(found, isEmpty);
  });
}

/// Minimal in-process Modbus TCP server for probe tests. Parses the MBAP unit
/// id from each request and echoes a valid holding-register response for it.
class _ModbusTestServer {
  final ServerSocket _server;
  final bool closeAfterEachResponse;
  final bool replyWithGarbage;
  final bool splitResponse;
  final Set<int>? respondOnlyTo;
  int acceptedConnections = 0;

  _ModbusTestServer(
    this._server, {
    required this.closeAfterEachResponse,
    required this.replyWithGarbage,
    required this.splitResponse,
    required this.respondOnlyTo,
  }) {
    _server.listen(_handle);
  }

  static Future<_ModbusTestServer> start({
    bool closeAfterEachResponse = false,
    bool replyWithGarbage = false,
    bool splitResponse = false,
    Set<int>? respondOnlyTo,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    return _ModbusTestServer(
      server,
      closeAfterEachResponse: closeAfterEachResponse,
      replyWithGarbage: replyWithGarbage,
      splitResponse: splitResponse,
      respondOnlyTo: respondOnlyTo,
    );
  }

  String get host => InternetAddress.loopbackIPv4.address;
  int get port => _server.port;

  void _handle(Socket socket) {
    acceptedConnections++;
    final buffer = <int>[];
    socket.listen((data) {
      buffer.addAll(data);
      // Parse every complete MBAP request frame the buffer holds, echoing the
      // request's transaction id so pipelined responses can be routed.
      while (buffer.length >= 7) {
        final length = (buffer[4] << 8) | buffer[5];
        final total = 6 + length;
        if (buffer.length < total) break;
        final request = buffer.sublist(0, total);
        buffer.removeRange(0, total);
        final txn = (request[0] << 8) | request[1];
        final unitId = request[6];

        // Emulate a device that hosts only a subset of unit ids: stay silent
        // for the rest so the probe must time out on them.
        if (respondOnlyTo != null && !respondOnlyTo!.contains(unitId)) {
          continue;
        }

        if (replyWithGarbage) {
          socket.add(Uint8List.fromList([0, 0, 0, 0, 0, 1, 0xff]));
        } else if (splitResponse) {
          // Deliver the MBAP header and the PDU in separate writes so the probe
          // must reassemble them across two data events.
          final full = _validResponse(txn, unitId);
          socket.add(full.sublist(0, 7));
          socket.flush().then((_) {
            Future<void>.delayed(const Duration(milliseconds: 20), () {
              socket.add(full.sublist(7));
            });
          });
        } else {
          socket.add(_validResponse(txn, unitId));
        }

        if (closeAfterEachResponse) {
          // Answer only the first request on this connection, then drop it.
          socket.flush().then((_) => socket.destroy());
          return;
        }
      }
    });
  }

  /// MBAP (echoed txn, proto=0, len=5, unit) + PDU (fc=3, byteCount=2, value=0).
  Uint8List _validResponse(int txn, int unitId) {
    return Uint8List.fromList([
      (txn >> 8) & 0xff, txn & 0xff, // transaction id
      0x00, 0x00, // protocol id
      0x00, 0x05, // length: unit id + 4-byte pdu
      unitId,
      0x03, // function code: read holding registers
      0x02, // byte count
      0x00, 0x00, // register value
    ]);
  }

  Future<void> close() => _server.close();
}
