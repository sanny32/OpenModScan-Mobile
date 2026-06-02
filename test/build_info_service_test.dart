import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/services/build_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'io.github.sanny32.omodscan_mobile/build_info',
  );
  const service = BuildInfoService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('package build date parses valid channel response', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getPackageBuildDate');
          return '2026-05-24T12:30:00.000Z';
        });

    expect(
      await service.packageBuildDate(),
      DateTime.parse('2026-05-24T12:30:00.000Z'),
    );
  });

  test('package build date returns null for null, malformed, or errors',
      () async {
    Future<DateTime?> dateFor(Future<Object?> Function() handler) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) => handler());
      return service.packageBuildDate();
    }

    expect(await dateFor(() async => null), isNull);
    expect(await dateFor(() async => 'not-a-date'), isNull);
    expect(
      await dateFor(
        () async => throw PlatformException(code: 'failed'),
      ),
      isNull,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(await service.packageBuildDate(), isNull);
  });

  test('package version parses valid channel response and display label',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getPackageVersion');
          return {'name': '1.2.3', 'code': 42};
        });

    final version = await service.packageVersion();

    expect(version, isNotNull);
    expect(version!.name, '1.2.3');
    expect(version.code, 42);
    expect(version.display, '1.2.3 (42)');
    expect(const PackageVersion(name: '', code: 0).display, '-');
  });

  test('package version returns null for null, malformed, or errors',
      () async {
    Future<PackageVersion?> versionFor(
      Future<Object?> Function() handler,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) => handler());
      return service.packageVersion();
    }

    expect(await versionFor(() async => null), isNull);
    expect(await versionFor(() async => {'name': '1.2.3'}), isNull);
    expect(await versionFor(() async => {'name': 123, 'code': 1}), isNull);
    expect(
      await versionFor(
        () async => throw PlatformException(code: 'failed'),
      ),
      isNull,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(await service.packageVersion(), isNull);
  });
}
