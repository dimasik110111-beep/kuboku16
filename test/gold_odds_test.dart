import 'package:flutter_test/flutter_test.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/gold_odds.dart';

void main() {
  final now = DateTime.utc(2026, 11, 8);

  test('uses confirmed qualifying results and returns normalized probabilities', () {
    final played = [
      Match('2026-11-01', 'North', 'South', '5:1', 'Группа А-II', '',
          status: 'FINAL', gameId: 1),
      Match('2026-11-02', 'South', 'North', '2:4', 'Группа А-II', '',
          status: 'FINAL', gameId: 2),
      Match('2026-11-03', 'North', 'Other', '3:2', 'Группа А-II', '',
          status: 'SCORE_AVAILABLE', gameId: 3),
      Match('2026-11-04', 'Other', 'South', '9:0', 'Группа А-II', '',
          status: 'LIVE', gameId: 4),
    ];
    final future = Match('2026-11-10', 'North', 'South', '', 'Группа А-II', '',
        status: 'SCHEDULED', gameId: 5);
    final result = GoldOdds.forMatch([...played, future], future, utcNow: now);

    expect(result.totalGames, 2);
    expect(result.homeGames, 2);
    expect(result.awayGames, 2);
    expect(result.homeWin + result.awayWin, closeTo(1, 1e-12));
    expect(result.homeWin, greaterThan(result.awayWin));
    expect(result.homeGoals, greaterThan(result.awayGoals));
  });

  test('sparse teams stay close to an even matchup', () {
    final future = Match('2026-11-10', 'New A', 'New B', '', 'Группа А-II', '',
        status: 'SCHEDULED', gameId: 8);
    final result = GoldOdds.forMatch([future], future, utcNow: now);
    expect(result.homeWin, closeTo(.5, .02));
    expect(result.awayWin, closeTo(.5, .02));
    expect(result.homeGoals, closeTo(result.awayGoals, 1e-12));
    expect(result.mostLikelyScore, '2:2');
  });

  test('excludes non-qualifier and unconfirmed results', () {
    final rows = [
      Match('2026-11-01', 'A', 'B', '8:0', 'Золотой финал', '',
          status: 'FINAL', gameId: 11),
      Match('2026-11-01', 'A', 'B', '8:0', 'Группа А-II', '',
          status: 'UNKNOWN', gameId: 12),
    ];
    final future = Match('2026-11-10', 'A', 'B', '', 'Группа А-II', '',
        status: 'SCHEDULED', gameId: 13);
    final result = GoldOdds.forMatch([...rows, future], future, utcNow: now);
    expect(result.totalGames, 0);
    expect(result.homeWin, closeTo(.5, .02));
  });
}
