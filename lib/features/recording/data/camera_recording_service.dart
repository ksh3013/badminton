import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'recording_foreground_bridge.dart';

class RecordingChunkFile {
  const RecordingChunkFile({
    required this.file,
    required this.sequence,
    required this.startedAt,
    required this.duration,
  });

  final XFile file;
  final int sequence;
  final DateTime startedAt;
  final Duration duration;
}

class CameraRecordingService extends ChangeNotifier {
  CameraRecordingService({
    this.onChunk,
    this.onChunkError,
    RecordingForegroundBridge? foreground,
  }) : _foreground = foreground ?? RecordingForegroundBridge();

  final Future<void> Function(RecordingChunkFile chunk)? onChunk;
  final void Function(Object error)? onChunkError;
  final RecordingForegroundBridge _foreground;
  CameraController? controller;
  CameraDescription? camera;
  Timer? _segmentTimer;
  DateTime? _segmentStartedAt;
  DateTime? _resumedAt;
  Duration _segmentDuration = Duration.zero;
  Duration _elapsed = Duration.zero;
  int _sequence = 0;
  Future<RecordingChunkFile?>? _rotationTask;

  static const segmentLength = Duration(minutes: 1);

  bool get isInitialized => controller?.value.isInitialized == true;
  bool get isRecording => controller?.value.isRecordingVideo == true;
  bool get isPaused => controller?.value.isRecordingPaused == true;
  Duration get elapsed => _elapsed;

  Future<void> initialize() async {
    if (isInitialized) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('사용할 수 있는 카메라가 없습니다.');
    camera = cameras.firstWhere(
      (item) => item.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    controller = CameraController(
      camera!,
      ResolutionPreset.high,
      enableAudio: true,
    );
    await controller!.initialize();
    notifyListeners();
  }

  Future<void> start({bool manageForeground = true}) async {
    if (!isInitialized) await initialize();
    if (isRecording) return;
    _segmentStartedAt = DateTime.now();
    _segmentDuration = Duration.zero;
    if (manageForeground) await _foreground.start();
    try {
      await controller!.startVideoRecording();
    } catch (_) {
      if (manageForeground) await _foreground.stop();
      rethrow;
    }
    _resumedAt = DateTime.now();
    _segmentTimer?.cancel();
    _segmentTimer = Timer.periodic(segmentLength, (_) => _rotateSegment());
    notifyListeners();
  }

  Future<void> pause() async {
    if (!isRecording) return;
    await controller!.pauseVideoRecording();
    final resumedAt = _resumedAt;
    if (resumedAt != null) {
      _segmentDuration += DateTime.now().difference(resumedAt);
      _resumedAt = null;
    }
    notifyListeners();
  }

  Future<void> resume() async {
    if (!isPaused) return;
    await controller!.resumeVideoRecording();
    _resumedAt = DateTime.now();
    notifyListeners();
  }

  Future<RecordingChunkFile?> stop({
    bool waitForRotation = true,
    bool stopForeground = true,
  }) async {
    if (waitForRotation) await _rotationTask;
    if (!isRecording && !isPaused) return null;
    _segmentTimer?.cancel();
    _segmentTimer = null;
    final startedAt = _segmentStartedAt ?? DateTime.now();
    final resumedAt = _resumedAt;
    if (resumedAt != null) {
      _segmentDuration += DateTime.now().difference(resumedAt);
    }
    final recordedFile = await controller!.stopVideoRecording();
    final file = await _persistChunk(recordedFile, _sequence);
    if (stopForeground) await _foreground.stop();
    final duration = _segmentDuration;
    _elapsed += duration;
    _segmentStartedAt = null;
    _resumedAt = null;
    _segmentDuration = Duration.zero;
    notifyListeners();
    return RecordingChunkFile(
      file: file,
      sequence: _sequence++,
      startedAt: startedAt,
      duration: duration,
    );
  }

  Future<RecordingChunkFile?> _rotateSegment() async {
    if (_rotationTask != null || !isRecording) return null;
    final task = _performRotation();
    _rotationTask = task;
    task.whenComplete(() {
      if (identical(_rotationTask, task)) _rotationTask = null;
    });
    return task;
  }

  Future<RecordingChunkFile?> _performRotation() async {
    // Keep the foreground service alive across segment boundaries. Restarting
    // it while the app is backgrounded is rejected on newer Android versions.
    final finished = await stop(waitForRotation: false, stopForeground: false);
    Object? restartError;
    try {
      await start(manageForeground: false);
    } catch (error) {
      restartError = error;
    }
    await _deliverChunk(finished);
    if (restartError != null) {
      onChunkError?.call(restartError);
    }
    return finished;
  }

  Future<void> _deliverChunk(RecordingChunkFile? chunk) async {
    if (chunk == null) return;
    try {
      await onChunk?.call(chunk);
    } catch (error) {
      onChunkError?.call(error);
    }
  }

  Future<XFile> _persistChunk(XFile source, int sequence) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final targetDirectory = Directory('${directory.path}/rally_recordings');
      await targetDirectory.create(recursive: true);
      final target = File(
        '${targetDirectory.path}/${DateTime.now().microsecondsSinceEpoch}_$sequence.mp4',
      );
      await File(source.path).copy(target.path);
      if (source.path != target.path) {
        try {
          await File(source.path).delete();
        } on FileSystemException {
          // The camera plugin may already have moved or cleaned its temp file.
        }
      }
      return XFile(target.path);
    } on Object {
      // Keep the camera plugin path as a last-resort pending source.
      return source;
    }
  }

  @override
  void dispose() {
    _segmentTimer?.cancel();
    unawaited(_foreground.stop());
    controller?.dispose();
    super.dispose();
  }
}
