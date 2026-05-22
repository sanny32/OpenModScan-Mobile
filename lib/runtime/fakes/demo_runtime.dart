import '../../models/log_entry.dart';
import '../../models/register_entry.dart';
import '../../models/status_entry.dart';
import '../runtime_ports.dart';
import 'demo_fixtures.dart';

class DemoRegisterRuntime implements RegisterRuntime {
  final bool enabled;

  const DemoRegisterRuntime({this.enabled = true});

  @override
  List<RegisterEntry> registersForRange(int startAddress, int count) {
    if (!enabled) return const [];
    final endAddress = startAddress + count - 1;
    return demoRegisters
        .where(
          (entry) =>
              entry.address >= startAddress && entry.address <= endAddress,
        )
        .toList();
  }

  @override
  List<StatusEntry> statusesForRange(int startAddress, int count) {
    if (!enabled) return const [];
    final endAddress = startAddress + count - 1;
    return demoStatuses
        .where(
          (entry) =>
              entry.address >= startAddress && entry.address <= endAddress,
        )
        .toList();
  }

  @override
  Future<void> writeRegister({
    required String deviceId,
    required int address,
    required String value,
  }) async {}
}

class DemoTrafficLogSource implements TrafficLogSource {
  final bool enabled;

  const DemoTrafficLogSource({this.enabled = true});

  @override
  List<LogEntry> entriesFor(String? deviceId) =>
      enabled ? demoLogEntries : const [];
}
