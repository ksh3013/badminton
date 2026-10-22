import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/match.dart';

abstract interface class MatchDataSource {
  Future<List<MatchData>> loadMatches();

  Future<MatchData> createMatch({
    required String title,
    required String place,
    required String players,
    required DateTime playedAt,
  });

  Future<void> updateStatus(String matchId, MatchStatus status);

  Future<void> addMarker(String matchId, Duration position);

  Future<MatchChunk> uploadChunk({
    required String matchId,
    required int sequence,
    required DateTime startedAt,
    required Duration duration,
    required String localPath,
  });

  Future<void> completeUpload(String matchId);

  Future<void> updateUploadProgress(String matchId, int progress);

  Future<void> updateDuration(String matchId, Duration duration);

  Future<void> updateChunkStatus({
    required String matchId,
    required int sequence,
    required DateTime startedAt,
    required Duration duration,
    required String localPath,
    required ChunkUploadStatus status,
  });
}

class MatchRepository implements MatchDataSource {
  MatchRepository({this.client});

  final SupabaseClient? client;

  bool get isRemote => client != null && client!.auth.currentUser != null;

  @override
  Future<List<MatchData>> loadMatches() async {
    _requireRemote();
    final rows = await client!
        .from('matches')
        .select('*, match_players(*), match_markers(*), video_chunks(*)')
        .order('created_at', ascending: false);
    return Future.wait(rows.map(_fromRow));
  }

