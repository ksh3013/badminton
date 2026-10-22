import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/match.dart';
import '../../../watch/data/watch_bridge.dart';
import '../widgets/match_widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    required this.match,
    required this.matches,
    required this.onCreate,
    required this.onCapture,
    required this.onMarker,
    required this.onPause,
    required this.onEnd,
    required this.watchState,
    super.key,
  });

  final MatchData match;
  final List<MatchData> matches;
  final VoidCallback onCreate;
  final VoidCallback onCapture;
  final VoidCallback onMarker;
  final VoidCallback onPause;
  final VoidCallback onEnd;
  final WatchConnectionState watchState;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthMatchCount = matches.where((item) {
      final playedAt = item.playedAt;
      return playedAt?.year == now.year && playedAt?.month == now.month;
    }).length;
    final totalDuration = matches.fold<Duration>(
      Duration.zero,
      (sum, item) => sum + item.duration,
    );

    return PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            eyebrow: formatTodayHeading(now),
            title: '오늘의 기록',
            subtitle: '경기 중에는 간단하게, 끝난 뒤에는 더 빠르게 복기하세요.',
            action: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 17),
              label: const Text('경기 만들기'),
            ),
          ),
          StatsGrid(
            matchCount: monthMatchCount,
            totalDuration: totalDuration,
            markerCount: matches.fold(
              0,
              (sum, item) => sum + item.markers.length,
            ),
            watchState: watchState,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              final live = LiveCard(
                match: match,
                onCapture: onCapture,
                onMarker: onMarker,
                onPause: onPause,
                onEnd: onEnd,
              );
              final side = SideCards(match: match);
              return Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide) Expanded(flex: 3, child: live) else live,
                  SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                  if (wide) Expanded(flex: 2, child: side) else side,
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const Text(
            '최근 경기',
            style: TextStyle(fontFamily: 'Headline', fontSize: 19),
          ),
          const SizedBox(height: 14),
          ...matches
              .take(3)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: MatchRow(match: item),
                ),
              ),
        ],
      ),
    );
  }
}
