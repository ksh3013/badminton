import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/match.dart';
import '../../../recording/data/camera_recording_service.dart';
import '../../../watch/data/watch_bridge.dart';
import '../widgets/match_widgets.dart';

class CapturePage extends StatelessWidget {
  const CapturePage({
    required this.match,
    required this.onStart,
    required this.onPause,
    required this.onEnd,
    required this.onMarker,
    required this.cameraService,
    required this.onRetry,
    required this.watchState,
    super.key,
  });

  final MatchData match;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onEnd;
  final VoidCallback onMarker;
  final CameraRecordingService cameraService;
  final VoidCallback onRetry;
  final WatchConnectionState watchState;

  @override
  Widget build(BuildContext context) => PageScroll(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          eyebrow: 'RECORDING CONTROL',
          title: '녹화 제어',
          subtitle: '휴대폰을 만지지 않고 경기 기록을 제어하세요.',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 900;
            final preview = _Preview(match: match, service: cameraService);
            final controls = AnimatedBuilder(
              animation: cameraService,
              builder: (context, _) => _Controls(
                match: match,
                watchState: watchState,
                cameraReady:
                    cameraService.isRecording || cameraService.isPaused,
                onStart: onStart,
                onPause: onPause,
                onEnd: onEnd,
                onMarker: onMarker,
                onRetry: onRetry,
              ),
            );
            return Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wide) Expanded(flex: 3, child: preview) else preview,
                SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                if (wide) Expanded(flex: 2, child: controls) else controls,
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _Preview extends StatelessWidget {
  const _Preview({required this.match, required this.service});

  final MatchData match;
  final CameraRecordingService service;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) => Surface(
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: service.isInitialized
                    ? CameraPreview(service.controller!)
                    : CustomPaint(painter: CourtPainter()),
              ),
              Positioned(
                top: 18,
                left: 18,
                child: StatusPill(status: match.status),
              ),
              Center(
                child: Text(
                  formatDuration(match.duration),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontFamily: 'Headline',
                    fontSize: 42,
                  ),
                ),
              ),
              Positioned(
                bottom: 18,
                left: 18,
                child: Text(
                  service.isInitialized ? '카메라 미리보기' : '녹화 시작을 누르면 카메라를 준비합니다.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.match,
    required this.watchState,
    required this.cameraReady,
    required this.onStart,
    required this.onPause,
    required this.onEnd,
    required this.onMarker,
    required this.onRetry,
  });

  final MatchData match;
  final WatchConnectionState watchState;
  final bool cameraReady;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onEnd;
  final VoidCallback onMarker;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '현재 경기',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              match.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              match.place,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.watch_outlined,
                  color: AppColors.greenBright,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  '워치 브리지',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(width: 5),
                Text(
                  switch (watchState) {
                    WatchConnectionState.connected => '연결됨',
                    WatchConnectionState.disconnected => '연결 끊김',
                    WatchConnectionState.unavailable => '사용 불가',
                  },
                  style: TextStyle(
                    color: watchState == WatchConnectionState.connected
                        ? AppColors.greenBright
                        : AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Surface(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: match.status == MatchStatus.draft || !cameraReady
                    ? onStart
                    : match.status == MatchStatus.recording ||
                          match.status == MatchStatus.paused
                    ? onPause
                    : null,
                icon: Icon(
                  cameraReady && match.status == MatchStatus.recording
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                label: Text(
                  !cameraReady || match.status == MatchStatus.draft
                      ? '녹화 시작'
                      : match.status == MatchStatus.recording
                      ? '일시정지'
                      : '녹화 재개',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: match.status == MatchStatus.recording && cameraReady
                    ? onMarker
                    : null,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('중요 장면 표시'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed:
                    match.status == MatchStatus.recording ||
                        match.status == MatchStatus.paused
                    ? (cameraReady ? onEnd : null)
                    : null,
                icon: const Icon(Icons.stop),
                label: const Text('녹화 종료'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Surface(child: MarkerDetails(markers: match.markers)),
      if (match.status == MatchStatus.uploading)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('업로드 다시 시도'),
            ),
          ),
        ),
    ],
  );
}
