/// Flip this flag to include or hide fixture devices and fake runtime data.
abstract final class AppFlags {
  static const bool demoData = bool.fromEnvironment('OMODSCAN_DEMO_DATA');
}
