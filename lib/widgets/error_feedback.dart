import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/modbus_client.dart';

class ErrorFeedbackMessage {
  final String title;
  final String body;

  const ErrorFeedbackMessage({required this.title, required this.body});
}

ErrorFeedbackMessage errorFeedbackMessage(BuildContext context, Object error) {
  final l10n = context.l10n;
  final rawMessage = _rawErrorMessage(error);
  final lowerMessage = rawMessage.toLowerCase();

  if (lowerMessage.startsWith('could not connect to ')) {
    final address = rawMessage
        .substring('Could not connect to '.length)
        .replaceAll(RegExp(r'\.$'), '')
        .trim();
    final hasReadableAddress = address.isNotEmpty && !address.startsWith(':');

    return ErrorFeedbackMessage(
      title: l10n.errorConnectionTitle,
      body: hasReadableAddress
          ? l10n.errorConnectionBody(address)
          : l10n.errorConnectionBodyUnknown,
    );
  }

  if (error is ModbusClientException && error.exceptionCode != null) {
    return ErrorFeedbackMessage(
      title: l10n.errorModbusTitle,
      body: l10n.errorModbusBody(rawMessage),
    );
  }

  if (lowerMessage.contains('not connected')) {
    return ErrorFeedbackMessage(
      title: l10n.errorNotConnectedTitle,
      body: l10n.errorNotConnectedBody,
    );
  }

  return ErrorFeedbackMessage(title: l10n.errorGenericTitle, body: rawMessage);
}

void showErrorSnackBar(BuildContext context, Object error) {
  final message = errorFeedbackMessage(context, error);
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final tt = theme.textTheme;

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: cs.errorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: cs.error.withAlpha(70)),
        ),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.title,
                    style: tt.titleSmall?.copyWith(color: cs.onErrorContainer),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.body,
                    style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
}

String _rawErrorMessage(Object error) {
  if (error is ModbusClientException) return error.message;

  final raw = error.toString();
  const prefixes = [
    'Exception: ',
    'StateError: ',
    'Unsupported operation: ',
    'SocketException: ',
  ];
  for (final prefix in prefixes) {
    if (raw.startsWith(prefix)) return raw.substring(prefix.length);
  }
  return raw;
}
