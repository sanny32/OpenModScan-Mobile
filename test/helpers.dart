import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omodscan_mobile/features/registers/register_list_dialogs.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/modbus_exception.dart';
import 'package:omodscan_mobile/models/register_list.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:omodscan_mobile/services/modbus_client.dart';
import 'package:omodscan_mobile/services/traffic_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> resetAppTestState({
  Iterable<DeviceInfo> devices = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  await AppSettings.instance.resetToDefaults();
  await DeviceRepository.instance.replaceAll(List.of(devices));
  await TrafficLog.instance.resetForTesting();
}

/// In-memory [DeviceRepositoryPort] used to verify that controllers depend on
/// the port rather than the concrete [DeviceRepository]/`SharedPreferences`.
class FakeDeviceRepository implements DeviceRepositoryPort {
  @override
  final ValueNotifier<List<DeviceInfo>> devices = ValueNotifier(const []);

  FakeDeviceRepository([List<DeviceInfo> initial = const []]) {
    devices.value = List.of(initial);
  }

  @override
  List<DeviceInfo> get snapshot => List.unmodifiable(devices.value);

  @override
  DeviceInfo? findById(String id) {
    for (final device in devices.value) {
      if (device.id == id) return device;
    }
    return null;
  }

  @override
  Future<void> replaceAll(List<DeviceInfo> newDevices) async {
    devices.value = List.of(newDevices);
  }

  @override
  Future<void> add(DeviceInfo device) => replaceAll([...devices.value, device]);

  @override
  Future<void> insert(int index, DeviceInfo device) async {
    final updated = List.of(devices.value);
    updated.insert(index.clamp(0, updated.length), device);
    await replaceAll(updated);
  }

  @override
  Future<void> update(DeviceInfo device) async {
    final updated = List.of(devices.value);
    final index = updated.indexWhere((item) => item.id == device.id);
    if (index == -1) return;
    updated[index] = device;
    await replaceAll(updated);
  }

  @override
  Future<DeviceInfo?> remove(String deviceId) async {
    final updated = List.of(devices.value);
    final index = updated.indexWhere((item) => item.id == deviceId);
    if (index == -1) return null;
    final removed = updated.removeAt(index);
    await replaceAll(updated);
    return removed;
  }

  @override
  Future<void> addRegisterList(String deviceId, RegisterList list) async {
    final device = findById(deviceId);
    if (device == null) return;
    await update(
      device.copyWith(registerLists: [...device.registerLists, list]),
    );
  }

  @override
  Future<void> removeRegisterList(String deviceId, String listId) async {
    final device = findById(deviceId);
    if (device == null) return;
    await update(
      device.copyWith(
        registerLists: device.registerLists
            .where((list) => list.id != listId)
            .toList(),
      ),
    );
  }

  @override
  Future<void> updateRegisterList(
    String deviceId,
    RegisterList registerList,
  ) async {
    final device = findById(deviceId);
    if (device == null) return;
    final updated = List.of(device.registerLists);
    final index = updated.indexWhere((list) => list.id == registerList.id);
    if (index == -1) return;
    updated[index] = registerList;
    await update(device.copyWith(registerLists: updated));
  }

  @override
  Future<void> upsertRegisterConfig(
    String deviceId,
    String listId,
    RegisterConfig config,
  ) async {
    final device = findById(deviceId);
    if (device == null) return;
    final indexOfList = device.registerLists.indexWhere(
      (item) => item.id == listId,
    );
    if (indexOfList == -1) return;
    final list = device.registerLists[indexOfList];
    final entries = List.of(list.entries);
    final index = entries.indexWhere((item) => item.address == config.address);
    if (index == -1) {
      entries.add(config);
    } else {
      entries[index] = config;
    }
    await updateRegisterList(deviceId, list.copyWith(entries: entries));
  }

  @override
  Future<void> upsertStatusConfig(
    String deviceId,
    String listId,
    StatusConfig config,
  ) async {
    final device = findById(deviceId);
    if (device == null) return;
    final indexOfList = device.registerLists.indexWhere(
      (item) => item.id == listId,
    );
    if (indexOfList == -1) return;
    final list = device.registerLists[indexOfList];
    final entries = List.of(list.statusEntries);
    final index = entries.indexWhere(
      (item) =>
          item.statusType == config.statusType &&
          item.address == config.address,
    );
    if (index == -1) {
      entries.add(config);
    } else {
      entries[index] = config;
    }
    await updateRegisterList(deviceId, list.copyWith(statusEntries: entries));
  }
}

