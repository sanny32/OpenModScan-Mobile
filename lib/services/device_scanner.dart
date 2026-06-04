import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/device_info.dart';
import '../runtime/runtime_ports.dart';
import 'discovered_device_list.dart';
import 'modbus_discovery_probe.dart';
import 'network_scan_subnet.dart';

typedef NetworkInterfacesProvider =
    Future<List<ScanNetworkInterface>> Function();
typedef ScanHostsProvider =
    Future<List<String>> Function(DeviceScanRequest request);

class ScanNetworkInterface {
  final String name;
  final List<InternetAddress> addresses;

  const ScanNetworkInterface({required this.name, required this.addresses});
}

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
           (() async {
             final interfaces = await NetworkInterface.list(
               type: InternetAddressType.IPv4,
               includeLoopback: false,
             );
             return [
               for (final interface in interfaces)
                 ScanNetworkInterface(
                   name: interface.name,
                   addresses: interface.addresses,
                 ),
             ];
           }) {
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
  int _scanGeneration = 0;
  DateTime? _lastProgressNotify;

  /// Minimum gap between progress-only UI notifications. Without this a /24
  /// scan fires thousands of rebuilds that starve the event loop driving the
  /// sockets. Device discoveries and state changes still notify immediately.
  static const _progressNotifyInterval = Duration(milliseconds: 100);

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

  Future<List<String>> availableSubnetCidrs({required int prefix}) async {
    final interfaces = await _networkInterfacesProvider().catchError(
      (_) => const <ScanNetworkInterface>[],
    );
    final privateCandidates = _interfaceIpv4Candidates(interfaces)
        .where((candidate) => isPrivateIpv4(candidate.address.address))
        .toList(growable: false);
    privateCandidates.sort((a, b) {
      final aWifi = _isWifiInterface(a.interfaceName);
      final bWifi = _isWifiInterface(b.interfaceName);
      if (aWifi == bWifi) return 0;
      return aWifi ? -1 : 1;
    });

    final cidrs = <String>{};
    for (final candidate in privateCandidates) {
      cidrs.add(Ipv4Subnet.fromAddress(candidate.address.address, prefix).cidr);
    }
    return cidrs.toList(growable: false);
  }

  @override
  Future<void> startScan(DeviceScanRequest request) async {
    if (_state == ScannerStateView.scanning) return;

    final generation = ++_scanGeneration;
    _cancelled = false;
    _lastProgressNotify = null;
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
        for (final port in ports) _ScanJob(host: host, port: port),
    ];

    Future<void> worker() async {
      while (!_cancelled) {
        final index = next++;
        if (index >= jobs.length) return;
        final job = jobs[index];
        final found = await probe
            .probeEndpoint(
              host: job.host,
              port: job.port,
              protocol: request.protocol,
              unitIds: unitIds,
              requestType: request.requestType,
              requestAddress: request.requestAddress,
              connectTimeout: request.connectTimeout,
              responseTimeout: request.timeout,
              isCancelled: () => _cancelled || generation != _scanGeneration,
            )
            .catchError((_) => const <int>[]);

        if (generation != _scanGeneration) return;
        if (!_cancelled) {
          for (final unitId in found) {
            discoveredDevices.add(
              request.discoveredDevice(job.host, job.port, unitId),
            );
          }
        }
        _scanned += unitIds.length;
        _notifyThrottled();
      }
    }

    final workerCount = jobs.isEmpty
        ? 0
        : request.concurrency.clamp(1, jobs.length).toInt();
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);

    if (generation != _scanGeneration) return;
    _state = _cancelled ? ScannerStateView.idle : ScannerStateView.done;
    notifyListeners();
  }

  @override
  void stopScan() {
    if (_state != ScannerStateView.scanning) return;
    _cancelled = true;
    _state = ScannerStateView.idle;
    notifyListeners();
  }

  @override
  void clearResults() {
    _scanGeneration++;
    _cancelled = true;
    _scanned = 0;
    _total = 0;
    _scanCidr = null;
    _scanStartedAt = null;
    _scanProtocol = null;
    _state = ScannerStateView.idle;
    discoveredDevices.clear();
    notifyListeners();
  }

  /// Emits a progress notification at most once per [_progressNotifyInterval].
  void _notifyThrottled() {
    final now = DateTime.now();
    final last = _lastProgressNotify;
    if (last != null && now.difference(last) < _progressNotifyInterval) {
      return;
    }
    _lastProgressNotify = now;
    notifyListeners();
  }

  Future<List<String>> _hostsFor(DeviceScanRequest request) async {
    final customHosts = scanHostsProvider;
    if (customHosts != null) {
      return customHosts(request);
    }
    final customSubnet = request.subnetCidr == null
        ? null
        : Ipv4Subnet.tryParse(request.subnetCidr!);
    if (customSubnet != null) {
      _scanCidr = customSubnet.cidr;
      return customSubnet.hosts();
    }
    final currentAddress = await _currentIpv4Address().catchError((_) => null);
    if (currentAddress == null) return const [];
    final subnet = Ipv4Subnet.fromAddress(currentAddress, request.subnetPrefix);
    _scanCidr = subnet.cidr;
    return subnet.hosts();
  }

  Future<String?> _currentIpv4Address() async {
    final interfaces = await _networkInterfacesProvider();
    final candidates = _interfaceIpv4Candidates(interfaces);
    if (candidates.isEmpty) return null;

    final privateCandidates = candidates
        .where((candidate) => isPrivateIpv4(candidate.address.address))
        .toList(growable: false);

    for (final candidate in privateCandidates) {
      if (_isWifiInterface(candidate.interfaceName)) {
        return candidate.address.address;
      }
    }

    if (privateCandidates.isNotEmpty) {
      return privateCandidates.first.address.address;
    }

    return candidates.first.address.address;
  }
}

List<_InterfaceIpv4> _interfaceIpv4Candidates(
  List<ScanNetworkInterface> interfaces,
) {
  return [
    for (final interface in interfaces)
      for (final address in interface.addresses)
        if (isUsableIpv4(address))
          _InterfaceIpv4(interfaceName: interface.name, address: address),
  ];
}

class _ScanJob {
  final String host;
  final int port;

  const _ScanJob({required this.host, required this.port});
}

class _InterfaceIpv4 {
  final String interfaceName;
  final InternetAddress address;

  const _InterfaceIpv4({required this.interfaceName, required this.address});
}

bool _isWifiInterface(String name) {
  final normalized = name.toLowerCase();
  return normalized == 'en0' ||
      normalized.startsWith('wlan') ||
      normalized.startsWith('wifi') ||
      normalized.contains('wi-fi');
}
