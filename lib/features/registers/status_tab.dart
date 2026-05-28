part of 'registers_screen.dart';

class _StatusTab extends StatefulWidget {
  final String statusType;
  final ValueChanged<String> onStatusTypeChanged;
  final Widget listSelector;
  final bool autoRefresh;
  final bool isActive;
  final ValueChanged<bool> onAutoRefreshChanged;
  final int autoRefreshIntervalMs;
  final TextEditingController refreshIntervalCtrl;
  final VoidCallback onRefreshIntervalCommitted;
  final TextEditingController startAddrCtrl;
  final TextEditingController countCtrl;
  final RegisterList registerList;
  final Map<(String, int), (bool, bool?, DateTime?)> runtimeValues;
  final DateTime? lastReadAt;
  final List<StatusEntry> Function(int startAddress, int count)
  referenceStatuses;
  final bool canRead;
  final Future<void> Function({
    required String statusType,
    required int startAddress,
    required int count,
  })
  onRead;
  final void Function(int address, String? comment) onEntryChanged;

  const _StatusTab({
    required this.statusType,
    required this.onStatusTypeChanged,
    required this.listSelector,
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
    required this.referenceStatuses,
    required this.canRead,
    required this.onRead,
    required this.onEntryChanged,
  });

  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab> {
  final _manualValues = <int, bool>{};
  var _reading = false;
  var _manualReadInProgress = false;
  Timer? _autoRefreshTimer;

  bool get _canWrite => RegisterAddressType.fromCode(
    widget.statusType,
    fallback: RegisterAddressType.coils,
  ).canWrite;

  bool get _supportsStatusRead => RegisterAddressType.fromCode(
    widget.statusType,
    fallback: RegisterAddressType.coils,
  ).supportsStatusRead;

  void _onCtrlChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.startAddrCtrl.addListener(_onCtrlChanged);
    widget.countCtrl.addListener(_onCtrlChanged);
    _syncAutoRefresh(readImmediately: true);
  }

  @override
  void didUpdateWidget(_StatusTab old) {
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
        old.statusType != widget.statusType) {
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
      (_) => _read(showErrors: false, showProgress: false),
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
        !_supportsStatusRead) {
      return;
    }

    final start = int.tryParse(widget.startAddrCtrl.text) ?? 0;
    final rawCount = int.tryParse(widget.countCtrl.text);
    final count = rawCount == null || rawCount < 1 ? 20 : rawCount;

    _reading = true;
    if (showProgress) {
      setState(() => _manualReadInProgress = true);
    }
    try {
      await widget.onRead(
        statusType: widget.statusType,
        startAddress: start,
        count: count,
      );
      if (!mounted) return;
    } catch (error) {
      if (!mounted || !showErrors) return;
      showErrorSnackBar(context, error);
    } finally {
      _reading = false;
      if (mounted && showProgress) {
        setState(() => _manualReadInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final dividerColor = Theme.of(context).dividerTheme.color ?? cs.outline;
    final start = int.tryParse(widget.startAddrCtrl.text) ?? 0;
    final rawCount = int.tryParse(widget.countCtrl.text);
    final count = rawCount == null || rawCount < 1 ? 20 : rawCount;
    final end = start + count - 1;
    final references = {
      for (final e in widget.referenceStatuses(start, count)) e.address: e,
    };
    final configByAddress = {
      for (final e in widget.registerList.statusEntries)
        if (e.statusType == widget.statusType) e.address: e,
    };
    final visibleStatuses = List.generate(count, (i) {
      final address = start + i;
      final reference = references[address];
      final runtime = widget.runtimeValues[(widget.statusType, address)];
      final value =
          runtime?.$1 ?? _manualValues[address] ?? reference?.value ?? false;
      return StatusEntry(
        address: address,
        value: value,
        previousValue: runtime?.$2 ?? reference?.previousValue,
        comment: configByAddress[address]?.comment ?? reference?.comment ?? '',
        timestamp: runtime?.$3 == null
            ? reference?.timestamp
            : _formatTimestamp(runtime!.$3!),
        date: runtime?.$3 == null ? reference?.date : _formatDate(runtime!.$3!),
      );
    });

    return Column(
      children: [
        RegistersTabToolbar(
          leading: widget.listSelector,
          segments: const [
            ButtonSegment(value: '0xxxx', label: Text('0xxxx')),
            ButtonSegment(value: '1xxxx', label: Text('1xxxx')),
          ],
          selectedSegment: widget.statusType,
          onSegmentChanged: widget.onStatusTypeChanged,
          canRead: widget.canRead,
          supportsRead: _supportsStatusRead,
          readInProgress: _manualReadInProgress,
          onRead: _read,
        ),
        RegistersRangeControls(
          startAddrCtrl: widget.startAddrCtrl,
          countCtrl: widget.countCtrl,
          maxCount: 2000,
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
            itemCount: visibleStatuses.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: dividerColor),
            itemBuilder: (context, i) => StatusRow(
              entry: visibleStatuses[i],
              canWrite: _canWrite,
              onEntryChanged: widget.onEntryChanged,
              onChanged: _canWrite
                  ? (value) => setState(() {
                      _manualValues[visibleStatuses[i].address] = value;
                    })
                  : null,
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
                _bitRangeLabel(l10n, start, end),
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
