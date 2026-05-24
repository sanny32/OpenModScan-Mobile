import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/device_info.dart';
import '../runtime/runtime_ports.dart';
import 'discovered_device_list.dart';
import 'modbus_discovery_probe.dart';
import 'network_scan_subnet.dart';

typedef NetworkInterfacesProvider = Future<List<NetworkInterface>> Function();
typedef ScanHostsProvider =
    Future<List<String>> Function(DeviceScanRequest request);

class DeviceScanner extends ChangeNotifier implements DeviceScannerPort {
  static final DeviceScanner instance = DeviceScanner();

  final ModbusDiscoveryProbe probe;
  final NetworkInterfacesProvider _networkInterfacesProvider;
  final ScanHostsProvider? scanHostsProvider;

  DeviceScanner({
    this.probe = const SocketModbusDiscoveryProbe(),
    NetworkInterfacesProvider? networkInterfacesProvider,
    this.scanHostsProvider,
  }) : _networkInterfacesProvider =
           networkInterfacesProvider ??
           (() => NetworkInterface.list(
             type: InternetAddressType.IPv4,
             includeLoopback: false,
           )) {
    discoveredDevices.addListener(notifyListeners);
  }

  @override
  final DiscoveredDeviceList discoveredDevices = DiscoveredDeviceList();

  ScannerStateView _state = ScannerStateView.idle;
  int _scanned = 0;
  int _total = 0;
  String? _scanCidr;
  DateTime? _scanStartedAt;
  ProtocolType? _scanProtocol;
  bool _cancelled = false;

  @override
  ScannerStateView get state => _state;

  @override
  int get scannedCount => _scanned;

  @override
  int get totalCount => _total;

  @override
  double get progress => _total == 0 ? 0.0 : _scanned / _total;

  @override
  String? get scanCidr => _scanCidr;

  @override
  DateTime? get scanStartedAt => _scanStartedAt;

  @override
  ProtocolType? get scanProtocol => _scanProtocol;

  @override
  Future<void> startScan(DeviceScanRequest request) async {
    if (_state == ScannerStateView.scanning) return;

    _cancelled = false;
    _scanned = 0;
    _total = 0;
    _scanCidr = null;
    _scanStartedAt = DateTime.now();
    _scanProtocol = request.protocol;
    _state = ScannerStateView.scanning;
    notifyListeners();

    final hosts = await _hostsFor(request);
    final ports = request.ports.toList(growable: false);
    final unitIds = request.unitIds.toList(growable: false);
    _total = hosts.length * ports.length * unitIds.length;
    notifyListeners();

    var next = 0;
    final jobs = [
      for (final host in hosts)
        for (final port in ports)
          for (final unitId in unitIds)
            _ScanJob(host: host, port: port, unitId: unitId),
    ];

    Future<void> worker() async {
      while (!_cancelled) {
        final index = next++;
        if (index >= jobs.length) return;
        final job = jobs[index];
        final found = await probe
            .probe(
              host: job.host,
              port: job.port,
              protocol: request.protocol,
              unitId: job.unitId,
              requestType: request.requestType,
              requestAddress: request.requestAddress,
              timeout: request.timeout,
            )
            .catchError((_) => false);

        if (!_cancelled && found) {
          discoveredDevices.add(
            request.discoveredDevice(job.host, job.port, job.unitId),
          );
        }
        _scanned++;
        notifyListeners();
      }
    }

    final workerCount = jobs.isEmpty
        ? 0
        : request.concurrency.clamp(1, jobs.length).toInt();
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);

    _state = _cancelled ? ScannerStateView.idle : ScannerStateView.done;
    notifyListeners();
  }

  @override
  void stopScan() {
    if (_state != ScannerStateView.scanning) return;
    _cancelled = true;
  }

  Future<List<String>> _hostsFor(DeviceScanRequest request) async {
    final customHosts = scanHostsProvider;
    if (customHosts != null) {
      return customHosts(request);
    }
    final currentAddress = await _currentIpv4Address().catchError((_) => null);
    if (currentAddress == null) return const [];
    final subnet = Ipv4Subnet.fromAddress(currentAddress, request.subnetPrefix);
    _scanCidr = subnet.cidr;
    return subnet.hosts();
  }

  Future<String?> _currentIpv4Address() async {
    final interfaces = await _networkInterfacesProvider();
    final addresses = [
      for (final interface in interfaces)
        for (final address in interface.addresses)
          if (isUsableIpv4(address)) address.address,
    ];
    if (addresses.isEmpty) return null;
    return addresses.firstWhere(isPrivateIpv4, orElse: () => addresses.first);
  }
}

class _ScanJob {
  final String host;
  final int port;
  final int unitId;

  const _ScanJob({
    required this.host,
    required this.port,
    required this.unitId,
  });
}
