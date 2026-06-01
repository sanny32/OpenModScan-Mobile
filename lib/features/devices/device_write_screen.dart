import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../models/app_settings.dart';
import '../../models/device_info.dart';
import '../../models/register_address_type.dart';
import '../../models/register_entry.dart';
import '../../utils/modbus_format.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/connection_info_bar.dart';
import '../../widgets/data_layout.dart';
import '../../widgets/error_feedback.dart';
import '../../widgets/section_card.dart';
import '../../widgets/segmented_button_style.dart';
import 'devices_controller.dart';

enum _WriteMode { register, coil }

class DeviceWriteScreen extends StatefulWidget {
  final String deviceId;
  final DevicesController controller;

  const DeviceWriteScreen({
    super.key,
    required this.deviceId,
    required this.controller,
  });

  @override
  State<DeviceWriteScreen> createState() => _DeviceWriteScreenState();
}

class _DeviceWriteScreenState extends State<DeviceWriteScreen> {
  late DeviceInfo _device;
  final _addressCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  var _mode = _WriteMode.register;
  var _typeName = 'UInt16';
  late String _registerOrder;
  late String _byteOrder;
  var _coilValue = false;
  var _writing = false;
  String? _addressError;
  String? _valueError;
  RegisterWriteResult? _registerResult;
  CoilWriteResult? _coilResult;

  bool get _connected => widget.controller.isConnected(_device);

  bool get _writeAvailable => _connected && AppSettings.instance.writeEnabled;

  @override
  void initState() {
    super.initState();
    _device = widget.controller.deviceById(widget.deviceId)!;
    _registerOrder = AppSettings.instance.registerOrder;
    _byteOrder = AppSettings.instance.byteOrder;
    _addressCtrl.text = _minAddress.toString();
    _valueCtrl.text = '0';
    _addressCtrl.addListener(_onFormChanged);
    _valueCtrl.addListener(_onFormChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _addressCtrl.removeListener(_onFormChanged);
    _valueCtrl.removeListener(_onFormChanged);
    _addressCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final updated = widget.controller.deviceById(widget.deviceId);
    if (updated != null) setState(() => _device = updated);
  }

  void _onFormChanged() {
    if (_addressError != null || _valueError != null) {
      setState(() {
        _addressError = null;
        _valueError = null;
      });
      return;
    }
    setState(() {});
  }

  RegisterAddressType get _addressType => _mode == _WriteMode.register
      ? RegisterAddressType.holdingRegisters
      : RegisterAddressType.coils;

  // The user enters the bare address (no table prefix), starting at the
  // configured Address Base. The prefix is applied before calling the
  // controller, which expects a display address including the table offset.
  int get _minAddress => AppSettings.instance.addressBaseStart;

  int get _maxAddress => AppSettings.instance.addressBaseStart + 0xffff;

  // Picks the keyboard for the value field based on the selected data type:
  // Hex needs letters, floats need a decimal point and sign, signed integers
  // need a sign, everything else is digits only.
  TextInputType get _valueKeyboardType {
    switch (_typeName) {
      case 'Hex':
        return TextInputType.text;
      case 'Float32':
      case 'Float64':
        return const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        );
      case 'Int16':
      case 'Int32':
      case 'Int64':
        return const TextInputType.numberWithOptions(signed: true);
      default:
        return TextInputType.number;
    }
  }

  int? _parsedAddress() {
    final value = int.tryParse(_addressCtrl.text);
    if (value == null || value < _minAddress || value > _maxAddress) {
      return null;
    }
    return value;
  }

  List<int>? _encodedWords() {
    if (_mode != _WriteMode.register) return null;
    try {
      return encodeRegisterValue(
        _typeName,
        _valueCtrl.text,
        registerOrder: _registerOrder,
        byteOrder: _byteOrder,
      );
    } catch (_) {
      return null;
    }
  }

