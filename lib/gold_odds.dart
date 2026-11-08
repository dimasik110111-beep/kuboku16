import 'dart:math';

import 'cup_data.dart';

/// Transparent match probability model for the current Cup.
/// It uses confirmed qualification results only and shrinks small samples
/// toward the tournament average before estimating goal distributions.
class GoldOdds {
  final double homeWin, awayWin, homeGoals, awayGoals;
  final int homeGames, awayGames, totalGames;
  final String mostLikelyScore;

  const GoldOdds({required this.homeWin, required this.awayWin,
    required this.homeGoals, required this.awayGoals,
    required this.homeGames, required this.awayGames,
    required this.totalGames, required this.mostLikelyScore});

  static GoldOdds forMatch(List<Match> matches, Match match,
      {DateTime? utcNow}) {
    final now = utcNow ?? DateTime.now().toUtc();
    final played = matches.where((m) => m.isQualifier && m.isResultAt(now) &&
        !m.isLive && m.goals != null).toList();
    var goalsFor = 0, homeGoalsFor = 0, awayGoalsFor = 0, games = 0;
    for (final m in played) {
      goalsFor += m.goals![0] + m.goals![1];
      homeGoalsFor += m.goals![0];
      awayGoalsFor += m.goals![1];
      games++;
    }
    final avg = games == 0 ? 5.0 : goalsFor / games;
    final baseline = (avg / 2).clamp(1.3, 5.0).toDouble();
    final homeFactor = games == 0 ? 1.0 :
        ((homeGoalsFor + baseline * 3) / (awayGoalsFor + baseline * 3))
            .clamp(.90, 1.10).toDouble();
    ({double scored, double conceded, int games}) form(String team) {
      var scored = 0, conceded = 0, count = 0;
      for (final m in played) {
        if (m.home != team && m.away != team) continue;
        final g = m.goals!;
        scored += m.home == team ? g[0] : g[1];
        conceded += m.home == team ? g[1] : g[0];
        count++;
      }
      const priorGames = 4.0;
      return (scored: (scored + baseline * priorGames) / (count + priorGames),
        conceded: (conceded + baseline * priorGames) / (count + priorGames),
        games: count);
    }

    final h = form(match.home), a = form(match.away);
    // Attack and defence are independently blended. Home ice is estimated
    // from the tournament's observed home/away scoring, shrunk by three
    // prior games and bounded to avoid overreacting to a small sample.
    final homeRate = ((h.scored / baseline) * (a.conceded / baseline) *
        baseline * homeFactor).clamp(.35, 8.0).toDouble();
    final awayRate = ((a.scored / baseline) * (h.conceded / baseline) *
        baseline / homeFactor).clamp(.35, 8.0).toDouble();
    final hp = _poisson(homeRate), ap = _poisson(awayRate);
    var home = 0.0, away = 0.0, tied = 0.0, best = -1.0;
    var bestHome = 0, bestAway = 0;
    for (var i = 0; i < hp.length; i++) {
      for (var j = 0; j < ap.length; j++) {
        final p = hp[i] * ap[j];
        if (i > j) home += p;
        else if (i < j) away += p;
        else tied += p;
        if (p > best) { best = p; bestHome = i; bestAway = j; }
      }
    }
    // Regulation ties are resolved with the estimated strength difference.
    final strength = ((homeRate - awayRate) / (homeRate + awayRate));
    final otHomeShare = (.5 + strength * .22).clamp(.38, .62).toDouble();
    home += tied * otHomeShare;
    away += tied * (1 - otHomeShare);
    final total = home + away;
    return GoldOdds(homeWin: home / total, awayWin: away / total,
      homeGoals: homeRate, awayGoals: awayRate,
      homeGames: h.games, awayGames: a.games, totalGames: games,
      mostLikelyScore: '$bestHome:$bestAway');
  }

  static List<double> _poisson(double lambda) {
    final out = List<double>.filled(21, 0);
    out[0] = exp(-lambda);
    for (var k = 1; k < out.length; k++) out[k] = out[k - 1] * lambda / k;
    final sum = out.fold<double>(0, (s, x) => s + x);
    return out.map((x) => x / sum).toList(growable: false);
  }
}
