import 'package:badmintonmatchrecord/features/matches/data/match_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not return sample matches when Supabase is unavailable', () async {
    final repository = MatchRepository();

    expect(repository.loadMatches(), throwsA(isA<StateError>()));
  });
}
