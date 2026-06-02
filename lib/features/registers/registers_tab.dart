part of 'registers_screen.dart';

class _RegistersTab extends StatefulWidget {
  final String regType;
  final ValueChanged<String> onRegTypeChanged;
  final Widget listSelector;
  final bool autoRefresh;
  final bool isActive;
  final ValueChanged<bool> onAutoRefreshChanged;
  final int autoRefreshIntervalMs;
  final TextEditingController refreshIntervalCtrl;
  final VoidCallback onRefreshIntervalCommitted;
  final TextEditingController startAddrCtrl;
  final TextEditingController countCtrl;
  final FocusNode startAddrFocus;
  final FocusNode countFocus;
  final FocusNode refreshIntervalFocus;
  final RegisterList registerList;
  final Map<int, RegisterRuntimeValue> runtimeValues;
  final DateTime? lastReadAt;
  final List<RegisterEntry> Function(int startAddress, int count)
  referenceRegisters;
  final bool isConnected;
  final bool canRead;
  final RegisterValueState valueState;
  final void Function(
    RegisterValueState state,
    String? label, {
    required bool shared,
  })
  onValueStateChanged;
  final Future<void> Function({
    required String regType,
    required int startAddress,
    required int count,
  })
  onRead;
  final void Function(int address, String typeName, String? comment)
  onEntryChanged;
  final Future<String?> Function(int address, String value, String typeName)
  onValueWritten;
  final Listenable valuesListenable;
  final RegisterRuntimeValue? Function(int address) liveValueAt;

  const _RegistersTab({
    required this.regType,
    required this.onRegTypeChanged,
    required this.listSelector,
    required this.autoRefresh,
    required this.isActive,
    required this.onAutoRefreshChanged,
    required this.autoRefreshIntervalMs,
    required this.refreshIntervalCtrl,
    required this.onRefreshIntervalCommitted,
    required this.startAddrCtrl,
    required this.countCtrl,
    required this.startAddrFocus,
    required this.countFocus,
    required this.refreshIntervalFocus,
    required this.registerList,
    required this.runtimeValues,
    required this.lastReadAt,
    required this.referenceRegisters,
    required this.isConnected,
    required this.canRead,
    required this.valueState,
    required this.onValueStateChanged,
    required this.onRead,
    required this.onEntryChanged,
    required this.onValueWritten,
    required this.valuesListenable,
    required this.liveValueAt,
  });

  @override
  State<_RegistersTab> createState() => _RegistersTabState();
}

class _RegistersTabState extends State<_RegistersTab> {
  var _reading = false;
  var _manualReadInProgress = false;
  final _expandedRegisterGroups = <int>{};
  final ScrollController _scrollController = ScrollController();
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
        old.isConnected != widget.isConnected ||
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
    _scrollController.dispose();
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

