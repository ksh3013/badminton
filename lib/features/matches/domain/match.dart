enum MatchStatus { recording, paused, uploading, complete, draft }

enum ChunkUploadStatus { pending, uploading, uploaded, failed }

class MatchChunk {
  const MatchChunk({
    required this.id,
    required this.sequence,
    required this.startedAt,
    required this.duration,
    required this.uploadStatus,
    this.localPath,
    this.storagePath,
    this.url,
  });

  final String id;
  final int sequence;
  final DateTime startedAt;
  final Duration duration;
  final String? localPath;
  final String? storagePath;
  final String? url;
  final ChunkUploadStatus uploadStatus;
}

class MatchData {
  const MatchData({
    required this.id,
    required this.title,
    required this.place,
    required this.players,
    this.playedAt,
    required this.duration,
    required this.status,
    required this.uploadProgress,
    required this.markers,
    this.chunks = const [],
  });

  final String id;
  final String title;
  final String place;
  final String players;
  final DateTime? playedAt;
  final Duration duration;
  final MatchStatus status;
  final int uploadProgress;
  final List<Duration> markers;
  final List<MatchChunk> chunks;

  MatchData copyWith({
    String? title,
    String? place,
    String? players,
    DateTime? playedAt,
    Duration? duration,
    MatchStatus? status,
    int? uploadProgress,
    List<Duration>? markers,
    List<MatchChunk>? chunks,
  }) {
    return MatchData(
      id: id,
      title: title ?? this.title,
      place: place ?? this.place,
      players: players ?? this.players,
      playedAt: playedAt ?? this.playedAt,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      markers: List.unmodifiable(markers ?? this.markers),
      chunks: List.unmodifiable(chunks ?? this.chunks),
    );
  }
}

String matchStatusLabel(MatchStatus status) {
  switch (status) {
    case MatchStatus.recording:
      return '녹화 중';
    case MatchStatus.paused:
      return '녹화 일시정지';
    case MatchStatus.uploading:
      return '업로드 중';
    case MatchStatus.complete:
      return '업로드 완료';
    case MatchStatus.draft:
      return '시작 전';
  }
}
