import 'device_info.dart';
import 'log_entry.dart';
import 'register_entry.dart';

const mockDevice = DeviceInfo(
  name: 'PLC #1',
  host: '192.168.0.10',
  port: 502,
  protocol: ProtocolType.modbusTcp,
  unitId: 1,
);

const mockDevices = [
  mockDevice,
  DeviceInfo(
    name: 'Water Pump Station',
    host: '192.168.0.20',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
  ),
  DeviceInfo(
    name: 'HVAC Controller',
    host: '192.168.0.30',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
  ),
  DeviceInfo(
    name: 'Energy Meter',
    host: '192.168.0.40',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 1,
  ),
  DeviceInfo(
    name: 'Boiler Control',
    host: '10.0.0.15',
    port: 502,
    protocol: ProtocolType.modbusTcp,
    unitId: 2,
  ),
];

const mockRegisters = [
  RegisterEntry(address: 40001, value: '123',   previousValue: '120',   typeName: 'UInt16',  comment: 'Temp °C',  timestamp: '10:42:35', date: '21.05.2024'),
  RegisterEntry(address: 40002, value: '45',    previousValue: '44',    typeName: 'Float32', comment: 'Voltage',  timestamp: '10:42:35', date: '21.05.2024'),
  RegisterEntry(address: 40003, value: '789',                           typeName: 'Float32',                      timestamp: '10:42:35', date: '21.05.2024'),
  RegisterEntry(address: 40004, value: '1',     previousValue: '0',     typeName: 'Bool',    comment: 'Running',  timestamp: '10:42:34', date: '21.05.2024'),
  RegisterEntry(address: 40005, value: '1000',                          typeName: 'UInt32',                       timestamp: '10:42:34', date: '21.05.2024'),
  RegisterEntry(address: 40006, value: '50000', previousValue: '49000', typeName: 'Float32', comment: 'Current',  timestamp: '10:42:33', date: '21.05.2024'),
  RegisterEntry(address: 40007, value: '32767',                         typeName: 'Int16',                        timestamp: '10:42:33', date: '21.05.2024'),
  RegisterEntry(address: 40008, value: '0',     previousValue: '1',     typeName: 'UInt16',  comment: 'Status',   timestamp: '10:42:32', date: '21.05.2024'),
  RegisterEntry(address: 40009, value: '250',   previousValue: '245',   typeName: 'Float32', comment: 'Pressure', timestamp: '10:42:32', date: '21.05.2024'),
  RegisterEntry(address: 40010, value: '65535',                         typeName: 'UInt16',                       timestamp: '10:42:31', date: '21.05.2024'),
];

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
