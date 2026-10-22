import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_recording_service.dart';

class PendingUpload {
  const PendingUpload({
    required this.matchId,
    required this.sequence,
    required this.startedAt,
    required this.duration,
    required this.localPath,
  });

  final String matchId;
  final int sequence;
  final DateTime startedAt;
  final Duration duration;
  final String localPath;

  RecordingChunkFile toRecordingChunk() => RecordingChunkFile(
    file: XFile(localPath),
    sequence: sequence,
    startedAt: startedAt,
    duration: duration,
  );

  Map<String, Object> toJson() => {
    'matchId': matchId,
    'sequence': sequence,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'localPath': localPath,
  };

  static PendingUpload? fromJson(Object? value) {
    if (value is! Map) return null;
    final matchId = value['matchId'];
    final sequence = value['sequence'];
    final startedAt = value['startedAt'];
    final durationSeconds = value['durationSeconds'];
    final localPath = value['localPath'];
    if (matchId is! String ||
        sequence is! int ||
        startedAt is! String ||
        durationSeconds is! int ||
        localPath is! String) {
      return null;
    }
    final parsedDate = DateTime.tryParse(startedAt);
    if (parsedDate == null) return null;
    return PendingUpload(
      matchId: matchId,
      sequence: sequence,
      startedAt: parsedDate,
      duration: Duration(seconds: durationSeconds),
      localPath: localPath,
    );
  }
}

abstract interface class UploadQueueStore {
  Future<List<PendingUpload>> load();

  Future<void> upsert(PendingUpload upload);

  Future<void> remove({required String matchId, required int sequence});
}

class FileUploadQueueStore implements UploadQueueStore {
  static const _fileName = 'rally_pending_uploads.json';

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }

  @override
  Future<List<PendingUpload>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return decoded
          .map(PendingUpload.fromJson)
          .whereType<PendingUpload>()
          .toList();
    } on FormatException {
      return [];
    } on FileSystemException {
      return [];
    } catch (_) {
      // Platform storage is unavailable in desktop/unit-test environments.
      return [];
    }
  }

  @override
  Future<void> upsert(PendingUpload upload) async {
    final uploads = await load();
    final index = uploads.indexWhere(
      (item) =>
          item.matchId == upload.matchId && item.sequence == upload.sequence,
    );
    if (index == -1) {
      uploads.add(upload);
    } else {
      uploads[index] = upload;
    }
    await _write(uploads);
  }

  @override
  Future<void> remove({required String matchId, required int sequence}) async {
    final uploads = await load();
    uploads.removeWhere(
      (item) => item.matchId == matchId && item.sequence == sequence,
    );
    await _write(uploads);
  }

  Future<void> _write(List<PendingUpload> uploads) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(uploads.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }
}
