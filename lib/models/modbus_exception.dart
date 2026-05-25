enum ModbusExceptionCode {
  illegalFunction(0x01, 'Illegal Function'),
  illegalDataAddress(0x02, 'Illegal Data Address'),
  illegalDataValue(0x03, 'Illegal Data Value'),
  serverDeviceFailure(0x04, 'Server Device Failure'),
  acknowledge(0x05, 'Acknowledge'),
  serverDeviceBusy(0x06, 'Server Device Busy'),
  negativeAcknowledge(0x07, 'Negative Acknowledge'),
  memoryParityError(0x08, 'Memory Parity Error'),
  gatewayPathUnavailable(0x0A, 'Gateway Path Unavailable'),
  gatewayTargetDeviceFailedToRespond(
    0x0B,
    'Gateway Target Device Failed To Respond',
  );

  final int code;
  final String label;

  const ModbusExceptionCode(this.code, this.label);

  static ModbusExceptionCode? fromCode(int code) {
    for (final exception in values) {
      if (exception.code == code) return exception;
    }
    return null;
  }
}