    final addressType = RegisterAddressType.fromCode(widget.regType);
    final offset = addressType.displayOffset;
    final minStart = AppSettings.instance.addressBaseStart;
    final parsedStart = int.tryParse(widget.startAddrCtrl.text) ?? minStart;
    final rawStart = parsedStart < minStart ? minStart : parsedStart;
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
      widget.onValueStateChanged(
        RegisterValueState.received,
        null,
        shared: true,
      );
      widget.onValueStateChanged(
        RegisterValueState.received,
        null,
        shared: false,
      );
    } catch (error) {
      if (mounted) {
        final valueState = _valueStateForReadError(error);
        widget.onValueStateChanged(
          valueState,
          valueState == RegisterValueState.exception
              ? _readErrorLabel(context, error)
              : null,
          shared: !_isModbusExceptionError(error),
        );
      }
      if (!mounted || !showErrors) return;
      showErrorSnackBar(context, error);
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
    final addressType = RegisterAddressType.fromCode(widget.regType);
    final offset = addressType.displayOffset;
    final minStart = AppSettings.instance.addressBaseStart;
    final parsedStart = int.tryParse(widget.startAddrCtrl.text) ?? minStart;
    final rawStart = parsedStart < minStart ? minStart : parsedStart;
    final startAddr = offset + rawStart;
    final rawCount = int.tryParse(widget.countCtrl.text);
    final count = (rawCount == null || rawCount < 1) ? 20 : rawCount;
    final endAddr = startAddr + count - 1;
    final mockByAddress = {
      for (final e in widget.referenceRegisters(startAddr, count + 3))
        e.address: e,
    };
    final configByAddress = <int, RegisterConfig>{};
    for (final entry in widget.registerList.entries) {
      final displayAddress = addressType.tryCanonicalAddressToDisplay(
        entry.address,
        addressBase: minStart,
      );
      if (displayAddress != null) {
        configByAddress[displayAddress] = entry;
      }
    }
    // Build raw uint16 map for visible + 3 extra addresses (needed for 64-bit types).
    final rawInts = <int, int>{};
    final previousRawInts = <int, int>{};
    for (var i = 0; i < count + 3; i++) {
      final addr = startAddr + i;
      final runtime = widget.runtimeValues[addr];
      final mock = mockByAddress[addr];
      rawInts[addr] = int.tryParse(runtime?.value ?? mock?.value ?? '') ?? 0;
      final prev = runtime?.previous ?? mock?.previousValue;
      final prevInt = prev == null ? null : int.tryParse(prev);
      if (prevInt != null) previousRawInts[addr] = prevInt;
    }
    final visibleRegisters = List.generate(count, (i) {
      final addr = startAddr + i;
      final mock = mockByAddress[addr];
      final config = configByAddress[addr];
      final runtime = widget.runtimeValues[addr];
      final typeName = config?.typeName ?? mock?.typeName ?? 'UInt16';
      final rawStr = runtime?.value ?? mock?.value ?? '0';
      final valueState = !widget.isConnected
          ? RegisterValueState.unavailable
          : widget.valueState == RegisterValueState.exception
          ? RegisterValueState.exception
          : runtime == null && mock == null
          ? RegisterValueState.unavailable
          : widget.valueState;
      return RegisterEntry(
        address: addr,
        value: rawStr,
        displayValue: computeDisplayValue(addr, typeName, rawInts),
        previousValue: runtime?.previous ?? mock?.previousValue,
        valueState: valueState,
        typeName: typeName,
        comment: config?.comment ?? mock?.comment,
        timestamp: runtime?.readAt == null
            ? mock?.timestamp
            : _formatTimestamp(runtime!.readAt!),
        date: runtime?.readAt == null
            ? mock?.date
            : _formatDate(runtime!.readAt!),
        rawWords: {
          for (var j = 0; j <= 3; j++)
            if (rawInts.containsKey(addr + j)) addr + j: rawInts[addr + j]!,
        },
        previousRawWords: {
          for (var j = 0; j <= 3; j++)
            if (previousRawInts.containsKey(addr + j))
              addr + j: previousRawInts[addr + j]!,
        },
      );
    });
    final displayItems = <_RegisterDisplayItem>[];
    final coveredTailAddresses = <int>{};
    for (var i = 0; i < visibleRegisters.length; i++) {
      final entry = visibleRegisters[i];
      final wordCount = registerWordCount(entry.typeName);
      final startsOwnGroup = wordCount > 1;
      if (coveredTailAddresses.contains(entry.address) && !startsOwnGroup) {
        continue;
      }

      final fitsVisibleRange = entry.address + wordCount - 1 <= endAddr;
      final hasTailConfig = Iterable.generate(
        wordCount - 1,
        (j) => entry.address + j + 1,
      ).map((address) => configByAddress[address]).any(_blocksRegisterGroup);
      final isGroup = wordCount > 1 && fitsVisibleRange && !hasTailConfig;

      displayItems.add(
        _RegisterDisplayItem(entry: entry, wordCount: isGroup ? wordCount : 1),
      );
      if (isGroup) {
        for (var j = 1; j < wordCount; j++) {
          final tailIndex = i + j;
          if (tailIndex >= visibleRegisters.length) break;
          final tailEntry = visibleRegisters[tailIndex];
          if (registerWordCount(tailEntry.typeName) == 1) {
            coveredTailAddresses.add(tailEntry.address);
          }
        }
      }
    }

    return Column(
      children: [
        RegistersTabToolbar(
          leading: widget.listSelector,
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
          minStartAddress: AppSettings.instance.addressBaseStart,
          autoRefresh: widget.autoRefresh,
          onAutoRefreshChanged: widget.onAutoRefreshChanged,
          refreshIntervalCtrl: widget.refreshIntervalCtrl,
          onRefreshIntervalCommitted: widget.onRefreshIntervalCommitted,
          startAddrFocus: widget.startAddrFocus,
          countFocus: widget.countFocus,
          refreshIntervalFocus: widget.refreshIntervalFocus,
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
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: false,
            child: ListView.separated(
              controller: _scrollController,
              itemCount: displayItems.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: dividerColor),
              itemBuilder: (context, i) {
                final item = displayItems[i];
                return RegisterRow(
                  entry: item.entry,
                  canWrite: addressType.canWrite,
                  groupWordCount: item.wordCount,
                  groupExpanded: _expandedRegisterGroups.contains(
                    item.entry.address,
                  ),
                  onGroupExpansionToggled: item.isGroup
                      ? () {
                          setState(() {
                            final address = item.entry.address;
                            if (!_expandedRegisterGroups.add(address)) {
                              _expandedRegisterGroups.remove(address);
                            }
                          });
                        }
                      : null,
                  onEntryChanged: widget.onEntryChanged,
                  onValueWritten: widget.onValueWritten,
                  valuesListenable: widget.valuesListenable,
                  liveValueAt: widget.liveValueAt,
                );
              },
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

class _RegisterDisplayItem {
  final RegisterEntry entry;
  final int wordCount;

  const _RegisterDisplayItem({required this.entry, required this.wordCount});

  bool get isGroup => wordCount > 1;
}

bool _blocksRegisterGroup(RegisterConfig? config) {
  if (config == null) return false;
  if (registerWordCount(config.typeName) > 1) return false;
  return config.typeName != 'UInt16' ||
      (config.comment?.trim().isNotEmpty ?? false);
}

RegisterValueState _valueStateForReadError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('not connected')) {
    return RegisterValueState.unavailable;
  }
  return RegisterValueState.exception;
}

bool _isModbusExceptionError(Object error) {
  return error is ModbusClientException && error.exceptionCode != null;
}

String _readErrorLabel(BuildContext context, Object error) {
  final raw = error.toString();
  const prefixes = ['ModbusClientException: ', 'Exception: '];
  for (final prefix in prefixes) {
    if (raw.startsWith(prefix)) {
      final message = raw.substring(prefix.length);
      return isTimeoutError(error)
          ? errorFeedbackMessage(context, error).title
          : message;
    }
  }
  return isTimeoutError(error)
      ? errorFeedbackMessage(context, error).title
      : raw;
}
