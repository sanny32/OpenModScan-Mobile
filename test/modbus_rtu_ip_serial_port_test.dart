import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/services/modbus_rtu_ip_serial_port.dart';

void main() {
  test('opens, writes exact bytes, reads split chunks, and closes', () async {
    final received = <int>[];
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final accepted = Completer<Socket>();
    server.listen((socket) {
      accepted.complete(socket);
      socket.listen(received.addAll);
    });

    final port = ModbusRtuIpSerialPort(
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      connectTimeout: const Duration(milliseconds: 200),
      deviceId: 'dev-a',
    );
    addTearDown(port.close);

    expect(await port.open(), isTrue);
    expect(port.isOpen, isTrue);
    final socket = await accepted.future;

    final written = await port.write(Uint8List.fromList([1, 2, 3]));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(written, 3);
    expect(received, [1, 2, 3]);

    socket.add([4]);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    socket.add([5, 6]);

    expect(await port.read(3, timeout: const Duration(milliseconds: 200)), [
      4,
      5,
      6,
    ]);

    await port.close();
    expect(port.isOpen, isFalse);
  });

  test('read times out with available partial data', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final accepted = Completer<Socket>();
    server.listen((socket) => accepted.complete(socket));

    final port = ModbusRtuIpSerialPort(
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      connectTimeout: const Duration(milliseconds: 200),
      deviceId: 'dev-a',
    );
    addTearDown(port.close);

    expect(await port.open(), isTrue);
    final socket = await accepted.future;
    socket.add([9]);

    expect(await port.read(2, timeout: const Duration(milliseconds: 30)), [9]);
  });
}
