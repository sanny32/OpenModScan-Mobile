class DeviceRouteArgs {
  final String deviceId;

  const DeviceRouteArgs(this.deviceId);
}

class RegistersRouteArgs {
  final String deviceId;
  final String? registerListId;

  const RegistersRouteArgs({required this.deviceId, this.registerListId});
}

class TrafficRouteArgs {
  final String deviceId;

  const TrafficRouteArgs(this.deviceId);
}
