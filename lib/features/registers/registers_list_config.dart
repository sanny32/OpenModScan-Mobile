part of 'registers_screen.dart';

class _ListConfig {
  final RegisterList data;
  final ValueChanged<RegisterList>? onChanged;
  late final TextEditingController startAddrCtrl;
  late final TextEditingController countCtrl;
  late final TextEditingController coilStartAddrCtrl;
  late final TextEditingController coilCountCtrl;

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

  bool get coilAutoRefresh => data.coilAutoRefresh;
  set coilAutoRefresh(bool value) => data.coilAutoRefresh = value;

  _ListConfig(this.data, {this.onChanged}) {
    startAddrCtrl = TextEditingController(text: data.startAddress.toString());
    countCtrl = TextEditingController(text: data.count.toString());
    coilStartAddrCtrl = TextEditingController(
      text: data.coilStartAddress.toString().padLeft(5, '0'),
    );
    coilCountCtrl = TextEditingController(text: data.coilCount.toString());

    startAddrCtrl.addListener(() {
      data.startAddress = int.tryParse(startAddrCtrl.text) ?? 1;
      onChanged?.call(data);
    });
    countCtrl.addListener(() {
      data.count = int.tryParse(countCtrl.text) ?? 20;
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
  }

  void dispose() {
    startAddrCtrl.dispose();
    countCtrl.dispose();
    coilStartAddrCtrl.dispose();
    coilCountCtrl.dispose();
  }
}