  bool get _formValid {
    if (!_writeAvailable || _writing || _parsedAddress() == null) return false;
    if (_mode == _WriteMode.coil) return true;
    return _encodedWords() != null;
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final address = _parsedAddress();
    final words = _encodedWords();

    if (address == null) {
      setState(() => _addressError = l10n.writeAddressRange);
      return;
    }
    if (_mode == _WriteMode.register && words == null) {
      setState(() => _valueError = l10n.writeInvalidValue);
      return;
    }

    final confirmed = await _confirmWrite(address, words);
    if (confirmed != true || !mounted) return;

    final displayAddress = address + _addressType.displayOffset;

    setState(() => _writing = true);
    try {
      if (_mode == _WriteMode.register) {
        final result = await widget.controller.writeRegisterValue(
          _device,
          address: displayAddress,
          typeName: _typeName,
          value: _valueCtrl.text,
          registerOrder: _registerOrder,
          byteOrder: _byteOrder,
        );
        if (!mounted) return;
        setState(() {
          _registerResult = result;
          _coilResult = null;
        });
      } else {
        final result = await widget.controller.writeCoilValue(
          _device,
          address: displayAddress,
          value: _coilValue,
        );
        if (!mounted) return;
        setState(() {
          _coilResult = result;
          _registerResult = null;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.writeSuccess)));
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<bool?> _confirmWrite(int address, List<int>? words) {
    final l10n = context.l10n;
    final isRegister = _mode == _WriteMode.register;
    final valueLabel = isRegister
        ? _valueCtrl.text.trim()
        : (_coilValue ? l10n.writeOn : l10n.writeOff);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.writeConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRegister
                  ? l10n.writeRegisterConfirm(_typeName, address, valueLabel)
                  : l10n.writeCoilConfirmDetailed(address, valueLabel),
            ),
            if (isRegister && words != null) ...[
              const SizedBox(height: 12),
              Text(
                '${l10n.writeRawWords}: ${_formatWords(words)}',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.btnWrite),
          ),
        ],
      ),
    );
  }

  void _setMode(_WriteMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _addressError = null;
      _valueError = null;
      _registerResult = null;
      _coilResult = null;
    });
    _addressCtrl.text = _minAddress.toString();
  }

  Future<void> _showDataLayoutSheet() {
    return showDataLayoutSheet(
      context,
      registerOrder: _registerOrder,
      byteOrder: _byteOrder,
      onRegisterOrder: (value) => setState(() {
        _registerOrder = value;
        _registerResult = null;
      }),
      onByteOrder: (value) => setState(() {
        _byteOrder = value;
        _registerResult = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final words = _encodedWords();
    final isRegister = _mode == _WriteMode.register;

    return Scaffold(
      backgroundColor: cs.surfaceContainerHighest,
      appBar: AppBar(
        toolbarHeight: 56,
        title: Text(
          l10n.writeValue,
          style: tt.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.icon(
              onPressed: _formValid ? _submit : null,
              icon: _writing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_outlined),
              label: Text(l10n.btnWrite),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                minimumSize: const Size(double.infinity, 52),
                textStyle: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
        children: [
          ConnectionInfoBar(device: _device, showDeviceName: true),
          if (!AppSettings.instance.writeEnabled) ...[
            const SizedBox(height: 14),
            _StatusBanner(
              icon: Icons.lock_outline,
              color: cs.error,
              text: l10n.writeDisabled,
            ),
          ],
          const SizedBox(height: 16),
          SegmentedButton<_WriteMode>(
            style: appSegmentedButtonStyle(context),
            segments: [
              ButtonSegment(
                value: _WriteMode.register,
                label: Text(l10n.writeModeRegister),
              ),
              ButtonSegment(
                value: _WriteMode.coil,
                label: Text(l10n.writeModeCoil),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => _setMode(selection.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  isRegister ? l10n.writeModeRegister : l10n.writeModeCoil,
                ),
              ),
              if (isRegister)
                DataLayoutChip(
                  registerOrder: _registerOrder,
                  byteOrder: _byteOrder,
                  onTap: _showDataLayoutSheet,
                ),
            ],
          ),
          const SizedBox(height: 7),
          OutlinedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isRegister) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _typeName,
                    decoration: InputDecoration(labelText: l10n.writeDataType),
                    dropdownColor: cs.surface,
                    items: [
                      for (final type in kRegisterTypes)
                        DropdownMenuItem(value: type, child: Text(type)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _typeName = value;
                        _valueError = null;
                        _registerResult = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _addressCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.colAddress,
                    errorText: _addressError,
                  ),
                ),
                if (isRegister) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _valueCtrl,
                    keyboardType: _valueKeyboardType,
                    decoration: InputDecoration(
                      labelText: l10n.colValue,
                      errorText: _valueError,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: cs.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '${l10n.writeRawWords}:',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          words == null ? '—' : _formatWords(words),
                          textAlign: TextAlign.right,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        _coilValue ? l10n.writeOn : l10n.writeOff,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      AppSwitch(
                        value: _coilValue,
                        onChanged: (value) =>
                            setState(() => _coilValue = value),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!_connected) ...[
            const SizedBox(height: 18),
            Text(
              l10n.deviceNotConnected(_device.name),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (_registerResult != null || _coilResult != null) ...[
            const SizedBox(height: 18),
            SectionHeader(l10n.writeResult),
            const SizedBox(height: 7),
            _ResultSection(
              registerResult: _registerResult,
              coilResult: _coilResult,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: tt.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultSection extends StatelessWidget {
  final RegisterWriteResult? registerResult;
  final CoilWriteResult? coilResult;

  const _ResultSection({this.registerResult, this.coilResult});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final register = registerResult;
    final coil = coilResult;

    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (register != null) ...[
            Text('${l10n.writeActualValue}: ${register.displayValue}'),
            const SizedBox(height: 4),
            Text(
              '${l10n.writeRawWords}: ${_formatWords(register.readBackWords)}',
            ),
            if (register.usedFallback) ...[
              const SizedBox(height: 8),
              Text(
                l10n.writeFallbackUsed,
                style: tt.bodyMedium?.copyWith(
                  color: cs.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
          if (coil != null)
            Text(
              '${l10n.writeActualValue}: '
              '${coil.value ? l10n.writeOn : l10n.writeOff}',
            ),
        ],
      ),
    );
  }
}

String _formatWords(List<int> words) => words
    .map((word) => '0x${word.toRadixString(16).toUpperCase().padLeft(4, '0')}')
    .join(', ');
