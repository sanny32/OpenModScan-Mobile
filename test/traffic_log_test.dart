import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/log_entry.dart';
import 'package:omodscan_mobile/services/traffic_file_writer.dart';
import 'package:omodscan_mobile/services/traffic_log.dart';

class _FakeFileWriter implements TrafficFileWriter {
  final List<(String, LogEntry)> written = [];

  @override
  void write(String deviceId, LogEntry entry) => written.add((deviceId, entry));

  @override
  Future<void> close() async {}
}

LogRecord _record(String message, [Level level = Level.FINEST]) =>
    LogRecord(level, message, 'ModbusAppLogger');

// A read-holding-registers request frame (transaction id 0x0001).
const _txReadReq = 'Sent data: 00 01 00 00 00 06 01 03 00 00 00 02';
// Its response (same transaction id 0x0001).
const _rxReadResp = 'Incoming data: 00 01 00 00 00 07 01 03 04 00 7B 00 2D';

void main() {
  setUp(() {
    AppSettings.instance.maxLogEntries = 1000;
    AppSettings.instance.saveLogToFile = false;
  });

  test('attributes TX frames to the active device', () {
    final log = TrafficLog.forTesting();
    log.setActiveDevice('dev-a');
    log.onLog(_record(_txReadReq));

    final entries = log.entriesFor('dev-a');
    expect(entries, hasLength(1));
    expect(entries.single.direction, LogDirection.tx);
    expect(entries.single.function, '03 Read Holding Registers');
    expect(entries.single.frame, isNotNull);
    expect(entries.single.frame!.first, 0x00); // raw frame retained
    expect(log.entriesFor('dev-b'), isEmpty);
  });

  test('correlates RX to its TX device by transaction id', () {
    final log = TrafficLog.forTesting();
    log.setActiveDevice('dev-a');
    log.onLog(_record(_txReadReq));
    // Active device cleared before the async response arrives.
    log.setActiveDevice(null);
    log.onLog(_record(_rxReadResp));

    final entries = log.entriesFor('dev-a');
    expect(entries, hasLength(2));
    expect(entries[1].direction, LogDirection.rx);
    // Row data is hex-only now; decoded values live in the frame.
    expect(entries[1].data, '00 01 00 00 00 07 01 03 04 00 7B 00 2D');
    expect(entries[1].frame, isNotNull);
  });

  test('drops frames with no attributable device', () {
    final log = TrafficLog.forTesting();
    log.onLog(_record(_rxReadResp)); // no active device, unknown transaction
    expect(log.entriesFor('dev-a'), isEmpty);
  });

  test('records warnings as error entries', () {
    final log = TrafficLog.forTesting();
    log.setActiveDevice('dev-a');
    log.onLog(_record('Connection to host failed!', Level.WARNING));

    final entries = log.entriesFor('dev-a');
    expect(entries, hasLength(1));
    expect(entries.single.type, LogEntryType.error);
    expect(entries.single.data, contains('Connection to host failed!'));
  });

  test('caps the ring buffer at maxLogEntries', () {
    AppSettings.instance.maxLogEntries = 3;
    final log = TrafficLog.forTesting();
    log.setActiveDevice('dev-a');
    for (var i = 0; i < 5; i++) {
      log.onLog(_record(_txReadReq));
    }
    expect(log.entriesFor('dev-a'), hasLength(3));
  });

  test('clear empties the device buffer and notifies listeners', () {
    final log = TrafficLog.forTesting();
    var notifications = 0;
    log.addListener(() => notifications++);

    log.setActiveDevice('dev-a');
    log.onLog(_record(_txReadReq));
    expect(log.entriesFor('dev-a'), hasLength(1));
    expect(notifications, greaterThan(0));

    final before = notifications;
    log.clear('dev-a');
    expect(log.entriesFor('dev-a'), isEmpty);
    expect(notifications, greaterThan(before));
  });

  test('writes to the file writer only when saveLogToFile is enabled', () {
    final writer = _FakeFileWriter();
    final log = TrafficLog.forTesting();
    log.attachFileWriter(writer);
    log.setActiveDevice('dev-a');

    log.onLog(_record(_txReadReq));
    expect(writer.written, isEmpty); // disabled by default

    AppSettings.instance.saveLogToFile = true;
    log.onLog(_record(_txReadReq));
    expect(writer.written, hasLength(1));
    expect(writer.written.single.$1, 'dev-a');
    expect(writer.written.single.$2.direction, LogDirection.tx);
  });

  test('formats a traffic line as a single row (hex-only entry)', () {
    final line = formatTrafficLine(
      'dev-a',
      const LogEntry(
        time: '10:42:31.234',
        direction: LogDirection.tx,
        function: '03 Read Holding Registers',
        data: '00 01 00 00 00 06 01 03 00 00 00 02',
      ),
    );

    expect(line, isNot(contains('\n')));
    expect(line, startsWith('10:42:31.234 [dev-a] TX 03 Read Holding Registers'));
    expect(line, contains('00 01 00 00 00 06 01 03 00 00 00 02'));
  });

  test('appends decoded detail to the file line when frame is present', () {
    final line = formatTrafficLine(
      'dev-a',
      LogEntry(
        time: '10:42:31.234',
        direction: LogDirection.tx,
        function: '03 Read Holding Registers',
        data: '00 01 00 00 00 06 01 03 00 00 00 02',
        frame: Uint8List.fromList(const [
          0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0x01,
          0x03, 0x00, 0x00, 0x00, 0x02,
        ]),
      ),
    );

    expect(line, isNot(contains('\n')));
    expect(line, contains('00 01 00 00 00 06 01 03 00 00 00 02'));
    expect(line, contains('Start address: 0'));
    expect(line, contains('Quantity: 2'));
  });
}
