import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/features/devices/devices_controller.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/services/discovered_device_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  late DeviceInfo device;
  late FakeDeviceRepository repository;
  late _WriteConnectionRuntime connections;
  late DevicesController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.resetToDefaults();
    device = DeviceInfo(
      id: 'device-1',
      name: 'PLC',
      host: '127.0.0.1',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
    );
    repository = FakeDeviceRepository([device]);
    connections = _WriteConnectionRuntime();
    controller = DevicesController(
      repository,
      connections,
      _IdleScanner(),
      AppSettings.instance,
    );
    await connections.connect(device);
  });

  tearDown(() => controller.dispose());

  test(
    'typed register write encodes words and reads back formatted value',
    () async {
      await AppSettings.instance.setAddressBase(AppSettings.addressBases[1]);
      connections.holdingReadBack = [1, 2];

      final result = await controller.writeRegisterValue(
        device,
        address: 40001,
        typeName: 'UInt32',
        value: '65538',
        registerOrder: 'MSRF',
        byteOrder: 'Direct',
      );

      expect(connections.lastWriteHoldingStartAddress, 0);
      expect(connections.lastWriteHoldingValues, [1, 2]);
      expect(connections.lastHoldingReadStartAddress, 0);
      expect(connections.lastHoldingReadCount, 2);
      expect(result.displayValue, '65538');
      expect(result.usedFallback, isFalse);
    },
  );

  test('typed register write reports FC06 fallback', () async {
    connections.writeHoldingRegistersFallback = true;
    connections.holdingReadBack = [0x3fc0, 0];

    final result = await controller.writeRegisterValue(
      device,
      address: 40001,
      typeName: 'Float32',
      value: '1.5',
      registerOrder: 'MSRF',
      byteOrder: 'Direct',
    );

    expect(result.usedFallback, isTrue);
    expect(result.displayValue, '1.5');
  });

  test(
    'typed register write keeps written value when read-back fails',
    () async {
      connections.throwOnHoldingRead = true;

      final result = await controller.writeRegisterValue(
        device,
        address: 40001,
        typeName: 'Int16',
        value: '-1',
        registerOrder: 'MSRF',
        byteOrder: 'Direct',
      );

      expect(result.readBackWords, [0xffff]);
      expect(result.displayValue, '-1');
    },
  );

  test('coil write uses configured address base and read-back value', () async {
    await AppSettings.instance.setAddressBase(AppSettings.addressBases[1]);
    connections.coilReadBack = [false];

    final result = await controller.writeCoilValue(
      device,
      address: 1,
      value: true,
    );

    expect(connections.lastWriteCoilAddress, 0);
    expect(connections.lastWriteCoilValue, isTrue);
    expect(connections.lastCoilReadStartAddress, 0);
    expect(result.value, isFalse);
  });

  test('write disabled prevents register write', () async {
    await AppSettings.instance.setWriteEnabled(false);

    expect(
      () => controller.writeRegisterValue(
        device,
        address: 40001,
        typeName: 'UInt16',
        value: '1',
        registerOrder: 'MSRF',
        byteOrder: 'Direct',
      ),
      throwsStateError,
    );
  });
}

class _WriteConnectionRuntime extends PollingConnectionRuntime {
  List<int> holdingReadBack = const [0];
  List<bool> coilReadBack = const [true];
  bool throwOnHoldingRead = false;
  int? lastHoldingReadStartAddress;
  int? lastHoldingReadCount;
  int? lastCoilReadStartAddress;

  @override
  Future<List<int>> readHoldingRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    if (throwOnHoldingRead) throw StateError('read failed');
    lastHoldingReadStartAddress = startAddress;
    lastHoldingReadCount = count;
    return holdingReadBack.take(count).toList();
  }

  @override
  Future<List<bool>> readCoils(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    lastCoilReadStartAddress = startAddress;
    return coilReadBack.take(count).toList();
  }
}

class _IdleScanner extends ChangeNotifier implements DeviceScannerPort {
  @override
  final discoveredDevices = DiscoveredDeviceList();

  @override
  ScannerStateView get state => ScannerStateView.idle;

  @override
  int get scannedCount => 0;

  @override
  int get totalCount => 0;

  @override
  double get progress => 0;

  @override
  String? get scanCidr => null;

  @override
  DateTime? get scanStartedAt => null;

  @override
  ProtocolType? get scanProtocol => null;

  @override
  Future<void> startScan(DeviceScanRequest request) async {}

  @override
  void stopScan() {}

  @override
  void clearResults() {}
}
