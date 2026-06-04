import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let buildInfoChannel = "io.github.sanny32.omodscan_mobile/build_info"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.buildInfoChannel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getPackageVersion":
        result(AppDelegate.packageVersion())
      case "getPackageBuildDate":
        result(AppDelegate.packageBuildDate())
      case "getAppName":
        result(AppDelegate.appName())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Mirrors the Android handler: `name` from `CFBundleShortVersionString` and
  /// `code` parsed from `CFBundleVersion`.
  private static func packageVersion() -> [String: Any] {
    let info = Bundle.main.infoDictionary
    let name = info?["CFBundleShortVersionString"] as? String ?? ""
    let code = Int(info?["CFBundleVersion"] as? String ?? "") ?? 0
    return ["name": name, "code": code]
  }

  /// Mirrors `package_info_plus`: prefers the user-facing `CFBundleDisplayName`
  /// and falls back to `CFBundleName`.
  private static func appName() -> String {
    let info = Bundle.main.infoDictionary
    return (info?["CFBundleDisplayName"] as? String)
      ?? (info?["CFBundleName"] as? String)
      ?? ""
  }

  /// iOS has no compile-time build-date resource like Android's gradle
  /// `resValue`, so the app binary's modification time is used as a proxy and
  /// returned as an ISO-8601 UTC string the Dart side can `DateTime.tryParse`.
  private static func packageBuildDate() -> String? {
    guard let executableURL = Bundle.main.executableURL,
      let attributes = try? FileManager.default.attributesOfItem(atPath: executableURL.path),
      let date = attributes[.modificationDate] as? Date
    else { return nil }

    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: date)
  }
}
