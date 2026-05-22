import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/device_info.dart';
import 'package:omodscan_mobile/models/register_list.dart';
import 'package:omodscan_mobile/services/device_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists ids and register config', () async {
    final repository = DeviceRepository.instance;
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
          entries: [RegisterConfig(address: 40001, typeName: 'Float32')],
        ),
      ],
    );

    await repository.replaceAll([device]);
    final loaded = await repository.load();

    expect(loaded.single.id, 'device-a');
    expect(loaded.single.registerLists.single.id, 'list-a');
    expect(
      loaded.single.registerLists.single.entries.single.typeName,
      'Float32',
    );
  });
}
