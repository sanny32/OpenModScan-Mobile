import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:modbus_client/modbus_client.dart' as modbus;

import '../models/app_settings.dart';
import '../models/log_entry.dart';
import '../runtime/runtime_ports.dart';
import '../utils/modbus_traffic_format.dart';
import 'traffic_file_writer.dart';

/// Captures real Modbus traffic by hooking the `modbus_client` library logger
/// and exposes it as a per-device, in-memory ring buffer.
///
/// The library logs full ADU frames at `FINEST` level ("Sent data: ..." for
/// requests, "Incoming data: ..." for responses). Those logs are global, so
/// each frame is attributed to the device whose request is currently in flight
/// ([setActiveDevice]); TX→RX pairs are correlated by the MBAP transaction id.
class TrafficLog extends ChangeNotifier implements TrafficLogSource {
  static final TrafficLog instance = TrafficLog._();
  TrafficLog._();

  /// Builds an isolated instance for tests.
  @visibleForTesting
  TrafficLog.forTesting();

  final Map<String, List<LogEntry>> _byDevice = {};
  final Map<int, String> _txnToDevice = {};
  String? _activeDeviceId;
  bool _installed = false;
  TrafficFileWriter? _fileWriter;

  /// Installs the global logger hook and, by default, file persistence (gated
  /// by [AppSettings.saveLogToFile]). Safe to call more than once.
  void install() {
    if (_installed) return;
    _installed = true;
    _fileWriter ??= FileTrafficWriter();
    modbus.ModbusAppLogger(Level.ALL, onLog);
  }

  /// Overrides the file writer for tests.
  @visibleForTesting
  void attachFileWriter(TrafficFileWriter? writer) => _fileWriter = writer;

  @visibleForTesting
  Future<void> resetForTesting() async {
    _byDevice.clear();
    _txnToDevice.clear();
    _activeDeviceId = null;
    _installed = false;
    final writer = _fileWriter;
    _fileWriter = null;
    await writer?.close();
    notifyListeners();
  }

  /// Marks which device's traffic is currently being exchanged. Cleared (with
  /// `null`) once the operation completes.
  void setActiveDevice(String? deviceId) {
    _activeDeviceId = deviceId;
  }

  void recordFrameForDevice(
    String deviceId, {
    required Uint8List frame,
    required LogDirection direction,
    required LogFrameKind frameKind,
    DateTime? time,
  }) {
    if (frame.isEmpty) return;
    _append(
      deviceId,
      buildTrafficLogEntry(
        frame: frame,
        direction: direction,
        time: time ?? DateTime.now(),
        frameKind: frameKind,
      ),
    );
  }

  @override
  List<LogEntry> entriesFor(String? deviceId) =>
      deviceId == null ? const [] : (_byDevice[deviceId] ?? const []);

  @override
  void clear(String? deviceId) {
    if (deviceId == null) return;
    if (_byDevice.remove(deviceId) != null) {
      notifyListeners();
    }
  }

  /// Handles a single log record from the library. Exposed for testing.
  @visibleForTesting
  void onLog(LogRecord record) {
    final message = record.message;
    if (message.startsWith('Sent data:')) {
      _recordFrame(
        message.substring('Sent data:'.length),
        LogDirection.tx,
        record.time,
      );
    } else if (message.startsWith('Incoming data:')) {
      _recordFrame(
        message.substring('Incoming data:'.length),
        LogDirection.rx,
        record.time,
      );
    } else if (record.level >= Level.WARNING) {
      _recordError(message, record.time);
    }
  }

  void _recordFrame(String hex, LogDirection direction, DateTime time) {
    final frame = _parseHex(hex);
    if (frame.isEmpty) return;

    final transactionId = frame.length >= 2 ? (frame[0] << 8) | frame[1] : null;
    final String? deviceId;
    if (direction == LogDirection.tx) {
      deviceId = _activeDeviceId;
      if (deviceId != null && transactionId != null) {
        _txnToDevice[transactionId] = deviceId;
      }
    } else {
      deviceId =
          (transactionId != null ? _txnToDevice[transactionId] : null) ??
          _activeDeviceId;
    }
    if (deviceId == null) return;

    _append(
      deviceId,
      buildTrafficLogEntry(frame: frame, direction: direction, time: time),
    );
  }

  void _recordError(String message, DateTime time) {
    final deviceId = _activeDeviceId;
    if (deviceId == null) return;
    _append(
      deviceId,
      LogEntry(
        time: formatTrafficTime(time),
        function: 'Error',
        data: message,
        type: LogEntryType.error,
      ),
    );
  }

  void _append(String deviceId, LogEntry entry) {
    final entries = _byDevice.putIfAbsent(deviceId, () => <LogEntry>[]);
    entries.add(entry);
    final max = AppSettings.instance.maxLogEntries;
    if (max > 0 && entries.length > max) {
      entries.removeRange(0, entries.length - max);
    }
    if (AppSettings.instance.saveLogToFile) {
      _fileWriter?.write(deviceId, entry);
    }
    notifyListeners();
  }

  Uint8List _parseHex(String hex) {
    final tokens = hex.trim().split(RegExp(r'\s+'));
    final bytes = <int>[];
    for (final token in tokens) {
      if (token.isEmpty) continue;
      final value = int.tryParse(token, radix: 16);
      if (value == null) return Uint8List(0);
      bytes.add(value);
    }
    return Uint8List.fromList(bytes);
  }
}