class RegisterListDialogHarness extends StatelessWidget {
  final List<String> existingNames;

  const RegisterListDialogHarness({super.key, this.existingNames = const []});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showRegisterListDialog(
                context,
                defaultName: 'List 1',
                existingNames: existingNames,
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );
  }
}

class PollingConnectionRuntime implements ConnectionRuntime {
  final _ids = ValueNotifier<Set<String>>(const {});
  var holdingReadCount = 0;
  var coilReadCount = 0;
  int? lastWriteHoldingAddress;
  int? lastWriteHoldingValue;
  int? lastWriteHoldingStartAddress;
  List<int>? lastWriteHoldingValues;
  var writeHoldingRegistersFallback = false;
  int? lastWriteCoilAddress;
  bool? lastWriteCoilValue;

  @override
  ValueListenable<Set<String>> get connectedDeviceIds => _ids;

  @override
  Future<void> connect(DeviceInfo device) async {
    _ids.value = {..._ids.value, device.id};
  }

  @override
  Future<void> disconnect(DeviceInfo device) async {
    _ids.value = Set.of(_ids.value)..remove(device.id);
  }

  @override
  bool isConnected(DeviceInfo device) => _ids.value.contains(device.id);

  @override
  Future<List<int>> readHoldingRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    holdingReadCount++;
    return List.filled(count, holdingReadCount);
  }

  @override
  Future<List<int>> readInputRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async => List.filled(count, 0);

  @override
  Future<List<bool>> readCoils(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    coilReadCount++;
    return List.filled(count, coilReadCount.isOdd);
  }

  @override
  Future<List<bool>> readDiscreteInputs(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async => List.filled(count, false);

  @override
  Future<void> writeHoldingRegister(
    DeviceInfo device, {
    required int address,
    required int value,
  }) async {
    lastWriteHoldingAddress = address;
    lastWriteHoldingValue = value;
  }

  @override
  Future<bool> writeHoldingRegisters(
    DeviceInfo device, {
    required int startAddress,
    required List<int> values,
  }) async {
    lastWriteHoldingStartAddress = startAddress;
    lastWriteHoldingValues = List.of(values);
    return writeHoldingRegistersFallback;
  }

  @override
  Future<void> writeCoil(
    DeviceInfo device, {
    required int address,
    required bool value,
  }) async {
    lastWriteCoilAddress = address;
    lastWriteCoilValue = value;
  }
}

class ThrowingRegisterConnectionRuntime extends PollingConnectionRuntime {
  final Object error;

  ThrowingRegisterConnectionRuntime({Object? error})
    : error =
          error ??
          ModbusClientException.modbus(ModbusExceptionCode.illegalDataAddress);

  @override
  Future<List<int>> readHoldingRegisters(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    throw error;
  }
}

class ThrowingStatusConnectionRuntime extends PollingConnectionRuntime {
  final Object error;

  ThrowingStatusConnectionRuntime({Object? error})
    : error =
          error ??
          ModbusClientException.modbus(ModbusExceptionCode.illegalDataAddress);

  @override
  Future<List<bool>> readCoils(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    coilReadCount++;
    throw error;
  }

  @override
  Future<List<bool>> readDiscreteInputs(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    coilReadCount++;
    throw error;
  }
}

class ThrowingStatusWriteConnectionRuntime extends PollingConnectionRuntime {
  final Object error;

  ThrowingStatusWriteConnectionRuntime({Object? error})
    : error = error ?? StateError('Coil write failed');

  @override
  Future<void> writeCoil(
    DeviceInfo device, {
    required int address,
    required bool value,
  }) async {
    lastWriteCoilAddress = address;
    lastWriteCoilValue = value;
    throw error;
  }
}

class FlakyStatusConnectionRuntime extends PollingConnectionRuntime {
  var failReads = true;
  final Object error;

  FlakyStatusConnectionRuntime({Object? error})
    : error =
          error ??
          ModbusClientException.modbus(ModbusExceptionCode.illegalDataAddress);

  @override
  Future<List<bool>> readCoils(
    DeviceInfo device, {
    required int startAddress,
    required int count,
  }) async {
    if (failReads) {
      coilReadCount++;
      throw error;
    }
    return super.readCoils(device, startAddress: startAddress, count: count);
  }
}
