import 'package:badmintonmatchrecord/app/rally_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty match state keeps a create action available', (
    tester,
  ) async {
    var createTapped = false;

    await tester.pumpWidget(
      MaterialApp(home: EmptyMatchesPage(onCreate: () => createTapped = true)),
    );

    expect(find.text('아직 기록된 경기가 없어요.'), findsOneWidget);
    expect(find.text('첫 경기 만들기'), findsOneWidget);

    await tester.tap(find.text('첫 경기 만들기'));
    expect(createTapped, isTrue);
  });
}
