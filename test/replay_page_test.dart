import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badmintonmatchrecord/features/matches/domain/match.dart';
import 'package:badmintonmatchrecord/features/matches/presentation/pages/replay_page.dart';

void main() {
  testWidgets('shows a clear message when no uploaded chunks are available', (
    tester,
  ) async {
    final match = MatchData(
      id: 'replay-test',
      title: '테스트 경기',
      place: '테스트 코트',
      players: 'A · B',
      duration: Duration.zero,
      status: MatchStatus.uploading,
      uploadProgress: 0,
      markers: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReplayPage(
            match: match,
            playhead: Duration.zero,
            isPlaying: false,
            onPlay: () {},
            onSeek: (_) {},
            onMarkerTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('업로드된 영상 조각이 아직 없습니다.'), findsOneWidget);
  });
}