  @override
  Future<MatchData> createMatch({
    required String title,
    required String place,
    required String players,
    required DateTime playedAt,
  }) async {
    _requireRemote();
    final userId = client!.auth.currentUser!.id;
    final row = await client!
        .from('matches')
        .insert({
          'owner_id': userId,
          'title': title,
          'place': place,
          'played_at': playedAt.toIso8601String(),
        })
        .select('*, match_players(*), match_markers(*), video_chunks(*)')
        .single();

    final names = players
        .split(RegExp(r'\s*[·/,]\s*'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (names.isNotEmpty) {
      await client!.from('match_players').insert([
        for (var i = 0; i < names.length; i++)
          {'match_id': row['id'], 'display_name': names[i], 'position': i + 1},
      ]);
    }
    final created = await _fromRow(row);
    return created.copyWith(players: players);
  }

  @override
  Future<void> updateStatus(String matchId, MatchStatus status) async {
    _requireRemote();
    await client!
        .from('matches')
        .update({'status': status.name})
        .eq('id', matchId);
  }

  @override
  Future<void> addMarker(String matchId, Duration position) async {
    _requireRemote();
    await client!.from('match_markers').insert({
      'match_id': matchId,
      'position_seconds': position.inSeconds,
      'created_by': client!.auth.currentUser!.id,
    });
  }

  @override
  Future<MatchChunk> uploadChunk({
    required String matchId,
    required int sequence,
    required DateTime startedAt,
    required Duration duration,
    required String localPath,
  }) async {
    _requireRemote();

    final userId = client!.auth.currentUser!.id;
    final storagePath = '$userId/$matchId/chunk_$sequence.mp4';
    await updateChunkStatus(
      matchId: matchId,
      sequence: sequence,
      startedAt: startedAt,
      duration: duration,
      localPath: localPath,
      status: ChunkUploadStatus.uploading,
    );
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await client!.storage
            .from('match-videos')
            .upload(
              storagePath,
              File(localPath),
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'video/mp4',
              ),
            );
        final row = await client!
            .from('video_chunks')
            .upsert({
              'match_id': matchId,
              'sequence_no': sequence,
              'started_at': startedAt.toIso8601String(),
              'duration_seconds': duration.inSeconds,
              'local_path': localPath,
              'storage_path': storagePath,
              'upload_status': ChunkUploadStatus.uploaded.name,
              'uploaded_at': DateTime.now().toIso8601String(),
            }, onConflict: 'match_id,sequence_no')
            .select()
            .single();
        final url = await client!.storage
            .from('match-videos')
            .createSignedUrl(storagePath, 60 * 60 * 24 * 7);
        await File(localPath).delete();
        return MatchChunk(
          id: row['id'] as String,
          sequence: sequence,
          startedAt: startedAt,
          duration: duration,
          storagePath: storagePath,
          url: url,
          uploadStatus: ChunkUploadStatus.uploaded,
        );
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(seconds: attempt + 1));
        }
      }
    }
    await updateChunkStatus(
      matchId: matchId,
      sequence: sequence,
      startedAt: startedAt,
      duration: duration,
      localPath: localPath,
      status: ChunkUploadStatus.failed,
    );
    throw lastError!;
  }

  @override
  Future<void> completeUpload(String matchId) async {
    _requireRemote();
    await client!
        .from('matches')
        .update({'status': MatchStatus.complete.name, 'upload_progress': 100})
        .eq('id', matchId);
  }

  @override
  Future<void> updateUploadProgress(String matchId, int progress) async {
    _requireRemote();
    await client!
        .from('matches')
        .update({'upload_progress': progress})
        .eq('id', matchId);
  }

  @override
  Future<void> updateDuration(String matchId, Duration duration) async {
    _requireRemote();
    await client!
        .from('matches')
        .update({'duration_seconds': duration.inSeconds})
        .eq('id', matchId);
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
    _requireRemote();
    final userId = client!.auth.currentUser!.id;
    await client!.from('video_chunks').upsert({
      'match_id': matchId,
      'sequence_no': sequence,
      'started_at': startedAt.toIso8601String(),
      'duration_seconds': duration.inSeconds,
      'local_path': localPath,
      'storage_path': '$userId/$matchId/chunk_$sequence.mp4',
      'upload_status': status.name,
      if (status == ChunkUploadStatus.uploaded)
        'uploaded_at': DateTime.now().toIso8601String(),
    }, onConflict: 'match_id,sequence_no');
  }

  Future<MatchData> _fromRow(Map<String, dynamic> row) async {
    final playerRows = (row['match_players'] as List? ?? const []).cast<Map>();
    playerRows.sort(
      (a, b) => ((a['position'] as int?) ?? 0).compareTo(
        (b['position'] as int?) ?? 0,
      ),
    );
    final players = playerRows
        .map((item) => item['display_name'] as String)
        .join(' · ');
    final markerRows = (row['match_markers'] as List? ?? const []).cast<Map>();
    markerRows.sort(
      (a, b) => ((a['position_seconds'] as int?) ?? 0).compareTo(
        (b['position_seconds'] as int?) ?? 0,
      ),
    );
    final markers = markerRows
        .map((item) => Duration(seconds: item['position_seconds'] as int))
        .toList();
    final chunks = <MatchChunk>[];
    final chunkRows = (row['video_chunks'] as List? ?? const []).cast<Map>();
    chunkRows.sort(
      (a, b) => ((a['sequence_no'] as int?) ?? 0).compareTo(
        (b['sequence_no'] as int?) ?? 0,
      ),
    );
    for (final chunk in chunkRows) {
      final path = chunk['storage_path'] as String?;
      String? url;
      if (path != null && path.isNotEmpty && isRemote) {
        url = await client!.storage
            .from('match-videos')
            .createSignedUrl(path, 604800);
      }
      chunks.add(
        MatchChunk(
          id: chunk['id'] as String,
          sequence: chunk['sequence_no'] as int,
          startedAt: DateTime.parse(chunk['started_at'] as String),
          duration: Duration(seconds: chunk['duration_seconds'] as int),
          localPath: chunk['local_path'] as String?,
          storagePath: path,
          url: url,
          uploadStatus: _uploadStatus(chunk['upload_status'] as String),
        ),
      );
    }
    final chunkDuration = chunks.fold<Duration>(
      Duration.zero,
      (sum, chunk) => sum + chunk.duration,
    );
    final storedDuration = Duration(
      seconds: row['duration_seconds'] as int? ?? 0,
    );
    return MatchData(
      id: row['id'] as String,
      title: row['title'] as String,
      place: row['place'] as String,
      players: players,
      playedAt: DateTime.tryParse(row['played_at'] as String? ?? ''),
      duration: storedDuration > chunkDuration ? storedDuration : chunkDuration,
      status: _matchStatus(row['status'] as String? ?? 'draft'),
      uploadProgress: row['upload_progress'] as int? ?? 0,
      markers: List.unmodifiable(markers),
      chunks: List.unmodifiable(chunks),
    );
  }

  static MatchStatus _matchStatus(String value) =>
      MatchStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => MatchStatus.draft,
      );

  static ChunkUploadStatus _uploadStatus(String value) =>
      ChunkUploadStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => ChunkUploadStatus.pending,
      );

  void _requireRemote() {
    if (!isRemote) {
      throw StateError(
        'Supabase가 설정되지 않았거나 로그인되지 않았습니다. '
        'publishable key와 사용자 인증을 확인하세요.',
      );
    }
  }
}
