import 'package:flutter/material.dart';
import '../models/device_info.dart';
import '../models/log_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_info_bar.dart';
import '../widgets/connection_status_chip.dart';

enum _LogFilter { all, tx, rx, errors }

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  _LogFilter _filter = _LogFilter.all;
  bool _autoScroll = true;
  bool _clearOnDisconnect = false;

  List<LogEntry> get _filtered {
    switch (_filter) {
      case _LogFilter.all:
        return mockLogEntries;
      case _LogFilter.tx:
        return mockLogEntries
            .where((e) => e.direction == LogDirection.tx)
            .toList();
      case _LogFilter.rx:
        return mockLogEntries
            .where((e) => e.direction == LogDirection.rx)
            .toList();
      case _LogFilter.errors:
        return mockLogEntries
            .where((e) => e.type == LogEntryType.error)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    const device = mockDevice;
    final entries = _filtered;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Log',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            ConnectionStatusChip(connected: device.connected),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.delete_outline), onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          ConnectionInfoBar(device: device),
          // Filter bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _FilterBtn(
                    label: 'All',
                    selected: _filter == _LogFilter.all,
                    onTap: () => setState(() => _filter = _LogFilter.all)),
                const SizedBox(width: 6),
                _FilterBtn(
                    label: 'TX',
                    icon: Icons.arrow_upward,
                    color: AppTheme.txColor,
                    selected: _filter == _LogFilter.tx,
                    onTap: () => setState(() => _filter = _LogFilter.tx)),
                const SizedBox(width: 6),
                _FilterBtn(
                    label: 'RX',
                    icon: Icons.arrow_downward,
                    color: AppTheme.rxColor,
                    selected: _filter == _LogFilter.rx,
                    onTap: () => setState(() => _filter = _LogFilter.rx)),
                const SizedBox(width: 6),
                _FilterBtn(
                    label: 'Errors',
                    icon: Icons.warning_amber_outlined,
                    color: Colors.orange,
                    selected: _filter == _LogFilter.errors,
                    onTap: () =>
                        setState(() => _filter = _LogFilter.errors)),
                const Spacer(),
                const Text('Auto scroll',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _autoScroll,
                    onChanged: (v) => setState(() => _autoScroll = v),
                  ),
                ),
              ],
            ),
          ),
          // Column headers
          Container(
            color: const Color(0xFF1A1A1A),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Row(
              children: [
                SizedBox(
                    width: 90,
                    child: Text('Time',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 12))),
                SizedBox(
                    width: 58,
                    child: Text('Direction',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 12))),
                Expanded(
                    child: Text('Function',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 12))),
              ],
            ),
          ),
          const Divider(height: 1),
          // Log entries
          Expanded(
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _LogRow(entry: entries[i]),
            ),
          ),
          // Footer
          Container(
            color: const Color(0xFF1A1A1A),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Messages: 128',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                Row(
                  children: [
                    const Text('Clear on disconnect',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 12)),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: _clearOnDisconnect,
                        onChanged: (v) =>
                            setState(() => _clearOnDisconnect = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterBtn({
    required this.label,
    this.icon,
    this.color = const Color(0xFF1976D2),
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.grey.shade800),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? Colors.white : Colors.grey),
              const SizedBox(width: 3),
            ],
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.grey,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final LogEntry entry;
  const _LogRow({required this.entry});

  Color get _funcColor {
    if (entry.type == LogEntryType.error) return AppTheme.errorColor;
    if (entry.direction == LogDirection.tx) return AppTheme.txColor;
    return AppTheme.rxColor;
  }

  @override
  Widget build(BuildContext context) {
    final isError = entry.type == LogEntryType.error;
    final isTx = entry.direction == LogDirection.tx;
    final dirColor = isError
        ? AppTheme.errorColor
        : isTx
            ? AppTheme.txColor
            : AppTheme.rxColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(entry.time,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 11)),
          ),
          SizedBox(
            width: 58,
            child: entry.direction == null
                ? const SizedBox()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isTx ? 'TX' : 'RX',
                          style: TextStyle(
                              color: dirColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      Icon(
                          isTx
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 12,
                          color: dirColor),
                    ],
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.function,
                    style: TextStyle(
                        color: _funcColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(entry.data,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
