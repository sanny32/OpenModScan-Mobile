import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omodscan_mobile/features/registers/register_list_dialogs.dart';
import 'package:omodscan_mobile/l10n/l10n.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/modbus_exception.dart';
import 'package:omodscan_mobile/runtime/runtime_ports.dart';
import 'package:omodscan_mobile/services/modbus_client.dart';

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
