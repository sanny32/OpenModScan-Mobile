import '../models/device_info.dart';

class ModbusClient {
  final DeviceInfo device;
  bool _connected = false;

  ModbusClient(this.device);

  bool get isConnected => _connected;

  Future<void> connect() async {
    // TODO: implement Modbus TCP/RTU connection
    _connected = true;
  }

  Future<void> disconnect() async {
    // TODO: close connection
    _connected = false;
  }
}
