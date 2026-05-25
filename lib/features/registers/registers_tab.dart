part of 'registers_screen.dart';

class _RegistersTab extends StatefulWidget {
  final String regType;
  final ValueChanged<String> onRegTypeChanged;
  final List<String> listNames;
  final int activeListIndex;
  final ValueChanged<int> onListChanged;
  final VoidCallback onAddList;
  final bool autoRefresh;
  final bool isActive;
  final ValueChanged<bool> onAutoRefreshChanged;
  final int autoRefreshIntervalMs;
  final TextEditingController refreshIntervalCtrl;
  final VoidCallback onRefreshIntervalCommitted;
  final TextEditingController startAddrCtrl;
  final TextEditingController countCtrl;
  final RegisterList registerList;
  final Map<int, (String, String?, DateTime?)> runtimeValues;
  final DateTime? lastReadAt;
  final List<RegisterEntry> Function(int startAddress, int count)
  referenceRegisters;
  final bool canRead;
  final Future<void> Function({
    required String regType,
    required int startAddress,
    required int count,
  })
  onRead;
  final void Function(int address, String typeName, String? comment)
  onEntryChanged;
  final void Function(int address, String value) onValueWritten;

  const _RegistersTab({
    required this.regType,
    required this.onRegTypeChanged,
    required this.listNames,
    required this.activeListIndex,
    required this.onListChanged,
    required this.onAddList,
    required this.autoRefresh,
    required this.isActive,
    required this.onAutoRefreshChanged,
    required this.autoRefreshIntervalMs,
    required this.refreshIntervalCtrl,
    required this.onRefreshIntervalCommitted,
    required this.startAddrCtrl,
    required this.countCtrl,
    required this.registerList,
    required this.runtimeValues,
    required this.lastReadAt,
    required this.referenceRegisters,
    required this.canRead,
    required this.onRead,
    required this.onEntryChanged,
    required this.onValueWritten,
  });

  @override
  State<_RegistersTab> createState() => _RegistersTabState();
}

class _RegistersTabState extends State<_RegistersTab> {
  var _reading = false;
  var _manualReadInProgress = false;
  Timer? _autoRefreshTimer;

  void _onCtrlChanged() => setState(() {});

  bool get _supportsRegisterRead =>
      RegisterAddressType.fromCode(widget.regType).supportsRegisterRead;

  @override
  void initState() {
    super.initState();
    widget.startAddrCtrl.addListener(_onCtrlChanged);
    widget.countCtrl.addListener(_onCtrlChanged);
    _syncAutoRefresh(readImmediately: true);
  }

  @override
  void didUpdateWidget(_RegistersTab old) {
    super.didUpdateWidget(old);
    if (old.startAddrCtrl != widget.startAddrCtrl) {
      old.startAddrCtrl.removeListener(_onCtrlChanged);
      widget.startAddrCtrl.addListener(_onCtrlChanged);
    }
    if (old.countCtrl != widget.countCtrl) {
      old.countCtrl.removeListener(_onCtrlChanged);
      widget.countCtrl.addListener(_onCtrlChanged);
    }
    if (old.autoRefresh != widget.autoRefresh ||
        old.isActive != widget.isActive ||
        old.autoRefreshIntervalMs != widget.autoRefreshIntervalMs ||
        old.canRead != widget.canRead ||
        old.regType != widget.regType) {
      _syncAutoRefresh(
        readImmediately:
            widget.autoRefresh &&
            (!old.autoRefresh ||
                !old.isActive && widget.isActive ||
                !old.canRead && widget.canRead),
      );
    }
  }

