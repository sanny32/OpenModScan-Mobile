part of 'registers_screen.dart';

int _regTypeOffset(String regType) =>
    RegisterAddressType.fromCode(regType).displayOffset;

String _formatTimestamp(DateTime value) => formatModbusTime(value);

String _formatDate(DateTime value) => formatModbusDate(value);

String _bitRangeLabel(AppLocalizations l10n, int start, int end) {
  final raw = l10n.registersShowing(start, end);
  final startText = '$start';
  final endText = '$end';
  final startIndex = raw.indexOf(startText);
  final endIndex = raw.lastIndexOf(endText);
  if (startIndex < 0 || endIndex < 0) return raw;

  final withEnd = raw.replaceRange(
    endIndex,
    endIndex + endText.length,
    end.toString().padLeft(5, '0'),
  );
  final adjustedStartIndex = startIndex > endIndex
      ? startIndex + 5 - endText.length
      : startIndex;
  return withEnd.replaceRange(
    adjustedStartIndex,
    adjustedStartIndex + startText.length,
    start.toString().padLeft(5, '0'),
  );
}
