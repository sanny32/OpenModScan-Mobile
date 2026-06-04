import 'dart:async';
import 'dart:io';

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

    expect(probe.endpointCalls, isEmpty);
    expect(scanner.totalCount, 0);
    expect(scanner.discoveredDevices.devices, isEmpty);
  });

  test('scan prefers Wi-Fi IPv4 over other private interfaces', () async {
    final probe = _FakeProbe();
    final scanner = DeviceScanner(
      probe: probe,
      networkInterfacesProvider: () async => [
        ScanNetworkInterface(
          name: 'pdp_ip0',
          addresses: [InternetAddress('10.240.94.10')],
        ),
        ScanNetworkInterface(
          name: 'en0',
          addresses: [InternetAddress('192.168.88.16')],
        ),
      ],
    );

    await scanner.startScan(
      const DeviceScanRequest(
        subnetPrefix: 30,
        portStart: 502,
        portEnd: 502,
        unitIdStart: 1,
        unitIdEnd: 1,
        concurrency: 1,
      ),
    );

    expect(scanner.scanCidr, '192.168.88.16/30');
    expect(probe.endpointCalls.map((call) => call.host), [
      '192.168.88.17',
      '192.168.88.18',
    ]);
  });

  test('available subnets prefer Wi-Fi and remove duplicates', () async {
    final scanner = DeviceScanner(
      networkInterfacesProvider: () async => [
        ScanNetworkInterface(
          name: 'pdp_ip0',
          addresses: [InternetAddress('10.240.94.10')],
        ),
        ScanNetworkInterface(
          name: 'en0',
          addresses: [InternetAddress('192.168.88.16')],
        ),
        ScanNetworkInterface(
          name: 'en1',
          addresses: [InternetAddress('192.168.88.20')],
        ),
      ],
    );

    expect(await scanner.availableSubnetCidrs(prefix: 24), [
      '192.168.88.0/24',
      '10.240.94.0/24',
    ]);
  });

  test('scan uses configured subnet before current interface', () async {
    final probe = _FakeProbe();
    final scanner = DeviceScanner(
      probe: probe,
      networkInterfacesProvider: () async => [
        ScanNetworkInterface(
          name: 'en0',
          addresses: [InternetAddress('192.168.88.16')],
        ),
      ],
    );

    await scanner.startScan(
      const DeviceScanRequest(
        subnetCidr: '10.0.5.200/30',
        portStart: 502,
        portEnd: 502,
        unitIdStart: 1,
        unitIdEnd: 1,
        concurrency: 1,
      ),
    );

    expect(scanner.scanCidr, '10.0.5.200/30');
    expect(probe.endpointCalls.map((call) => call.host), [
      '10.0.5.201',
      '10.0.5.202',
    ]);
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
    expect(scanner.totalCount, 2);
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

  test('a single endpoint connection probes the whole unit id range', () async {
    final probe = _FakeProbe(found: {const _ProbeKey('192.168.1.1', 502, 5)});
    final scanner = DeviceScanner(
      probe: probe,
      scanHostsProvider: (_) async => ['192.168.1.1'],
    );

    await scanner.startScan(
      const DeviceScanRequest(unitIdStart: 1, unitIdEnd: 10, concurrency: 1),
    );

    expect(probe.endpointCalls, hasLength(1));
    expect(probe.endpointCalls.single.unitIds, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(scanner.discoveredDevices.devices.map((d) => d.unitId), [5]);
    expect(scanner.scannedCount, scanner.totalCount);
  });

  test('unreachable endpoint is probed once for the whole range', () async {
    final probe = _FakeProbe(unreachable: {'192.168.1.9'});
    final scanner = DeviceScanner(
      probe: probe,
      scanHostsProvider: (_) async => ['192.168.1.9'],
    );

    await scanner.startScan(
      const DeviceScanRequest(unitIdStart: 1, unitIdEnd: 50, concurrency: 1),
    );

    expect(probe.endpointCalls, hasLength(1));
    expect(scanner.discoveredDevices.devices, isEmpty);
    expect(scanner.scannedCount, scanner.totalCount);
    expect(scanner.totalCount, 50);
  });

  test(
    'request carries connect timeout and concurrency to the probe',
    () async {
      final probe = _FakeProbe();
      final scanner = DeviceScanner(
        probe: probe,
        scanHostsProvider: (_) async => ['192.168.1.1'],
      );

      await scanner.startScan(
        const DeviceScanRequest(
          unitIdStart: 1,
          unitIdEnd: 1,
          timeout: Duration(milliseconds: 750),
          connectTimeout: Duration(milliseconds: 250),
          concurrency: 4,
        ),
      );

      final call = probe.endpointCalls.single;
      expect(call.connectTimeout, const Duration(milliseconds: 250));
      expect(call.responseTimeout, const Duration(milliseconds: 750));
    },
  );

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
    expect(scanner.scannedCount, 2);
  });

  test('cancellation flag is forwarded to the probe', () async {
    final probe = _CancellationProbe();
    final scanner = DeviceScanner(
      probe: probe,
      scanHostsProvider: (_) async => ['192.168.1.1'],
    );

    final scan = scanner.startScan(
      const DeviceScanRequest(unitIdStart: 1, unitIdEnd: 5, concurrency: 1),
    );
    await probe.started.future;
    expect(probe.isCancelled!(), isFalse);
    scanner.stopScan();
    expect(probe.isCancelled!(), isTrue);
    probe.release();
    await scan;

    expect(scanner.discoveredDevices.devices, isEmpty);
  });
}

class _EndpointCall {
  final String host;
  final int port;
  final List<int> unitIds;
  final Duration connectTimeout;
  final Duration responseTimeout;

  const _EndpointCall({
    required this.host,
    required this.port,
    required this.unitIds,
    required this.connectTimeout,
    required this.responseTimeout,
  });
}

class _FakeProbe implements ModbusDiscoveryProbe {
  final Set<_ProbeKey> found;
  final Set<String> unreachable;
  final List<_EndpointCall> endpointCalls = [];

  _FakeProbe({this.found = const {}, this.unreachable = const {}});

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
  }) async {
    final ids = unitIds.toList();
    endpointCalls.add(
      _EndpointCall(
        host: host,
        port: port,
        unitIds: ids,
        connectTimeout: connectTimeout,
        responseTimeout: responseTimeout,
      ),
    );
    if (unreachable.contains(host)) return const [];
    return [
      for (final unitId in ids)
        if (found.contains(_ProbeKey(host, port, unitId))) unitId,
    ];
  }
}

class _BlockingProbe implements ModbusDiscoveryProbe {
  final firstCall = Completer<void>();
  final _release = Completer<void>();

  void release() => _release.complete();

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
  }) async {
    if (!firstCall.isCompleted) firstCall.complete();
    await _release.future;
    return unitIds.toList();
  }
}

class _CancellationProbe implements ModbusDiscoveryProbe {
  final started = Completer<void>();
  final _release = Completer<void>();
  bool Function()? isCancelled;

  void release() => _release.complete();

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
  }) async {
    this.isCancelled = isCancelled;
    if (!started.isCompleted) started.complete();
    await _release.future;
    return const [];
  }
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
