import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/log_entry.dart';
import '../utils/modbus_traffic_format.dart';

/// Persists captured traffic [LogEntry]s to a file. Writing is fire-and-forget
/// so it never blocks the capture path.
abstract interface class TrafficFileWriter {
  void write(String deviceId, LogEntry entry);

  Future<void> close();
}

/// Appends traffic to `modbus-traffic.log` in the app documents directory.
///
/// The output sink is opened lazily on the first write and kept open for the
/// session; each entry is rendered as a single line.
class FileTrafficWriter implements TrafficFileWriter {
  static const fileName = 'modbus-traffic.log';

  IOSink? _sink;
  Future<IOSink>? _opening;

  @override
  void write(String deviceId, LogEntry entry) {
    unawaited(_append(deviceId, entry));
  }

  Future<void> _append(String deviceId, LogEntry entry) async {
    final sink = await (_opening ??= _open());
    sink.writeln(formatTrafficLine(deviceId, entry));
  }

  Future<IOSink> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final sink = File('${dir.path}/$fileName').openWrite(mode: FileMode.append);
    _sink = sink;
    return sink;
  }

  @override
  Future<void> close() async {
    final opening = _opening;
    final sink = _sink ?? (opening == null ? null : await opening);
    _sink = null;
    _opening = null;
    if (sink != null) {
      await sink.flush();
      await sink.close();
    }
  }
}

/// Renders a single traffic entry as one log-file line.
String formatTrafficLine(String deviceId, LogEntry entry) {
  final direction = switch (entry.direction) {
    LogDirection.tx => 'TX',
    LogDirection.rx => 'RX',
    null => '--',
  };
  final data = entry.data.replaceAll('\n', ' | ');
  final frame = entry.frame;
  final detail = (frame != null && entry.direction != null)
      ? trafficDetailText(frame, entry.direction!, frameKind: entry.frameKind)
      : '';
  final suffix = detail.isEmpty ? '' : '  $detail';
  return '${entry.time} [$deviceId] $direction ${entry.function}  $data$suffix';
}
