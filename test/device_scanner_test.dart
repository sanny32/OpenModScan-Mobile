import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/modbus_scan.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/services/device_scanner.dart';
import 'package:omodscan_mobile/services/modbus_discovery_probe.dart';
import 'package:omodscan_mobile/services/network_scan_subnet.dart';

void main() {
  test('CIDR hosts are generated from current IPv4 and /24', () {
    final hosts = Ipv4Subnet.fromAddress('192.168.1.42', 24).hosts();

    expect(hosts, hasLength(254));
    expect(hosts.first, '192.168.1.1');
    expect(hosts.last, '192.168.1.254');
  });

  test('scan is unavailable when current subnet is unavailable', () async {
    final probe = _FakeProbe(found: {const _ProbeKey('192.168.1.2', 502, 1)});
    final scanner = DeviceScanner(
      probe: probe,
      networkInterfacesProvider: () async => const [],
    );

    await scanner.startScan(
      const DeviceScanRequest(
        portStart: 502,
        portEnd: 502,
        unitIdStart: 1,
        unitIdEnd: 1,
        concurrency: 1,
      ),
    );

    expect(probe.calls, isEmpty);
    expect(scanner.totalCount, 0);
    expect(scanner.discoveredDevices.devices, isEmpty);
  });

  test('closed ports do not add discovered devices', () async {
    final scanner = DeviceScanner(
      probe: _FakeProbe(),
      scanHostsProvider: (_) async => ['192.168.1.1', '192.168.1.2'],
    );

    await scanner.startScan(
      const DeviceScanRequest(unitIdStart: 1, unitIdEnd: 1, concurrency: 2),
    );

    expect(scanner.discoveredDevices.devices, isEmpty);
    expect(scanner.scannedCount, scanner.totalCount);
    expect(scanner.state, ScannerStateView.done);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(scanner.state, ScannerStateView.idle);
    expect(scanner.scannedCount, 0);
    expect(scanner.totalCount, 0);
  });

  test('successful Modbus TCP probe adds a discovered device', () async {
    final scanner = DeviceScanner(
      probe: _FakeProbe(found: {const _ProbeKey('192.168.1.1', 502, 1)}),
      scanHostsProvider: (_) async => ['192.168.1.1', '192.168.1.2'],
    );

    await scanner.startScan(
      const DeviceScanRequest(
        protocol: ProtocolType.modbusTcp,
        unitIdStart: 1,
        unitIdEnd: 1,
      ),
    );

    final device = scanner.discoveredDevices.devices.single;
    expect(device.host, '192.168.1.1');
    expect(device.port, 502);
    expect(device.unitId, 1);
    expect(device.protocol, ProtocolType.modbusTcp);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(scanner.state, ScannerStateView.done);
  });

  test('unit id range can discover multiple units on one endpoint', () async {
    final scanner = DeviceScanner(
      probe: _FakeProbe(
        found: {
          const _ProbeKey('192.168.1.1', 502, 1),
          const _ProbeKey('192.168.1.1', 502, 2),
        },
      ),
      scanHostsProvider: (_) async => ['192.168.1.1'],
    );

    await scanner.startScan(
      const DeviceScanRequest(unitIdStart: 1, unitIdEnd: 2, concurrency: 1),
    );

    expect(scanner.discoveredDevices.devices.map((d) => d.unitId), [1, 2]);
  });

  test('different protocols are not treated as duplicates', () async {
    final probe = _FakeProbe(found: {const _ProbeKey('192.168.1.1', 502, 1)});
    final scanner = DeviceScanner(
      probe: probe,
      scanHostsProvider: (_) async => ['192.168.1.1'],
    );

    await scanner.startScan(
      const DeviceScanRequest(
        protocol: ProtocolType.modbusTcp,
        unitIdStart: 1,
        unitIdEnd: 1,
      ),
    );
    await scanner.startScan(
      const DeviceScanRequest(
        protocol: ProtocolType.modbusRtuIp,
        unitIdStart: 1,
        unitIdEnd: 1,
      ),
    );

    expect(scanner.discoveredDevices.devices, hasLength(2));
    expect(scanner.discoveredDevices.devices.map((d) => d.protocol).toSet(), {
      ProtocolType.modbusTcp,
      ProtocolType.modbusRtuIp,
    });
  });

  test('stopScan prevents further results from being added', () async {
    final probe = _BlockingProbe();
    final scanner = DeviceScanner(
      probe: probe,
      scanHostsProvider: (_) async => ['192.168.1.1', '192.168.1.2'],
    );

    final scan = scanner.startScan(
      const DeviceScanRequest(unitIdStart: 1, unitIdEnd: 2, concurrency: 1),
    );
    await probe.firstCall.future;
    scanner.stopScan();
    probe.release();
    await scan;

    expect(scanner.state, ScannerStateView.idle);
    expect(scanner.discoveredDevices.devices, isEmpty);
    expect(scanner.scannedCount, 1);
  });
}

class _FakeProbe implements ModbusDiscoveryProbe {
  final Set<_ProbeKey> found;
  final List<_ProbeCall> calls = [];

  _FakeProbe({this.found = const {}});

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
    calls.add(_ProbeCall(host: host, port: port, unitId: unitId));
    return found.contains(_ProbeKey(host, port, unitId));
  }
}

class _BlockingProbe implements ModbusDiscoveryProbe {
  final firstCall = Completer<void>();
  final _release = Completer<void>();

  void release() => _release.complete();

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
    if (!firstCall.isCompleted) firstCall.complete();
    await _release.future;
    return true;
  }
}

class _ProbeCall {
  final String host;
  final int port;
  final int unitId;

  const _ProbeCall({
    required this.host,
    required this.port,
    required this.unitId,
  });
}

class _ProbeKey {
  final String host;
  final int port;
  final int unitId;

  const _ProbeKey(this.host, this.port, this.unitId);

  @override
  bool operator ==(Object other) =>
      other is _ProbeKey &&
      host == other.host &&
      port == other.port &&
      unitId == other.unitId;

  @override
  int get hashCode => Object.hash(host, port, unitId);
}
