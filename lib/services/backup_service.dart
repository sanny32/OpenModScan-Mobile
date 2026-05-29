import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_settings.dart';
import '../models/device_info.dart';
import 'device_repository.dart';

/// Outcome of an export/import operation, so the UI can show the right message.
enum BackupResult { success, cancelled, failure }

/// Writes [bytes] to a user-chosen location, returning the path or `null` when
/// the dialog is dismissed.
typedef BackupWriter =
    Future<String?> Function({
      String? dialogTitle,
      required String fileName,
      required Uint8List bytes,
    });

/// Reads the bytes of a user-chosen file, returning `null` when the dialog is
/// dismissed.
typedef BackupReader = Future<Uint8List?> Function({String? dialogTitle});

/// Exports/imports application settings together with saved devices and their
/// register lists as a single JSON file.
///
/// Reuses the existing JSON serialization: [AppSettings.toJson]/[applyJson] and
/// [DeviceInfo.toJson]/[fromJson]. File I/O is injected so the policy can be
/// unit-tested without the platform file picker; production defaults route
/// through [FilePicker].
class BackupService {
  static const _version = 1;
  static const _fileName = 'openmodscan-backup.json';

  final AppSettings _settings;
  final DeviceRepositoryPort _repository;
  final BackupWriter _writer;
  final BackupReader _reader;

  BackupService({
    AppSettings? settings,
    DeviceRepositoryPort? repository,
    BackupWriter? writer,
    BackupReader? reader,
  }) : _settings = settings ?? AppSettings.instance,
       _repository = repository ?? DeviceRepository.instance,
       _writer = writer ?? _saveWithPicker,
       _reader = reader ?? _pickWithPicker;

  Future<BackupResult> export({String? dialogTitle}) async {
    try {
      final payload = <String, dynamic>{
        'version': _version,
        'settings': _settings.toJson(),
        'devices': _repository.snapshot
            .map((device) => device.toJson())
            .toList(),
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      final path = await _writer(
        dialogTitle: dialogTitle,
        fileName: _fileName,
        bytes: bytes,
      );
      return path == null ? BackupResult.cancelled : BackupResult.success;
    } catch (_) {
      return BackupResult.failure;
    }
  }

  Future<BackupResult> import({String? dialogTitle}) async {
    try {
      final bytes = await _reader(dialogTitle: dialogTitle);
      if (bytes == null) return BackupResult.cancelled;

      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return BackupResult.failure;
      if (decoded['version'] != _version) return BackupResult.failure;

      final settingsJson = decoded['settings'];
      if (settingsJson is Map<String, dynamic>) {
        await _settings.applyJson(settingsJson);
      }
      final devicesJson = decoded['devices'];
      if (devicesJson is List) {
        final devices = devicesJson
            .whereType<Map<String, dynamic>>()
            .map(DeviceInfo.fromJson)
            .toList();
        await _repository.replaceAll(devices);
      }
      return BackupResult.success;
    } catch (_) {
      return BackupResult.failure;
    }
  }

  /// Writes [bytes] to a temp file and hands it to the system share sheet so
  /// the user can save it (e.g. to Files) or send it elsewhere. Returns the
  /// temp path on completion, or `null` when the sheet was dismissed.
  static Future<String?> _saveWithPicker({
    String? dialogTitle,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final dir = await Directory.systemTemp.createTemp('omodscan_backup');
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: dialogTitle,
        fileNameOverrides: [fileName],
      ),
    );
    return result.status == ShareResultStatus.dismissed ? null : file.path;
  }

  static Future<Uint8List?> _pickWithPicker({String? dialogTitle}) async {
    const typeGroup = XTypeGroup(
      label: 'Backup',
      extensions: ['json'],
      mimeTypes: ['application/json', 'text/plain'],
      uniformTypeIdentifiers: ['public.json', 'public.plain-text', 'public.data'],
    );
    final file = await openFile(
      acceptedTypeGroups: const [typeGroup],
      confirmButtonText: dialogTitle,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }
}
