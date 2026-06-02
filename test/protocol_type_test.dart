import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/models/device_info.dart';

void main() {
  test('describes currently supported connection protocols', () {
    expect(ProtocolType.modbusTcp.supportsConnection, isTrue);
    expect(ProtocolType.modbusRtuIp.supportsConnection, isTrue);
    expect(ProtocolType.modbusRtuIp.unsupportedConnectionMessage, isEmpty);
  });
}
