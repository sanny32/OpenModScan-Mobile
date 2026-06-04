import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/app_settings.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/services/backup_service.dart';
import 'package:omodscan_mobile/services/settings_store.dart';

import 'helpers.dart';

/// In-memory [SettingsStore] so each test gets an isolated [AppSettings].
class _MemorySettingsStore implements SettingsStore {
  final Map<String, Object?> values = {};

  @override
  Future<void> load() async {}

  @override
  String? getString(String key) => values[key] as String?;

  @override
  int? getInt(String key) => values[key] as int?;

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => values[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
}

DeviceInfo _device(String name, String host) => DeviceInfo(
  name: name,
  host: host,
  port: 502,
  protocol: ProtocolType.modbusTcp,
  unitId: 1,
);

Uint8List _encode(Object json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  test('export writes settings and devices as versioned JSON', () async {
    final settings = AppSettings.withStore(_MemorySettingsStore());
    await settings.setDefaultReadQty(33);
    final repo = FakeDeviceRepository([_device('PLC', '10.0.0.5')]);

    Uint8List? written;
    final service = BackupService(
      settings: settings,
      repository: repo,
      writer: ({dialogTitle, required fileName, required bytes}) async {
        written = bytes;
        return '/tmp/$fileName';
      },
    );

    final result = await service.export();

    expect(result, BackupResult.success);
    final decoded = jsonDecode(utf8.decode(written!)) as Map<String, dynamic>;
    expect(decoded['version'], 1);
    expect((decoded['settings'] as Map)['defaultReadQty'], 33);
    final devices = decoded['devices'] as List;
    expect(devices, hasLength(1));
    expect((devices.first as Map)['name'], 'PLC');
  });

  test('export returns cancelled when the save dialog is dismissed', () async {
    final service = BackupService(
      settings: AppSettings.withStore(_MemorySettingsStore()),
      repository: FakeDeviceRepository(),
      writer: ({dialogTitle, required fileName, required bytes}) async => null,
    );

    expect(await service.export(), BackupResult.cancelled);
  });

  test('import applies settings and replaces devices', () async {
    final settings = AppSettings.withStore(_MemorySettingsStore());
    final repo = FakeDeviceRepository([_device('Old', '1.1.1.1')]);
    final payload = _encode({
      'version': 1,
      'settings': {'defaultReadQty': 64, 'timeout': 2500},
      'devices': [_device('Imported', '192.168.1.9').toJson()],
    });
    final service = BackupService(
      settings: settings,
      repository: repo,
      reader: ({dialogTitle}) async => payload,
    );

    final result = await service.import();

    expect(result, BackupResult.success);
    expect(settings.defaultReadQty, 64);
    expect(settings.timeout, 2500);
    expect(repo.snapshot, hasLength(1));
    expect(repo.snapshot.first.name, 'Imported');
  });

  test('import rejects an unknown backup version and keeps data', () async {
    final repo = FakeDeviceRepository([_device('Existing', '1.1.1.1')]);
    final service = BackupService(
      settings: AppSettings.withStore(_MemorySettingsStore()),
      repository: repo,
      reader: ({dialogTitle}) async => _encode({'version': 99}),
    );

    expect(await service.import(), BackupResult.failure);
    expect(repo.snapshot, hasLength(1));
    expect(repo.snapshot.first.name, 'Existing');
  });

  test('import returns cancelled when no file is chosen', () async {
    final service = BackupService(
      settings: AppSettings.withStore(_MemorySettingsStore()),
      repository: FakeDeviceRepository(),
      reader: ({dialogTitle}) async => null,
    );

    expect(await service.import(), BackupResult.cancelled);
  });

  test('import treats malformed JSON as a failure', () async {
    final repo = FakeDeviceRepository([_device('Existing', '1.1.1.1')]);
    final service = BackupService(
      settings: AppSettings.withStore(_MemorySettingsStore()),
      repository: repo,
      reader: ({dialogTitle}) async =>
          Uint8List.fromList(utf8.encode('not json')),
    );

    expect(await service.import(), BackupResult.failure);
    expect(repo.snapshot, hasLength(1));
  });
}
