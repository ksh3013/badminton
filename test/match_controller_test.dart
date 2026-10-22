import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';

import 'package:badmintonmatchrecord/features/matches/data/match_repository.dart';
import 'package:badmintonmatchrecord/features/matches/domain/match.dart';
import 'package:badmintonmatchrecord/features/matches/presentation/match_controller.dart';
import 'package:badmintonmatchrecord/features/recording/data/camera_recording_service.dart';
import 'package:badmintonmatchrecord/features/recording/data/upload_queue_store.dart';

void main() {
  test('creates a match and persists recording state changes', () async {
    final source = FakeMatchDataSource();
    final controller = MatchController(source);
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.matches, hasLength(1));

    await controller.start();
    expect(controller.currentMatch.status, MatchStatus.recording);
    expect(await controller.addMarker(), isTrue);
    expect(controller.currentMatch.markers, hasLength(1));

    await controller.togglePause();
    expect(controller.currentMatch.status, MatchStatus.paused);
    await controller.end();
    expect(controller.currentMatch.status, MatchStatus.complete);
    expect(source.statuses, contains(MatchStatus.complete));
  });

  test('selects a created match and clamps replay seek position', () async {
    final controller = MatchController(FakeMatchDataSource());
    addTearDown(controller.dispose);
    await controller.initialize();

    final created = await controller.createMatch(
      title: '테스트 경기',
      place: '테스트 코트',
      players: 'A · B',
      playedAt: DateTime(2026, 10, 14),
    );
    controller.selectMatch(created);
    expect(controller.currentMatch.title, '테스트 경기');

    controller.seek(const Duration(hours: 1));
    expect(controller.playhead, Duration.zero);
  });

  test('seeks replay playhead to a selected marker', () async {
    final source = FakeMatchDataSource(
      initialMatch: const MatchData(
        id: 'replay',
        title: '리플레이 경기',
        place: '코트',
        players: 'A · B',
        duration: Duration(minutes: 2),
        status: MatchStatus.complete,
        uploadProgress: 100,
        markers: [Duration(seconds: 45)],
      ),
    );
    final controller = MatchController(source);
    addTearDown(controller.dispose);

    await controller.initialize();
    controller.seekToMarker(const Duration(seconds: 45));

    expect(controller.playhead, const Duration(seconds: 45));
  });

  test(
    'keeps failed chunks across controller recreation and retries them',
    () async {
      final source = FakeMatchDataSource()..failUploads = true;
      final queue = MemoryUploadQueueStore();
      final first = MatchController(source, uploadQueue: queue);
      await first.initialize();
      await first.start();

      await expectLater(
        first.uploadChunk(
          RecordingChunkFile(
            file: XFile('/tmp/rally-chunk-0.mp4'),
            sequence: 0,
            startedAt: DateTime(2026, 10, 14),
            duration: const Duration(seconds: 30),
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(first.hasPendingUploads, isTrue);
      expect(
        first.currentMatch.chunks.single.uploadStatus,
        ChunkUploadStatus.failed,
      );
      first.dispose();

      source.failUploads = false;
      final second = MatchController(source, uploadQueue: queue);
      addTearDown(second.dispose);
      await second.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(second.hasPendingUploads, isFalse);
      expect(source.uploadedSequences, [0]);
    },
  );

  test(
    'does not double count timer duration when a chunk is uploaded',
    () async {
      final source = FakeMatchDataSource();
      final controller = MatchController(
        source,
        uploadQueue: MemoryUploadQueueStore(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.start();

      await controller.uploadChunk(
        RecordingChunkFile(
          file: XFile('/tmp/rally-chunk-1.mp4'),
          sequence: 1,
          startedAt: DateTime(2026, 10, 14),
          duration: const Duration(seconds: 30),
        ),
      );

      expect(controller.currentMatch.duration, const Duration(minutes: 2));
      expect(source.durationUpdates.last, const Duration(minutes: 2));
    },
  );

  test('keeps recording state while a completed segment uploads', () async {
    final controller = MatchController(
      FakeMatchDataSource(),
      uploadQueue: MemoryUploadQueueStore(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.start();

    await controller.uploadChunk(
      RecordingChunkFile(
        file: XFile('/tmp/rally-live-chunk.mp4'),
        sequence: 0,
        startedAt: DateTime(2026, 10, 14),
        duration: const Duration(seconds: 30),
      ),
    );

    expect(controller.currentMatch.status, MatchStatus.recording);
    expect(
      controller.currentMatch.chunks.single.uploadStatus,
      ChunkUploadStatus.uploaded,
    );
  });

  test(
    'reserves unique sequence numbers for overlapping chunk callbacks',
    () async {
      final source = FakeMatchDataSource()
        ..uploadDelay = const Duration(milliseconds: 10);
      final controller = MatchController(
        source,
        uploadQueue: MemoryUploadQueueStore(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.start();

      await Future.wait([
        controller.uploadChunk(
          RecordingChunkFile(
            file: XFile('/tmp/rally-overlap-a.mp4'),
            sequence: 0,
            startedAt: DateTime(2026, 10, 14),
            duration: const Duration(seconds: 10),
          ),
        ),
        controller.uploadChunk(
          RecordingChunkFile(
            file: XFile('/tmp/rally-overlap-b.mp4'),
            sequence: 0,
            startedAt: DateTime(2026, 10, 14, 0, 1),
            duration: const Duration(seconds: 10),
          ),
        ),
      ]);

      expect(source.uploadedSequences, [0, 1]);
    },
  );

  test(
    'keeps a failed chunk when its uploading status cannot be persisted',
    () async {
      final source = FakeMatchDataSource()..failStatusUpdates = true;
      final queue = MemoryUploadQueueStore();
      final controller = MatchController(source, uploadQueue: queue);
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.start();

      await expectLater(
        controller.uploadChunk(
          RecordingChunkFile(
            file: XFile('/tmp/rally-status-failure.mp4'),
            sequence: 0,
            startedAt: DateTime(2026, 10, 14),
            duration: const Duration(seconds: 5),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(controller.hasPendingUploads, isTrue);
      expect(
        controller.currentMatch.chunks.single.uploadStatus,
        ChunkUploadStatus.failed,
      );
    },
  );
}

class FakeMatchDataSource implements MatchDataSource {
  FakeMatchDataSource({this.initialMatch});

  final MatchData? initialMatch;
  final statuses = <MatchStatus>[];
  final uploadedSequences = <int>[];
  final durationUpdates = <Duration>[];
  bool failUploads = false;
  bool failStatusUpdates = false;
  Duration uploadDelay = Duration.zero;

  @override
  Future<List<MatchData>> loadMatches() async => [
    initialMatch ??
        const MatchData(
          id: 'fake',
          title: '기존 경기',
          place: '코트',
          players: 'A · B',
          duration: Duration(minutes: 2),
          status: MatchStatus.draft,
          uploadProgress: 0,
          markers: [],
        ),
  ];

  @override
  Future<MatchData> createMatch({
    required String title,
    required String place,
    required String players,
    required DateTime playedAt,
  }) async => MatchData(
    id: 'created',
    title: title,
    place: place,
    players: players,
    playedAt: playedAt,
    duration: Duration.zero,
    status: MatchStatus.draft,
    uploadProgress: 0,
    markers: const [],
  );

  @override
  Future<void> updateStatus(String matchId, MatchStatus status) async {
    statuses.add(status);
  }

  @override
  Future<void> addMarker(String matchId, Duration position) async {}

  @override
  Future<MatchChunk> uploadChunk({
    required String matchId,
    required int sequence,
    required DateTime startedAt,
    required Duration duration,
    required String localPath,
  }) async {
    if (failUploads) throw StateError('network unavailable');
    if (uploadDelay > Duration.zero) await Future<void>.delayed(uploadDelay);
    uploadedSequences.add(sequence);
    return MatchChunk(
      id: 'chunk',
      sequence: sequence,
      startedAt: startedAt,
      duration: duration,
      uploadStatus: ChunkUploadStatus.uploaded,
    );
  }

  @override
  Future<void> completeUpload(String matchId) async {
    statuses.add(MatchStatus.complete);
  }

  @override
  Future<void> updateUploadProgress(String matchId, int progress) async {}

  @override
  Future<void> updateDuration(String matchId, Duration duration) async {
    durationUpdates.add(duration);
  }

  @override
  Future<void> updateChunkStatus({
    required String matchId,
    required int sequence,
    required DateTime startedAt,
    required Duration duration,
    required String localPath,
    required ChunkUploadStatus status,
  }) async {
    if (failStatusUpdates) throw StateError('status unavailable');
  }
}

class MemoryUploadQueueStore implements UploadQueueStore {
  final uploads = <PendingUpload>[];

  @override
  Future<List<PendingUpload>> load() async => List.of(uploads);

  @override
  Future<void> upsert(PendingUpload upload) async {
    uploads.removeWhere(
      (item) =>
          item.matchId == upload.matchId && item.sequence == upload.sequence,
    );
    uploads.add(upload);
  }

  @override
  Future<void> remove({required String matchId, required int sequence}) async {
    uploads.removeWhere(
      (item) => item.matchId == matchId && item.sequence == sequence,
    );
  }
}
