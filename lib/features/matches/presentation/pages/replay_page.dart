import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/match.dart';
import '../widgets/match_widgets.dart';

class ReplayPage extends StatelessWidget {
  const ReplayPage({
    required this.match,
    required this.playhead,
    required this.isPlaying,
    required this.onPlay,
    required this.onSeek,
    required this.onMarkerTap,
    super.key,
  });

  final MatchData match;
  final Duration playhead;
  final bool isPlaying;
  final VoidCallback onPlay;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration> onMarkerTap;

  @override
  Widget build(BuildContext context) => PageScroll(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          eyebrow: 'MATCH REPLAY',
          title: '다시보기',
          subtitle: '타임라인의 중요 장면에서 바로 복기를 시작하세요.',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 900;
            final uploadedChunks =
                match.chunks.where((chunk) => chunk.url != null).toList()
                  ..sort((a, b) => a.sequence.compareTo(b.sequence));
            final player = Surface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ReplayVideo(
                              urls: [
                                for (final chunk in uploadedChunks) chunk.url!,
                              ],
                              durations: [
                                for (final chunk in uploadedChunks)
                                  chunk.duration,
                              ],
                              isPlaying: isPlaying,
                              playhead: playhead,
                              onPositionChanged: onSeek,
                            ),
                          ),
                          Positioned(
                            top: 18,
                            left: 18,
                            right: 18,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  match.title,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  match.place,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Center(
                            child: IconButton.filled(
                              onPressed: onPlay,
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 30,
                                color: const Color(0xFF102015),
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.lime,
                                fixedSize: const Size(64, 64),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 18),
                    child: Column(
                      children: [
                        Slider(
                          value: playhead.inSeconds.toDouble().clamp(
                            0,
                            match.duration.inSeconds.toDouble(),
                          ),
                          min: 0,
                          max: match.duration.inSeconds.toDouble(),
                          onChanged: (value) =>
                              onSeek(Duration(seconds: value.round())),
                          activeColor: AppColors.greenBright,
                          inactiveColor: const Color(0xFF344238),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: onPlay,
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: AppColors.lime,
                              ),
                            ),
                            Text(
                              '${formatDuration(playhead)} / ${formatDuration(match.duration)}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.volume_up_outlined,
                              color: AppColors.muted,
                              size: 17,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            return Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wide) Expanded(flex: 3, child: player) else player,
                SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                if (wide)
                  Expanded(
                    flex: 2,
                    child: MarkerDetails(
                      markers: match.markers,
                      onMarkerTap: onMarkerTap,
                    ),
                  )
                else
                  MarkerDetails(
                    markers: match.markers,
                    onMarkerTap: onMarkerTap,
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class ReplayVideo extends StatefulWidget {
  const ReplayVideo({
    required this.urls,
    required this.durations,
    required this.isPlaying,
    required this.playhead,
    required this.onPositionChanged,
    super.key,
  });

  final List<String> urls;
  final List<Duration> durations;
  final bool isPlaying;
  final Duration playhead;
  final ValueChanged<Duration> onPositionChanged;

  @override
  State<ReplayVideo> createState() => _ReplayVideoState();
}

class _ReplayVideoState extends State<ReplayVideo> {
  VideoPlayerController? _controller;
  VoidCallback? _listener;
  int _index = 0;
  bool _advancing = false;
  bool _loading = true;
  bool _positionReportScheduled = false;
  Duration? _pendingPosition;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReplayVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.urls, widget.urls)) _load();
    if ((widget.playhead - oldWidget.playhead).abs() >
            const Duration(seconds: 2) &&
        _controller?.value.isInitialized == true) {
      _seekGlobal(widget.playhead);
    }
    if (_controller?.value.isInitialized == true) {
      if (widget.isPlaying && !_controller!.value.isPlaying) {
        _controller!.play();
      } else if (!widget.isPlaying && _controller!.value.isPlaying) {
        _controller!.pause();
      }
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    if (_listener != null) _controller?.removeListener(_listener!);
    await _controller?.dispose();
    _controller = null;
    if (widget.urls.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    try {
      _index = _index.clamp(0, widget.urls.length - 1);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.urls[_index]),
      );
      await controller.initialize();
      _listener = () {
        if (!mounted || !controller.value.isInitialized) return;
        final global = _offsetFor(_index) + controller.value.position;
        _reportPositionAfterFrame(global, controller);
        if (widget.isPlaying &&
            !controller.value.isPlaying &&
            controller.value.position >=
                controller.value.duration - const Duration(milliseconds: 200)) {
          _playNext();
        }
      };
      controller.addListener(_listener!);
      _controller = controller;
      if (widget.isPlaying) await controller.play();
    } catch (_) {
      _error = '영상 조각을 불러오지 못했어요.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reportPositionAfterFrame(
    Duration position,
    VideoPlayerController controller,
  ) {
    _pendingPosition = position;
    if (_positionReportScheduled) return;
    _positionReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionReportScheduled = false;
      final pending = _pendingPosition;
      _pendingPosition = null;
      if (!mounted || !identical(_controller, controller) || pending == null) {
        return;
      }
      widget.onPositionChanged(pending);
    });
  }

  Duration _offsetFor(int index) => widget.durations
      .take(index)
      .fold(Duration.zero, (sum, item) => sum + item);

  Future<void> _playNext() async {
    if (_advancing || _index >= widget.urls.length - 1) return;
    _advancing = true;
    try {
      _index++;
      await _load();
      await _controller?.play();
    } finally {
      _advancing = false;
    }
  }

  Future<void> _seekGlobal(Duration position) async {
    if (widget.urls.isEmpty) return;
    var remaining = position;
    var target = 0;
    for (var i = 0; i < widget.durations.length; i++) {
      if (remaining <= widget.durations[i] ||
          i == widget.durations.length - 1) {
        target = i;
        break;
      }
      remaining -= widget.durations[i];
    }
    if (target != _index) {
      _index = target;
      await _load();
    }
    await _controller?.seekTo(remaining);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller?.value.isInitialized != true) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: CourtPainter()),
          Center(
            child: _loading
                ? const CircularProgressIndicator(color: AppColors.lime)
                : Text(
                    _error ?? '업로드된 영상 조각이 아직 없습니다.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
          ),
        ],
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: controller!.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }

  @override
  void dispose() {
    if (_listener != null) _controller?.removeListener(_listener!);
    _controller?.dispose();
    super.dispose();
  }
}
