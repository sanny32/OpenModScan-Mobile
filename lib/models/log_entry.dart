enum LogDirection { tx, rx }

enum LogEntryType { normal, error }

class LogEntry {
  final String time;
  final LogDirection? direction;
  final String function;
  final String data;
  final LogEntryType type;

  const LogEntry({
    required this.time,
    this.direction,
    required this.function,
    required this.data,
    this.type = LogEntryType.normal,
  });
}

const mockLogEntries = [
  LogEntry(
    time: '10:42:31.234',
    direction: LogDirection.tx,
    function: '03 Read Holding Registers',
    data: '00 01 00 00 00 02 C4 0B\nAddr: 40001    Qty: 2',
  ),
  LogEntry(
    time: '10:42:31.254',
    direction: LogDirection.rx,
    function: '03 Read Holding Registers',
    data: '00 01 04 00 7B 00 2D FA 33\nValues: 123, 45',
  ),
  LogEntry(
    time: '10:42:35.678',
    direction: LogDirection.tx,
    function: '03 Read Holding Registers',
    data: '00 01 00 00 00 02 C4 0B\nAddr: 40001    Qty: 2',
  ),
  LogEntry(
    time: '10:42:35.701',
    direction: LogDirection.rx,
    function: '03 Read Holding Registers',
    data: '00 01 04 00 7B 00 2E 39 F3\nValues: 123, 46',
  ),
  LogEntry(
    time: '10:42:40.112',
    direction: LogDirection.tx,
    function: '06 Write Single Register',
    data: '00 01 00 00 00 7B 08 0A\nAddr: 40001    Value: 123',
  ),
  LogEntry(
    time: '10:42:40.134',
    direction: LogDirection.rx,
    function: '06 Write Single Register',
    data: '00 01 00 00 00 7B 08 0A\nAddr: 40001    Value: 123',
  ),
  LogEntry(
    time: '10:42:50.921',
    direction: LogDirection.rx,
    function: 'Exception Response',
    data: '00 01 83 02 C0 F1\nILLEGAL DATA ADDRESS',
    type: LogEntryType.error,
  ),
  LogEntry(
    time: '10:42:55.103',
    direction: LogDirection.tx,
    function: '04 Read Input Registers',
    data: '00 01 00 10 00 02 71 CB\nAddr: 30017    Qty: 2',
  ),
];
