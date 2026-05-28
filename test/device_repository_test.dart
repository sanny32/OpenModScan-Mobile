import 'dart:convert';

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
      createdAt: DateTime(2026, 5, 24, 12),
      lastConnectedAt: DateTime(2026, 5, 24, 13),
      isFavorite: true,
      markerColor: DeviceMarkerColor.purple,
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
    expect(loaded.single.createdAt, DateTime(2026, 5, 24, 12));
    expect(loaded.single.lastConnectedAt, DateTime(2026, 5, 24, 13));
    expect(loaded.single.isFavorite, isTrue);
    expect(loaded.single.markerColor, DeviceMarkerColor.purple);
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

  test('SharedPreferences store migrates legacy device metadata', () async {
    final legacyDevices = [
      {
        'id': 'device-old',
        'name': 'Old',
        'host': '127.0.0.1',
        'port': 502,
        'protocol': 'modbusTcp',
        'unitId': 1,
        'timeout': 1000,
        'reconnectDelay': 3000,
        'notes': '',
        'registerLists': [],
      },
      {
        'id': 'device-new',
        'name': 'New',
        'host': '127.0.0.2',
        'port': 502,
        'protocol': 'modbusTcp',
        'unitId': 1,
        'timeout': 1000,
        'reconnectDelay': 3000,
        'notes': '',
        'registerLists': [],
      },
    ];
    SharedPreferences.setMockInitialValues({
      SharedPreferencesDeviceStore.key: jsonEncode(legacyDevices),
    });

    final loaded = await const SharedPreferencesDeviceStore().load();

    expect(loaded.map((device) => device.isFavorite), [false, false]);
    expect(loaded.map((device) => device.markerColor), [
      DeviceMarkerColor.blue,
      DeviceMarkerColor.blue,
    ]);
    expect(loaded.map((device) => device.lastConnectedAt), [null, null]);
    expect(loaded.last.createdAt.isAfter(loaded.first.createdAt), isTrue);
  });

  test('SharedPreferences store migrates legacy status addresses', () async {
    final legacyDevices = [
      {
        'id': 'device-status-legacy',
        'name': 'Status Legacy',
        'host': '127.0.0.1',
        'port': 502,
        'protocol': 'modbusTcp',
        'unitId': 1,
        'timeout': 1000,
        'reconnectDelay': 3000,
        'notes': '',
        'registerLists': [
          {
            'id': 'status-list-legacy',
            'name': 'Status List',
            'coilStartAddress': 7,
            'statusEntries': [
              {'statusType': '0xxxx', 'address': 7, 'comment': 'Ready'},
              {'statusType': '1xxxx', 'address': 12, 'comment': 'Line ready'},
            ],
          },
        ],
      },
    ];
    SharedPreferences.setMockInitialValues({
      SharedPreferencesDeviceStore.key: jsonEncode(legacyDevices),
    });

    final store = const SharedPreferencesDeviceStore();
    final loaded = await store.load();
    final list = loaded.single.registerLists.single;

    expect(list.coilStartAddress, 8);
    expect(list.statusEntries.map((entry) => entry.address), [8, 10013]);

    await store.save(loaded);
    final reloaded = await store.load();
    final reloadedList = reloaded.single.registerLists.single;

    expect(reloadedList.coilStartAddress, 8);
    expect(reloadedList.statusEntries.map((entry) => entry.address), [
      8,
      10013,
    ]);

    final savedRaw = SharedPreferences.getInstance().then(
      (prefs) => prefs.getString(SharedPreferencesDeviceStore.key),
    );
    final savedJson = jsonDecode((await savedRaw)!) as List<dynamic>;
    final savedList =
        (savedJson.single as Map<String, dynamic>)['registerLists'].single
            as Map<String, dynamic>;
    expect(savedList['statusAddressMode'], kStatusAddressModeDisplay);
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
