import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badmintonmatchrecord/features/matches/domain/match.dart';
import 'package:badmintonmatchrecord/features/matches/presentation/widgets/match_widgets.dart';
import 'package:badmintonmatchrecord/features/recording/data/device_readiness_service.dart';

void main() {
  testWidgets('shows device storage instead of design-time storage values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StorageCard(
            readiness: DeviceReadiness(
              availableBytes: 3 * 1024 * 1024 * 1024,
              batteryPercent: 80,
            ),
          ),
        ),
      ),
    );

    expect(find.text('3.0 GB 여유'), findsOneWidget);
    expect(find.text('34%'), findsNothing);
    expect(find.text('1.7 GB / 5 GB 사용 중'), findsNothing);
  });

  testWidgets('shows the actual upload chunk state', (tester) async {
    const match = MatchData(
      id: 'match',
      title: '테스트 경기',
      place: '테스트 코트',
      players: 'A · B',
      duration: Duration.zero,
      status: MatchStatus.draft,
      uploadProgress: 0,
      markers: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SideCards(match: match)),
      ),
    );

    expect(find.text('업로드 대기 중'), findsOneWidget);
    expect(find.text('3개 중 2개 업로드'), findsNothing);
  });
}
