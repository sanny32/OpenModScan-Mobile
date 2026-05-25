import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/register_list.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:omodscan_mobile/services/device_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SharedPreferences store persists ids and register config', () async {
    const store = SharedPreferencesDeviceStore();
    final device = DeviceInfo(
      id: 'device-a',
      name: 'PLC A',
      host: '127.0.0.1',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
      registerLists: [
        RegisterList(
          id: 'list-a',
          name: 'Holding',
          refreshIntervalMs: 250,
          coilRefreshIntervalMs: 500,
          entries: [RegisterConfig(address: 40001, typeName: 'Float32')],
          statusEntries: [StatusConfig(address: 7, comment: 'Ready')],
        ),
      ],
    );

    await store.save([device]);
    final loaded = await store.load();

    expect(loaded.single.id, 'device-a');
    expect(loaded.single.registerLists.single.id, 'list-a');
    expect(loaded.single.registerLists.single.refreshIntervalMs, 250);
    expect(loaded.single.registerLists.single.coilRefreshIntervalMs, 500);
    expect(
      loaded.single.registerLists.single.entries.single.typeName,
      'Float32',
    );
    expect(
      loaded.single.registerLists.single.statusEntries.single.comment,
      'Ready',
    );
  });

  test('repository delegates persistence to store', () async {
    final store = _FakeDeviceStore();
    final repository = DeviceRepository(store);
    final device = DeviceInfo(
      id: 'device-a',
      name: 'PLC A',
      host: '127.0.0.1',
      port: 502,
      protocol: ProtocolType.modbusTcp,
      unitId: 1,
    );

    await repository.add(device);

    expect(repository.snapshot.single.id, 'device-a');
    expect(store.saved.single.id, 'device-a');
  });
}

class _FakeDeviceStore implements DeviceStore {
  List<DeviceInfo> saved = const [];

  @override
  Future<List<DeviceInfo>> load() async => saved;

  @override
  Future<void> save(List<DeviceInfo> devices) async {
    saved = List.of(devices);
  }
}
