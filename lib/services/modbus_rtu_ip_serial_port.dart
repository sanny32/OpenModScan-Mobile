import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:modbus_client/modbus_client.dart' as modbus;

import '../models/log_entry.dart';
import 'traffic_log.dart';

class ModbusRtuIpSerialPort implements modbus.ModbusSerialPort {
  final String host;
  final int port;
  final Duration connectTimeout;
  final String deviceId;
  final TrafficLog trafficLog;

  Socket? _socket;
  StreamSubscription<Uint8List>? _subscription;
  final List<int> _rxBuffer = [];
  final List<int> _currentRxFrame = [];
  final List<Completer<void>> _waiters = [];
  bool _closed = true;
  Object? _socketError;

  ModbusRtuIpSerialPort({
    required this.host,
    required this.port,
    required this.connectTimeout,
    required this.deviceId,
    TrafficLog? trafficLog,
  }) : trafficLog = trafficLog ?? TrafficLog.instance;

  @override
  String get name => '$host:$port';

  @override
  bool get isOpen => !_closed && _socket != null;

  @override
  Future<bool> open() async {
    if (isOpen) return true;
    _socketError = null;
    try {
      final socket = await Socket.connect(host, port, timeout: connectTimeout);
      _socket = socket;
      _closed = false;
      _subscription = socket.listen(
        _onData,
        onError: (Object error) {
          _socketError = error;
          _closed = true;
          _wakeWaiters();
        },
        onDone: () {
          _closed = true;
          _wakeWaiters();
        },
        cancelOnError: true,
      );
      return true;
    } catch (error) {
      _socketError = error;
      _closed = true;
      return false;
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    _rxBuffer.clear();
    _currentRxFrame.clear();
    _wakeWaiters();
  }

  @override
  Future<void> flush() async {
    _rxBuffer.clear();
    _currentRxFrame.clear();
  }

  @override
  Future<int> write(Uint8List bytes, {Duration? timeout}) async {
    final socket = _socket;
    if (socket == null || _closed) return 0;
    _currentRxFrame.clear();
    trafficLog.recordFrameForDevice(
      deviceId,
      frame: Uint8List.fromList(bytes),
      direction: LogDirection.tx,
      frameKind: LogFrameKind.modbusRtu,
    );
    socket.add(bytes);
    await socket.flush().timeout(timeout ?? connectTimeout);
    return bytes.length;
  }

  @override
  Future<Uint8List> read(int bytes, {Duration? timeout}) async {
    final deadline = timeout ?? connectTimeout;
    final timer = Stopwatch()..start();

    while (_rxBuffer.length < bytes && !_closed) {
      final remaining = deadline - timer.elapsed;
      if (remaining <= Duration.zero) break;
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future.timeout(remaining, onTimeout: () {});
      _waiters.remove(waiter);
    }

    if (_rxBuffer.isEmpty && _socketError != null) {
      return Uint8List(0);
    }

    final count = _rxBuffer.length < bytes ? _rxBuffer.length : bytes;
    final chunk = _rxBuffer.sublist(0, count);
    _rxBuffer.removeRange(0, count);
    _currentRxFrame.addAll(chunk);
    _recordCompleteRxFrameIfReady();
    return Uint8List.fromList(chunk);
  }

  void _onData(Uint8List data) {
    _rxBuffer.addAll(data);
    _wakeWaiters();
  }

  void _wakeWaiters() {
    for (final waiter in List.of(_waiters)) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  void _recordCompleteRxFrameIfReady() {
    final expected = _expectedRtuResponseLength(_currentRxFrame);
    if (expected == null || _currentRxFrame.length < expected) return;
    trafficLog.recordFrameForDevice(
      deviceId,
      frame: Uint8List.fromList(_currentRxFrame.take(expected).toList()),
      direction: LogDirection.rx,
      frameKind: LogFrameKind.modbusRtu,
    );
    _currentRxFrame.clear();
  }
}

int? _expectedRtuResponseLength(List<int> frame) {
  if (frame.length < 3) return null;
  final function = frame[1];
  if ((function & 0x80) != 0) return 5;
  return switch (function) {
    0x01 || 0x02 || 0x03 || 0x04 => 3 + frame[2] + 2,
    0x05 || 0x06 || 0x0F || 0x10 => 8,
    _ => null,
  };
}
