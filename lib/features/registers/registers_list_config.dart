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

  int get addrMode => data.addrMode;
  set addrMode(int value) => data.addrMode = value;

  bool get autoRefresh => data.autoRefresh;
  set autoRefresh(bool value) => data.autoRefresh = value;

  int get refreshIntervalMs => data.refreshIntervalMs;

  bool get coilAutoRefresh => data.coilAutoRefresh;
  set coilAutoRefresh(bool value) => data.coilAutoRefresh = value;

  int get coilRefreshIntervalMs => data.coilRefreshIntervalMs;

  _ListConfig(this.data, {this.onChanged}) {
    startAddrCtrl = TextEditingController(text: data.startAddress.toString());
    countCtrl = TextEditingController(text: data.count.toString());
    refreshIntervalCtrl = TextEditingController(
      text: data.refreshIntervalMs.toString(),
    );
    coilStartAddrCtrl = TextEditingController(
      text: data.coilStartAddress.toString().padLeft(5, '0'),
    );
    coilCountCtrl = TextEditingController(text: data.coilCount.toString());
    coilRefreshIntervalCtrl = TextEditingController(
      text: data.coilRefreshIntervalMs.toString(),
    );

    startAddrCtrl.addListener(() {
      data.startAddress = int.tryParse(startAddrCtrl.text) ?? 1;
      onChanged?.call(data);
    });
    countCtrl.addListener(() {
      data.count = int.tryParse(countCtrl.text) ?? 20;
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
      data.coilStartAddress = int.tryParse(coilStartAddrCtrl.text) ?? 0;
      onChanged?.call(data);
    });
    coilCountCtrl.addListener(() {
      data.coilCount = int.tryParse(coilCountCtrl.text) ?? 20;
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
