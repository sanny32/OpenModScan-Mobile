part of 'registers_screen.dart';

class _ListConfig {
  final RegisterList data;
  final ValueChanged<RegisterList>? onChanged;
  late final TextEditingController startAddrCtrl;
  late final TextEditingController countCtrl;
  late final TextEditingController refreshIntervalCtrl;
  late final TextEditingController coilStartAddrCtrl;
  late final TextEditingController coilCountCtrl;
  late final TextEditingController coilRefreshIntervalCtrl;

  String get name => data.name;
  set name(String value) => data.name = value;

  String get regType => data.regType;
  set regType(String value) => data.regType = value;

  String get coilType => data.coilType;
  set coilType(String value) => data.coilType = value;

  bool get autoRefresh => data.autoRefresh;
  set autoRefresh(bool value) => data.autoRefresh = value;

  int get refreshIntervalMs => data.refreshIntervalMs;

  bool get coilAutoRefresh => data.coilAutoRefresh;
  set coilAutoRefresh(bool value) => data.coilAutoRefresh = value;

  int get coilRefreshIntervalMs => data.coilRefreshIntervalMs;

  _ListConfig(this.data, {this.onChanged}) {
    final addressBaseStart = AppSettings.instance.addressBaseStart;
    if (data.count < 1) data.count = 20;
    if (data.coilCount < 1) data.coilCount = 20;

    startAddrCtrl = TextEditingController(
      text: (data.startAddress + addressBaseStart).toString(),
    );
    countCtrl = TextEditingController(text: data.count.toString());
    refreshIntervalCtrl = TextEditingController(
      text: data.refreshIntervalMs.toString(),
    );
    coilStartAddrCtrl = TextEditingController(
      text: (data.coilStartAddress + addressBaseStart).toString(),
    );
    coilCountCtrl = TextEditingController(text: data.coilCount.toString());
    coilRefreshIntervalCtrl = TextEditingController(
      text: data.coilRefreshIntervalMs.toString(),
    );

    startAddrCtrl.addListener(() {
      final minStart = AppSettings.instance.addressBaseStart;
      final value = int.tryParse(startAddrCtrl.text) ?? minStart;
      final displayStart = value < minStart ? minStart : value;
      data.startAddress = displayStart - minStart;
      onChanged?.call(data);
    });
    countCtrl.addListener(() {
      final value = int.tryParse(countCtrl.text) ?? 20;
      data.count = value < 1 ? 20 : value;
      onChanged?.call(data);
    });
    refreshIntervalCtrl.addListener(() {
      final value = int.tryParse(refreshIntervalCtrl.text);
      if (value == null ||
          value < kMinRegisterRefreshIntervalMs ||
          value > kMaxRegisterRefreshIntervalMs) {
        return;
      }
      data.refreshIntervalMs = value;
      onChanged?.call(data);
    });
    coilStartAddrCtrl.addListener(() {
      final minStart = AppSettings.instance.addressBaseStart;
      final value = int.tryParse(coilStartAddrCtrl.text) ?? minStart;
      final displayStart = value < minStart ? minStart : value;
      data.coilStartAddress = displayStart - minStart;
      onChanged?.call(data);
    });
    coilCountCtrl.addListener(() {
      final value = int.tryParse(coilCountCtrl.text) ?? 20;
      data.coilCount = value < 1 ? 20 : value;
      onChanged?.call(data);
    });
    coilRefreshIntervalCtrl.addListener(() {
      final value = int.tryParse(coilRefreshIntervalCtrl.text);
      if (value == null ||
          value < kMinRegisterRefreshIntervalMs ||
          value > kMaxRegisterRefreshIntervalMs) {
        return;
      }
      data.coilRefreshIntervalMs = value;
      onChanged?.call(data);
    });
  }

  void commitRefreshInterval() {
    final rawValue = int.tryParse(refreshIntervalCtrl.text);
    final value = rawValue == null
        ? data.refreshIntervalMs
        : rawValue
              .clamp(
                kMinRegisterRefreshIntervalMs,
                kMaxRegisterRefreshIntervalMs,
              )
              .toInt();
    if (data.refreshIntervalMs != value) {
      data.refreshIntervalMs = value;
      onChanged?.call(data);
    }
    refreshIntervalCtrl.text = value.toString();
  }

  void commitCoilRefreshInterval() {
    final rawValue = int.tryParse(coilRefreshIntervalCtrl.text);
    final value = rawValue == null
        ? data.coilRefreshIntervalMs
        : rawValue
              .clamp(
                kMinRegisterRefreshIntervalMs,
                kMaxRegisterRefreshIntervalMs,
              )
              .toInt();
    if (data.coilRefreshIntervalMs != value) {
      data.coilRefreshIntervalMs = value;
      onChanged?.call(data);
    }
    coilRefreshIntervalCtrl.text = value.toString();
  }

  void dispose() {
    startAddrCtrl.dispose();
    countCtrl.dispose();
    refreshIntervalCtrl.dispose();
    coilStartAddrCtrl.dispose();
    coilCountCtrl.dispose();
    coilRefreshIntervalCtrl.dispose();
  }
}
