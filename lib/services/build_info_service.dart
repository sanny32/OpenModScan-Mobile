import 'package:flutter/services.dart';

class PackageVersion {
  final String name;
  final int code;

  const PackageVersion({required this.name, required this.code});

  String get display => name.isEmpty ? '-' : '$name ($code)';
}

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

  Future<PackageVersion?> packageVersion() async {
    try {
      final rawVersion = await _channel.invokeMapMethod<String, Object?>(
        'getPackageVersion',
      );
      if (rawVersion == null) return null;
      final name = rawVersion['name'];
      final code = rawVersion['code'];
      if (name is! String || code is! int) return null;
      return PackageVersion(name: name, code: code);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