  @override
  void dispose() {
    widget.startAddrCtrl.removeListener(_onCtrlChanged);
    widget.countCtrl.removeListener(_onCtrlChanged);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _syncAutoRefresh({bool readImmediately = false}) {
    _autoRefreshTimer?.cancel();
    if (!widget.autoRefresh || !widget.isActive) return;

    _autoRefreshTimer = Timer.periodic(
      Duration(milliseconds: widget.autoRefreshIntervalMs),
      (_) {
        _read(showErrors: false, showProgress: false);
      },
    );
    if (readImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.autoRefresh && widget.isActive) {
          _read(showErrors: false, showProgress: false);
        }
      });
    }
  }

  Future<void> _read({bool showErrors = true, bool showProgress = true}) async {
    if (_reading ||
        !widget.isActive ||
        !widget.canRead ||
        !_supportsRegisterRead) {
      return;
    }

    final offset = _regTypeOffset(widget.regType);
    final rawStart = int.tryParse(widget.startAddrCtrl.text) ?? 1;
    final rawCount = int.tryParse(widget.countCtrl.text);
    final count = (rawCount == null || rawCount < 1) ? 20 : rawCount;

    _reading = true;
    if (showProgress) {
      setState(() => _manualReadInProgress = true);
    }
    try {
      await widget.onRead(
        regType: widget.regType,
        startAddress: offset + rawStart,
        count: count,
      );
      if (!mounted) return;
    } catch (error) {
      if (!mounted || !showErrors) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      _reading = false;
      if (mounted) {
        if (showProgress) {
          setState(() => _manualReadInProgress = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final dividerColor = Theme.of(context).dividerTheme.color ?? cs.outline;
    final offset = _regTypeOffset(widget.regType);
    final rawStart = int.tryParse(widget.startAddrCtrl.text) ?? 1;
    final startAddr = offset + rawStart;
    final rawCount = int.tryParse(widget.countCtrl.text);
    final count = (rawCount == null || rawCount < 1) ? 20 : rawCount;
    final endAddr = startAddr + count - 1;
    final mockByAddress = {
      for (final e in widget.referenceRegisters(startAddr, count + 3))
        e.address: e,
    };
    final configByAddress = {
      for (final e in widget.registerList.entries) e.address: e,
    };
    // Build raw uint16 map for visible + 3 extra addresses (needed for 64-bit types).
    final rawInts = <int, int>{};
    for (var i = 0; i < count + 3; i++) {
      final addr = startAddr + i;
      final runtime = widget.runtimeValues[addr];
      final mock = mockByAddress[addr];
      rawInts[addr] = int.tryParse(runtime?.$1 ?? mock?.value ?? '') ?? 0;
    }
    final visibleRegisters = List.generate(count, (i) {
      final addr = startAddr + i;
      final mock = mockByAddress[addr];
      final config = configByAddress[addr];
      final runtime = widget.runtimeValues[addr];
      final typeName = config?.typeName ?? mock?.typeName ?? 'UInt16';
      final rawStr = runtime?.$1 ?? mock?.value ?? '0';
      return RegisterEntry(
        address: addr,
        value: rawStr,
        displayValue: computeDisplayValue(addr, typeName, rawInts),
        previousValue: runtime?.$2 ?? mock?.previousValue,
        typeName: typeName,
        comment: config?.comment ?? mock?.comment,
        timestamp: runtime?.$3 == null
            ? mock?.timestamp
            : _formatTimestamp(runtime!.$3!),
        date: runtime?.$3 == null ? mock?.date : _formatDate(runtime!.$3!),
        rawWords: {
          for (var j = 0; j <= 3; j++)
            if (rawInts.containsKey(addr + j)) addr + j: rawInts[addr + j]!,
        },
      );
    });

    return Column(
      children: [
        RegistersTabToolbar(
          listNames: widget.listNames,
          activeListIndex: widget.activeListIndex,
          onListChanged: widget.onListChanged,
          onAddList: widget.onAddList,
          segments: const [
            ButtonSegment(value: '4xxxx', label: Text('4xxxx')),
            ButtonSegment(value: '3xxxx', label: Text('3xxxx')),
          ],
          selectedSegment: widget.regType,
          onSegmentChanged: widget.onRegTypeChanged,
          canRead: widget.canRead,
          supportsRead: _supportsRegisterRead,
          readInProgress: _manualReadInProgress,
          onRead: _read,
        ),
        RegistersRangeControls(
          startAddrCtrl: widget.startAddrCtrl,
          countCtrl: widget.countCtrl,
          maxCount: 125,
          autoRefresh: widget.autoRefresh,
          onAutoRefreshChanged: widget.onAutoRefreshChanged,
          refreshIntervalCtrl: widget.refreshIntervalCtrl,
          onRefreshIntervalCommitted: widget.onRefreshIntervalCommitted,
        ),
        Container(
          color: cs.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  l10n.colAddress,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Text(
                  l10n.colComment,
                  style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.colValue,
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),
        Divider(height: 1, color: dividerColor),
        Expanded(
          child: ListView.separated(
            itemCount: visibleRegisters.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: dividerColor),
            itemBuilder: (context, i) => RegisterRow(
              entry: visibleRegisters[i],
              canWrite: RegisterAddressType.fromCode(widget.regType).canWrite,
              onEntryChanged: widget.onEntryChanged,
              onValueWritten: widget.onValueWritten,
            ),
          ),
        ),
        Container(
          color: cs.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.registersShowing(startAddr, endAddr),
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                l10n.registersLastUpdate(
                  widget.lastReadAt == null
                      ? '--:--:--'
                      : _formatTimestamp(widget.lastReadAt!),
                ),
                style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
