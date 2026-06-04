import 'package:flutter/widgets.dart';

/// Stable widget keys for high-value interactions covered by widget tests.
class AppTestKeys {
  const AppTestKeys._();

  static const scanNetworkButton = ValueKey('scan.network.button');
  static const scanSheetActionButton = ValueKey('scan.sheet.action.button');
  static const deviceFormNameField = ValueKey('device.form.name.field');
  static const deviceFormSaveButton = ValueKey('device.form.save.button');
  static const deviceWriteSubmitButton = ValueKey('device.write.submit.button');
  static const deviceWriteConfirmButton = ValueKey(
    'device.write.confirm.button',
  );
  static const registerCommentField = ValueKey('register.comment.field');
  static const registerCommentSaveButton = ValueKey(
    'register.comment.save.button',
  );
}
