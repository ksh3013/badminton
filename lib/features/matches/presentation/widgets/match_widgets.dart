import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../recording/data/device_readiness_service.dart';
import '../../../watch/data/watch_bridge.dart';
import '../../domain/match.dart';

class PageScroll extends StatelessWidget {
  const PageScroll({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(34, 38, 34, 60),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1260),
        child: child,
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppColors.lime,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Headline',
                  fontSize: 37,
                  letterSpacing: -1.7,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.panel,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class StorageCard extends StatelessWidget {
  const StorageCard({this.readiness, super.key});

  final DeviceReadiness? readiness;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF151B18),
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '기기 저장공간',
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
            Text(
              formatStorageBytes(readiness?.availableBytes),
              style: const TextStyle(color: AppColors.lime, fontSize: 11),
            ),
          ],
        ),
        SizedBox(height: 12),
        const Text(
          '녹화 전 여유 공간을 확인하세요.',
          style: TextStyle(color: AppColors.dim, fontSize: 10),
        ),
      ],
    ),
  );
}

class StatsGrid extends StatelessWidget {
  const StatsGrid({
    required this.matchCount,
    required this.totalDuration,
    required this.markerCount,
    required this.watchState,
    super.key,
  });

  final int matchCount;
  final Duration totalDuration;
  final int markerCount;
  final WatchConnectionState watchState;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 900 ? 4 : 2;
      final ratio = columns == 4 ? 2.3 : 1.1;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: ratio,
        children: [
          StatCard(
            label: '이번 달 경기',
            value: '$matchCount',
            note: matchCount == 0 ? '아직 기록된 경기가 없어요' : '실제 경기 기록 기준',
            positive: matchCount > 0,
          ),
          StatCard(
            label: '총 기록 시간',
            value: formatHoursMinutes(totalDuration),
            note: '저장된 경기 기록 기준',
          ),
          StatCard(
            label: '중요 장면',
            value: '$markerCount',
            note: markerCount == 0 ? '아직 저장된 마커가 없어요' : '저장된 마커 기준',
            positive: markerCount > 0,
          ),
          StatCard(
            label: '워치 연결 상태',
            value: switch (watchState) {
              WatchConnectionState.connected => 'ON',
              WatchConnectionState.disconnected => 'OFF',
              WatchConnectionState.unavailable => '대기',
            },
            note: switch (watchState) {
              WatchConnectionState.connected => '워치와 실시간 동기화 중',
              WatchConnectionState.disconnected => '워치 연결을 확인하세요',
              WatchConnectionState.unavailable => '워치 브리지 · 연동 준비 중',
            },
            positive: watchState == WatchConnectionState.connected,
          ),
        ],
      );
    },
  );
}

