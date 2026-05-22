import 'package:flutter/services.dart';

class BuildInfoService {
  static const _channel = MethodChannel(
    'io.github.sanny32.omodscan_mobile/build_info',
  );

  const BuildInfoService();

  Future<DateTime?> packageBuildDate() async {
    try {
      final rawDate = await _channel.invokeMethod<String>(
        'getPackageBuildDate',
      );
      return rawDate == null ? null : DateTime.tryParse(rawDate);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
