import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../recording/data/camera_recording_service.dart';
import '../../recording/data/upload_queue_store.dart';
import '../data/match_repository.dart';
import '../domain/match.dart';

class MatchController extends ChangeNotifier {
  MatchController(this._dataSource, {UploadQueueStore? uploadQueue})
    : _uploadQueue = uploadQueue ?? FileUploadQueueStore();

  final MatchDataSource _dataSource;
  final UploadQueueStore _uploadQueue;
  final List<MatchData> _matches = [];
  final List<PendingUpload> _pendingUploads = [];
  Duration _playhead = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _error;
  String? _selectedId;
  Timer? _timer;
  Future<void> _uploadTail = Future<void>.value();
  final Set<String> _reservedSequences = <String>{};

  List<MatchData> get matches => List.unmodifiable(_matches);
  MatchData get currentMatch => _matches.firstWhere(
    (match) => match.id == _selectedId,
    orElse: () => _matches.first,
  );
  MatchData get replayMatch => _matches.firstWhere(
    (match) => match.id == _selectedId && match.status == MatchStatus.complete,
    orElse: () => _matches.firstWhere(
      (match) => match.status == MatchStatus.complete,
      orElse: () => _matches.first,
    ),
  );
  Duration get playhead => _playhead;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPendingUploads => _pendingUploads.isNotEmpty;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      _pendingUploads
        ..clear()
        ..addAll(await _uploadQueue.load());
      _matches
        ..clear()
        ..addAll(await _dataSource.loadMatches());
      if (_matches.isNotEmpty) _selectedId = _matches.first.id;
      _error = null;
    } catch (error) {
      _error = '경기 목록을 불러오지 못했어요: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    _ensureTimer();
    unawaited(_retryPersistedUploads());
  }

  Future<void> start() async {
    await _dataSource.updateStatus(currentMatch.id, MatchStatus.recording);
    _replaceCurrent(currentMatch.copyWith(status: MatchStatus.recording));
    _ensureTimer();
  }

  Future<void> togglePause() async {
    final nextStatus = currentMatch.status == MatchStatus.recording
        ? MatchStatus.paused
        : MatchStatus.recording;
    await _dataSource.updateStatus(currentMatch.id, nextStatus);
    _replaceCurrent(currentMatch.copyWith(status: nextStatus));
    _ensureTimer();
  }

  Future<void> end({RecordingChunkFile? finalChunk}) async {
    await _dataSource.updateStatus(currentMatch.id, MatchStatus.uploading);
    _replaceCurrent(currentMatch.copyWith(status: MatchStatus.uploading));
    if (finalChunk != null) await uploadChunk(finalChunk);
    final matchId = currentMatch.id;
    if (_pendingUploads.any((item) => item.matchId == matchId)) {
      notifyListeners();
      return;
    }
    await _dataSource.completeUpload(matchId);
    _replaceCurrent(
      currentMatch.copyWith(status: MatchStatus.complete, uploadProgress: 100),
    );
  }

  Future<void> uploadChunk(RecordingChunkFile chunk) async {
    final sequence = _nextSequence(chunk.sequence);
    final pending = PendingUpload(
      matchId: currentMatch.id,
      sequence: sequence,
      startedAt: chunk.startedAt,
      duration: chunk.duration,
      localPath: chunk.file.path,
    );
    try {
      await _uploadQueue.upsert(pending);
      _upsertPending(pending);
      await _enqueueUpload(pending);
    } catch (_) {
      if (!_pendingUploads.any(
        (item) =>
            item.matchId == pending.matchId &&
            item.sequence == pending.sequence,
      )) {
        _reservedSequences.remove('${pending.matchId}:${pending.sequence}');
      }
      rethrow;
    }
  }

  Future<void> retryPendingUploads() async {
    final matchId = currentMatch.id;
    for (final pending in List<PendingUpload>.from(_pendingUploads)) {
      if (pending.matchId != matchId) continue;
      await _enqueueUpload(pending);
    }
    if (!_pendingUploads.any((item) => item.matchId == matchId)) {
      await _dataSource.completeUpload(matchId);
      _replaceCurrent(
        currentMatch.copyWith(
          status: MatchStatus.complete,
          uploadProgress: 100,
        ),
      );
    }
  }

  Future<void> _retryPersistedUploads() async {
    for (final matchId in _pendingUploads.map((item) => item.matchId).toSet()) {
      final pendingForMatch = _pendingUploads
          .where((item) => item.matchId == matchId)
          .toList();
      for (final pending in pendingForMatch) {
        try {
          await _enqueueUpload(pending);
        } catch (_) {
          return;
        }
      }
      if (!_pendingUploads.any((item) => item.matchId == matchId)) {
        await _dataSource.completeUpload(matchId);
        final match = _matchById(matchId);
        if (match != null) {
          _replaceMatch(
            match.copyWith(status: MatchStatus.complete, uploadProgress: 100),
          );
        }
      }
    }
  }

  Future<MatchData> createMatch({
    required String title,
    required String place,
    required String players,
    required DateTime playedAt,
  }) async {
    final match = await _dataSource.createMatch(
      title: title,
      place: place,
      players: players,
      playedAt: playedAt,
    );
    _matches.insert(0, match);
    _selectedId = match.id;
    notifyListeners();
    return match;
  }

  Future<bool> addMarker() async {
    if (currentMatch.status != MatchStatus.recording) return false;
    await _dataSource.addMarker(currentMatch.id, currentMatch.duration);
    _replaceCurrent(
      currentMatch.copyWith(
        markers: [...currentMatch.markers, currentMatch.duration],
      ),
    );
    return true;
  }

  void togglePlayback() {
    _isPlaying = !_isPlaying;
    _ensureTimer();
    notifyListeners();
  }

  void seek(Duration position) {
    _playhead = position < Duration.zero
        ? Duration.zero
        : position > replayMatch.duration
        ? replayMatch.duration
        : position;
    notifyListeners();
  }

  void seekToMarker(Duration marker) => seek(marker);

  void selectMatch(MatchData match) {
    _selectedId = match.id;
    _playhead = Duration.zero;
    notifyListeners();
  }

  Future<void> _uploadPending(PendingUpload pending) async {
    try {
      await _dataSource.updateChunkStatus(
        matchId: pending.matchId,
        sequence: pending.sequence,
        startedAt: pending.startedAt,
        duration: pending.duration,
        localPath: pending.localPath,
        status: ChunkUploadStatus.uploading,
      );
      _setChunkStatus(pending, ChunkUploadStatus.uploading);
      final uploaded = await _dataSource.uploadChunk(
        matchId: pending.matchId,
        sequence: pending.sequence,
        startedAt: pending.startedAt,
        duration: pending.duration,
        localPath: pending.localPath,
      );
      await _uploadQueue.remove(
        matchId: pending.matchId,
        sequence: pending.sequence,
      );
      _pendingUploads.removeWhere(
        (item) =>
            item.matchId == pending.matchId &&
            item.sequence == pending.sequence,
      );
      final match = _matchById(pending.matchId);
      if (match == null) return;
      final alreadyPresent = match.chunks.any(
        (chunk) => chunk.sequence == uploaded.sequence,
      );
      final chunkDuration = match.chunks.fold<Duration>(
        Duration.zero,
        (sum, chunk) => sum + chunk.duration,
      );
      final candidateDuration = chunkDuration + pending.duration;
      final updatedDuration =
          alreadyPresent || match.duration >= candidateDuration
          ? match.duration
          : candidateDuration;
      final progress = match.uploadProgress < 95
          ? match.uploadProgress + 5
          : match.uploadProgress;
      await _dataSource.updateUploadProgress(pending.matchId, progress);
      await _dataSource.updateDuration(pending.matchId, updatedDuration);
      final nextChunks = alreadyPresent
          ? [
              for (final chunk in match.chunks)
                if (chunk.sequence == uploaded.sequence) uploaded else chunk,
            ]
          : [...match.chunks, uploaded];
      _replaceMatch(
        match.copyWith(
          duration: updatedDuration,
          uploadProgress: progress,
          chunks: nextChunks,
        ),
      );
    } catch (_) {
      try {
        await _dataSource.updateChunkStatus(
          matchId: pending.matchId,
          sequence: pending.sequence,
          startedAt: pending.startedAt,
          duration: pending.duration,
          localPath: pending.localPath,
          status: ChunkUploadStatus.failed,
        );
      } catch (_) {
        // Preserve the local queue even if the status update also failed.
      }
      _setChunkStatus(pending, ChunkUploadStatus.failed);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _enqueueUpload(PendingUpload pending) {
    final task = _uploadTail.then((_) => _uploadPending(pending));
    _uploadTail = task.catchError((_) {});
    return task;
  }

  int _nextSequence(int requested) {
    final occupied = <int>{
      ...currentMatch.chunks.map((chunk) => chunk.sequence),
      ..._pendingUploads
          .where((item) => item.matchId == currentMatch.id)
          .map((item) => item.sequence),
    };
    occupied.addAll(
      _reservedSequences
          .where((key) => key.startsWith('${currentMatch.id}:'))
          .map((key) => int.parse(key.split(':').last)),
    );
    if (!occupied.contains(requested)) {
      _reservedSequences.add('${currentMatch.id}:$requested');
      return requested;
    }
    var next = occupied.isEmpty
        ? 0
        : occupied.reduce((a, b) => a > b ? a : b) + 1;
    while (occupied.contains(next)) {
      next++;
    }
    _reservedSequences.add('${currentMatch.id}:$next');
    return next;
  }

  void _setChunkStatus(PendingUpload pending, ChunkUploadStatus status) {
    final match = _matchById(pending.matchId);
    if (match == null) return;
    final index = match.chunks.indexWhere(
      (chunk) => chunk.sequence == pending.sequence,
    );
    final next = MatchChunk(
      id: index == -1 ? 'local-${pending.sequence}' : match.chunks[index].id,
      sequence: pending.sequence,
      startedAt: pending.startedAt,
      duration: pending.duration,
      localPath: pending.localPath,
      storagePath: index == -1 ? null : match.chunks[index].storagePath,
      url: index == -1 ? null : match.chunks[index].url,
      uploadStatus: status,
    );
    final chunks = [...match.chunks];
    if (index == -1) {
      chunks.add(next);
    } else {
      chunks[index] = next;
    }
    // A recording can upload completed segments while the next segment is
    // still being recorded. Chunk status must not change the match lifecycle.
    _replaceMatch(match.copyWith(chunks: chunks));
  }

  MatchData? _matchById(String id) {
    for (final match in _matches) {
      if (match.id == id) return match;
    }
    return null;
  }

  void _upsertPending(PendingUpload pending) {
    final index = _pendingUploads.indexWhere(
      (item) =>
          item.matchId == pending.matchId && item.sequence == pending.sequence,
    );
    if (index == -1) {
      _pendingUploads.add(pending);
    } else {
      _pendingUploads[index] = pending;
    }
  }

  void _replaceCurrent(MatchData match) => _replaceMatch(match);

  void _replaceMatch(MatchData match) {
    final index = _matches.indexWhere((item) => item.id == match.id);
    if (index >= 0) _matches[index] = match;
    notifyListeners();
  }

  void _ensureTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      var changed = false;
      if (_matches.isNotEmpty && currentMatch.status == MatchStatus.recording) {
        _replaceCurrent(
          currentMatch.copyWith(
            duration: currentMatch.duration + const Duration(seconds: 1),
          ),
        );
        changed = true;
      }
      if (_isPlaying && _matches.isNotEmpty) {
        _playhead += const Duration(seconds: 1);
        if (_playhead >= replayMatch.duration) {
          _playhead = Duration.zero;
          _isPlaying = false;
        }
        changed = true;
      }
      if (changed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