class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.note,
    this.positive = false,
    super.key,
  });

  final String label;
  final String value;
  final String note;
  final bool positive;

  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.all(17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 9),
        Text(
          value,
          style: TextStyle(
            color: positive && value == 'ON'
                ? AppColors.greenBright
                : AppColors.ink,
            fontFamily: 'Headline',
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          note,
          style: TextStyle(
            color: positive ? AppColors.greenBright : AppColors.dim,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, super.key});

  final MatchStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MatchStatus.recording => AppColors.red,
      MatchStatus.complete => AppColors.greenBright,
      MatchStatus.paused => AppColors.orange,
      _ => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 6),
          const SizedBox(width: 6),
          Text(
            matchStatusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class MatchRow extends StatelessWidget {
  const MatchRow({required this.match, this.onTap, super.key});

  final MatchData match;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.panelRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.sports_tennis,
              color: AppColors.greenBright,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${formatDate(match.playedAt)} · ${match.place} · ${match.players}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(status: match.status),
              const SizedBox(height: 5),
              Text(
                '${formatDuration(match.duration)} · ${match.markers.length}개 마커',
                style: const TextStyle(
                  color: AppColors.dim,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class LiveCard extends StatelessWidget {
  const LiveCard({
    required this.match,
    required this.onCapture,
    required this.onMarker,
    required this.onPause,
    required this.onEnd,
    super.key,
  });

  final MatchData match;
  final VoidCallback onCapture;
  final VoidCallback onMarker;
  final VoidCallback onPause;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              children: [
                const Text(
                  'LIVE SESSION',
                  style: TextStyle(
                    color: AppColors.lime,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                StatusPill(status: match.status),
              ],
            ),
          ),
          SizedBox(
            height: 188,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: CourtPainter())),
                Positioned(
                  top: 20,
                  left: 20,
                  child: Text(
                    match.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 20,
                  child: Text(
                    match.place,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    formatDuration(match.duration),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontFamily: 'Headline',
                      fontSize: 34,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: LinearProgressIndicator(
                    value: match.uploadProgress / 100,
                    minHeight: 4,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    backgroundColor: const Color(0xFF2A352F),
                    color: AppColors.lime,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: match.status == MatchStatus.draft
                        ? onCapture
                        : onPause,
                    icon: Icon(
                      match.status == MatchStatus.recording
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      match.status == MatchStatus.draft
                          ? '녹화 시작'
                          : match.status == MatchStatus.recording
                          ? '일시정지'
                          : '녹화 재개',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: match.status == MatchStatus.recording
                      ? onMarker
                      : null,
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: '중요 장면',
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  onPressed:
                      match.status == MatchStatus.recording ||
                          match.status == MatchStatus.paused
                      ? onEnd
                      : null,
                  icon: const Icon(Icons.stop),
                  tooltip: '녹화 종료',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class SideCards extends StatelessWidget {
  const SideCards({required this.match, super.key});

  final MatchData match;

  String get _uploadSummary {
    if (match.uploadProgress == 100) return '모든 조각 저장됨';
    if (match.chunks.isEmpty) return '업로드 대기 중';
    final uploaded = match.chunks
        .where((chunk) => chunk.uploadStatus == ChunkUploadStatus.uploaded)
        .length;
    final failed = match.chunks
        .where((chunk) => chunk.uploadStatus == ChunkUploadStatus.failed)
        .length;
    if (failed > 0) return '$failed개 실패 · 다시 시도';
    return '${match.chunks.length}개 중 $uploaded개 업로드';
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '업로드 현황',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Text(
                  '${match.uploadProgress}%',
                  style: const TextStyle(
                    color: AppColors.lime,
                    fontFamily: 'Headline',
                    fontSize: 28,
                  ),
                ),
                const Spacer(),
                Text(
                  _uploadSummary,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 13),
            LinearProgressIndicator(
              value: match.uploadProgress / 100,
              minHeight: 5,
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              backgroundColor: const Color(0xFF2A352F),
              color: AppColors.greenBright,
            ),
            const SizedBox(height: 14),
            Text(
              match.uploadProgress == 100
                  ? '휴대폰 임시 파일을 정리할 수 있어요.'
                  : '네트워크가 연결되면 자동으로 이어집니다.',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Surface(child: MarkerDetails(markers: match.markers)),
    ],
  );
}

class MarkerDetails extends StatelessWidget {
  const MarkerDetails({required this.markers, this.onMarkerTap, super.key});

  final List<Duration> markers;
  final ValueChanged<Duration>? onMarkerTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '이번 경기 마커',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      const Text(
        '워치에서 버튼을 누르면 현재 시점이 저장됩니다.',
        style: TextStyle(color: AppColors.muted, fontSize: 10),
      ),
      const SizedBox(height: 14),
      for (var i = markers.length - 1; i >= 0 && i >= markers.length - 4; i--)
        ListTile(
          onTap: onMarkerTap == null ? null : () => onMarkerTap!(markers[i]),
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.lime,
            foregroundColor: const Color(0xFF1B2518),
            child: Text('${i + 1}', style: const TextStyle(fontSize: 9)),
          ),
          title: Text(
            formatDuration(markers[i]),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          trailing: const Text(
            '저장됨',
            style: TextStyle(color: AppColors.dim, fontSize: 10),
          ),
        ),
    ],
  );
}

class CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF17241C), Color(0xFF101512), Color(0xFF1A2D20)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);
    final court = Paint()
      ..color = const Color(0x665B9B6A)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width + size.height; x += 150) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * .55, size.height),
        court,
      );
    }
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.height * .33,
      court..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      court,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
