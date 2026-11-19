import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cup_data.dart';
import 'player_statistics.dart';
import 'player_statistics_page.dart';
import 'team_pages.dart';
import 'match_center.dart';
import 'insights.dart';
import 'app_services.dart';
import 'ui_kit.dart';
import 'scenario_page.dart';
import 'tournament.dart';
import 'follow_store.dart';
import 'command_center_page.dart';

class TeamHubPage extends StatefulWidget {
  final TeamInfo team;
  final List<Match> matches;
  final List<TeamInfo> teams;
  const TeamHubPage(
      {super.key,
      required this.team,
      required this.matches,
      required this.teams});
  @override
  State<TeamHubPage> createState() => _TeamHubPageState();
}

class _TeamHubPageState extends State<TeamHubPage> {
  final client = http.Client();
  String? opponent;
  CupStatistics? statistics;
  bool following = false,
      followingBusy = false,
      loadingStats = false,
      staleStats = false;
  int _followRevision = 0;
  Future<void> loadFollowing() async {
    final revision = _followRevision;
    try {
      final all = await FollowStore.teams();
      if (mounted && revision == _followRevision)
        setState(() => following = all.contains(widget.team.fullName));
    } catch (e) {
      Diagnostics.record('team following', e);
    }
  }

  Future<void> toggleFollowing() async {
    if (followingBusy) return;
    _followRevision++;
    setState(() => followingBusy = true);
    try {
      final next = await FollowStore.toggleTeam(widget.team.fullName);
      if (mounted) setState(() => following = next);
    } catch (e) {
      Diagnostics.record('team following', e);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Не удалось сохранить команду. Попробуй ещё раз.')));
    } finally {
      if (mounted) setState(() => followingBusy = false);
    }
  }

  Future<void> fetchStats() async {
    if (loadingStats || !mounted) return;
    setState(() => loadingStats = true);
    try {
      final source = CupStatisticsClient(client);
      if (statistics == null) {
        final saved = await source.cached();
        if (!mounted) return;
        if (saved != null)
          setState(() {
            statistics = saved;
            staleStats = true;
          });
      }
      final fresh = await source.fetch();
      if (mounted)
        setState(() {
          statistics = fresh;
          staleStats = false;
        });
    } catch (error) {
      Diagnostics.record('team stats', error);
      if (mounted) setState(() => staleStats = statistics != null);
    } finally {
      if (mounted) setState(() => loadingStats = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchStats();
    loadFollowing();
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }

  TeamInfo? _team(String name) {
    for (final team in widget.teams) {
      if (sameClub(team.fullName, name)) return team;
    }
    return null;
  }

  void open(Match m) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => MatchCenterPage(
              match: m,
              homeTeam: _team(m.home),
              awayTeam: _team(m.away),
              matches: widget.matches)));
  Widget fixture(Match m) => CupCard(
      margin: const EdgeInsets.fromLTRB(12, 3, 12, 4),
      padding: EdgeInsets.zero,
      child: ListTile(
          onTap: () => open(m),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
          leading: Container(
              width: 5,
              height: 44,
              decoration: BoxDecoration(
                  color: m.isLive
                      ? CupUi.green
                      : m.finished
                          ? CupUi.ice
                          : CupUi.yellow,
                  borderRadius: BorderRadius.circular(5))),
          title: Text('${m.home} — ${m.away}',
              maxLines: 2,
              style: TextStyle(
                  color: CupUi.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${m.dayLabel} · ${m.timeMsk} · ${m.stage}',
                  maxLines: 2,
                  style: TextStyle(color: CupUi.muted, fontSize: 12))),
          trailing: Text(m.hasScore ? m.score : '→',
              style: TextStyle(
                  color: m.isLive ? CupUi.green : CupUi.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 19))));
  Widget teamPulse(List<Match> fixtures, Rank? rank, List<Rank> table) {
    final finished = fixtures.where((m) => m.finished && m.isQualifier).toList()
      ..sort((a, b) =>
          '${b.date} ${b.timeMsk}'.compareTo('${a.date} ${a.timeMsk}'));
    final cup = CupTournament(widget.matches,
        teams: widget.teams.map((t) => t.fullName));
    final groups = cup.thirdTourProjection();
    final spot = groups
        .indexWhere((g) => g.any((s) => sameClub(s, widget.team.fullName)));
    const letters = ['А', 'Б', 'В', 'Г'];
    final form = finished.take(5).toList();
    bool victory(Match m) {
      final goals = m.goals;
      if (goals == null) return false;
      return sameClub(m.home, widget.team.fullName)
          ? goals[0] > goals[1]
          : goals[1] > goals[0];
    }

    return Column(children: [
      CupSection(
          title: 'Форма команды',
          subtitle: 'Форма, результативность и текущий путь в III тур'),
      CupCard(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Разница шайб',
                        style: TextStyle(
                            color: CupUi.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text(
                        rank == null
                            ? '—'
                            : '${rank.diff > 0 ? '+' : ''}${rank.diff}',
                        style: TextStyle(
                            color: CupUi.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700)),
                  ])),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Шайб за матч',
                        style: TextStyle(
                            color: CupUi.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text(
                        rank == null || rank.gp == 0
                            ? '—'
                            : (rank.gf / rank.gp).toStringAsFixed(2),
                        style: TextStyle(
                            color: CupUi.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700)),
                  ])),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Победы',
                        style: TextStyle(
                            color: CupUi.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text(rank == null ? '—' : '${rank.w}',
                        style: TextStyle(
                            color: CupUi.green,
                            fontSize: 30,
                            fontWeight: FontWeight.w700)),
                  ])),
            ]),
            const SizedBox(height: 17),
            Text('Последние игры',
                style: TextStyle(
                    color: CupUi.soft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (form.isEmpty)
              Text('Результатов пока нет',
                  style: TextStyle(color: CupUi.muted, fontSize: 12))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in form.reversed)
                  Tooltip(
                      message:
                          '${m.dayLabel} · ${m.home} — ${m.away} · ${m.score}',
                      child: InkWell(
                          onTap: () => open(m),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color:
                                      (victory(m) ? CupUi.green : CupUi.coral)
                                          .withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(victory(m) ? 'В' : 'П',
                                  style: TextStyle(
                                      color: victory(m)
                                          ? CupUi.green
                                          : CupUi.coral,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13))))),
              ]),
          ])),
      CupCard(
          padding: const EdgeInsets.all(17),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.account_tree_rounded, color: CupUi.ice, size: 21),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Рассев III тура',
                      style: TextStyle(
                          color: CupUi.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700))),
              CupTag(
                  text: cup.firstTwoComplete ? 'ИТОГ' : 'ПРОГНОЗ',
                  color: cup.firstTwoComplete ? CupUi.green : CupUi.yellow,
                  filled: true),
            ]),
            const SizedBox(height: 13),
            Text(
                spot < 0
                    ? 'Позиция пока не определена'
                    : 'ГРУППА ${letters[spot]}',
                style: TextStyle(
                    color: CupUi.ice,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 9),
            if (spot >= 0)
              Text(
                  'Соперники: ${groups[spot].where((t) => !sameClub(t, widget.team.fullName)).join(', ')}',
                  style:
                      TextStyle(color: CupUi.soft, fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            Text(
                'Обновляется по подтверждённым матчам I–II туров. Неофициальный прогноз до завершения обоих туров.',
                style:
                    TextStyle(color: CupUi.muted, fontSize: 12, height: 1.5)),
          ])),
      CupSection(
          title: 'По турам',
          subtitle: 'Очки с учётом официальных стыковых матчей'),
      for (final round in [CupTour.first, CupTour.second, CupTour.third])
        _roundRow(round),
    ]);
  }

  Widget _roundRow(CupTour round) {
    final cup = CupTournament(widget.matches);
    final rows = cup
        .tourMatches(round)
        .where((m) =>
            sameClub(m.home, widget.team.fullName) ||
            sameClub(m.away, widget.team.fullName))
        .toList();
    final done = rows.where((m) => m.finished).toList();
    final ranked = ranking(done, participants: [widget.team.fullName]);
    final rank = ranked.where((r) => sameClub(r.team, widget.team.fullName));
    final points = rank.isEmpty ? 0 : rank.first.pts;
    final label = round == CupTour.first
        ? 'I ТУР'
        : round == CupTour.second
            ? 'II ТУР'
            : 'III ТУР';
    return CupCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
              width: 35,
              height: 35,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: CupUi.redMuted,
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.sports_hockey, color: CupUi.ice, size: 18)),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        color: CupUi.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${done.length} сыграно · ${rows.length} опубликовано',
                    style: TextStyle(color: CupUi.muted, fontSize: 12)),
              ])),
          Text('$points О',
              style: TextStyle(
                  color: CupUi.ice, fontSize: 16, fontWeight: FontWeight.w700)),
        ]));
  }

  Widget _summaryMetric(String value, String label) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                color: CupUi.white,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                height: 1.15)),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: CupUi.muted, fontSize: 12)),
      ]);

  Widget _leaders() {
    if (statistics == null) {
      if (loadingStats)
        return const Padding(
            padding: EdgeInsets.all(20), child: LinearProgressIndicator());
      return CupMessage(
          title: 'Лидеры не загружены',
          message: 'Статистика ФХР сейчас недоступна. Попробуй обновить.',
          retry: fetchStats);
    }
    final leaders = sortCupPlayers(
            statistics!.skaters.where((p) =>
                sameClub('${p.team} ${p.city}', widget.team.fullName) ||
                ((p.city.isEmpty || widget.team.city.isEmpty) &&
                    sameClub(p.team, widget.team.name))),
            PlayerStatSort.points)
        .take(5)
        .toList();
    return CupCard(
        child: Column(children: [
      if (loadingStats) const LinearProgressIndicator(minHeight: 2),
      if (staleStats)
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(children: [
              Expanded(
                  child: Text('Сохранённая статистика',
                      style: TextStyle(color: CupUi.muted, fontSize: 12))),
              IconButton(
                  tooltip: 'Обновить статистику',
                  onPressed: loadingStats ? null : fetchStats,
                  icon: const Icon(Icons.refresh_rounded, size: 20)),
            ])),
      if (leaders.isEmpty)
        Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
                'ФХР пока не опубликовал статистику игроков этой команды.',
                style:
                    TextStyle(color: CupUi.muted, fontSize: 13, height: 1.5))),
      for (var i = 0; i < leaders.length; i++) ...[
        if (i > 0) const CupDiv(indent: 16),
        ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(leaders[i].name,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${leaders[i].goals} + ${leaders[i].assists} · ${leaders[i].games} игр',
                style: TextStyle(color: CupUi.muted, fontSize: 12)),
            trailing: Text('${leaders[i].points}',
                style: TextStyle(
                    color: CupUi.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CupPlayerProfilePage(player: leaders[i])))),
      ],
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final fixtures = teamFixtures(widget.matches, widget.team.fullName);
    final played = fixtures.where((m) => m.finished).toList();
    final upcoming =
        fixtures.where((m) => !m.finished).toList().reversed.toList();
    final table = ranking(widget.matches,
        participants: widget.teams.map((t) => t.fullName));
    final ranks = table.where((r) => sameClub(r.team, widget.team.fullName));
    final rank = ranks.isEmpty ? null : ranks.first;
    final bounds =
        rank == null ? null : QualificationBounds.forTeam(table, rank);
    final h2h = opponent == null
        ? <Match>[]
        : meetings(widget.matches, widget.team.fullName, opponent!)
            .where((m) => m.finished)
            .toList();
    int wins = 0, gf = 0, ga = 0;
    for (final m in h2h) {
      final g = m.goals!;
      final home = sameClub(m.home, widget.team.fullName);
      gf += g[home ? 0 : 1];
      ga += g[home ? 1 : 0];
      if (g[home ? 0 : 1] > g[home ? 1 : 0]) wins++;
    }
    return DefaultTabController(
        length: 4,
        child: Scaffold(
            appBar: AppBar(
                title: Text(widget.team.name),
                actions: [
                  IconButton(
                      tooltip: following
                          ? 'Убрать из моих команд'
                          : 'Добавить в мои команды',
                      onPressed: followingBusy ? null : toggleFollowing,
                      icon: Icon(
                          following
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: following ? CupUi.yellow : CupUi.soft)),
                  IconButton(
                      tooltip: 'Поделиться',
                      icon: const Icon(Icons.ios_share),
                      onPressed: () =>
                          shareCard(context, widget.team.fullName, [
                            if (rank != null)
                              '${rank.pts} очков · ${rank.gp} игр',
                            '${played.length} завершённых матчей',
                            'Кубок России U16'
                          ])),
                ],
                bottom: const TabBar(isScrollable: true, tabs: [
                  Tab(text: 'Обзор'),
                  Tab(text: 'Матчи'),
                  Tab(text: 'Личные встречи'),
                  Tab(text: 'Расклады')
                ])),
            body: SafeArea(
                child: TabBarView(children: [
              ListView(key: const PageStorageKey('team-overview'), children: [
                CupCard(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                    width: 76,
                                    height: 76,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    child: fhrTeamLogo(widget.team.logo,
                                        size: 60)),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('Кубок России · U16',
                                          style: TextStyle(
                                              color: CupUi.muted,
                                              fontSize: 12)),
                                      const SizedBox(height: 6),
                                      Text(widget.team.name,
                                          style: TextStyle(
                                              color: CupUi.white,
                                              fontFamily: 'Manrope',
                                              fontSize: 24,
                                              height: 1.2,
                                              fontWeight: FontWeight.w800)),
                                      if (widget.team.city.isNotEmpty)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 5),
                                            child: Text(widget.team.city,
                                                style: TextStyle(
                                                    color: CupUi.muted,
                                                    fontSize: 13))),
                                    ])),
                              ]),
                          const SizedBox(height: 24),
                          Row(children: [
                            Expanded(
                                child: _summaryMetric(
                                    rank == null
                                        ? '—'
                                        : '${table.indexOf(rank) + 1}',
                                    'Место')),
                            Expanded(
                                child: _summaryMetric(
                                    rank == null ? '—' : '${rank.pts}',
                                    'Очки')),
                            Expanded(
                                child: _summaryMetric(
                                    '${played.length}', 'Матчи')),
                          ]),
                          const SizedBox(height: 22),
                          SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => TeamRosterPage(
                                              team: widget.team))),
                                  icon: const Icon(Icons.groups_outlined,
                                      size: 20),
                                  label: const Text('Состав команды'))),
                        ])),
                teamPulse(fixtures, rank, table),
                CupSection(title: 'Последние матчи'),
                for (final m in played.take(5)) fixture(m),
                CupSection(title: 'Лидеры команды'),
                _leaders(),
                const SizedBox(height: 24),
              ]),
              ListView(key: const PageStorageKey('team-matches'), children: [
                CupSection(title: 'Расписание'),
                if (upcoming.isEmpty)
                  const CupMessage(
                      title: 'Новых матчей пока нет',
                      message: 'Расписание появится после публикации ФХР.'),
                for (final m in upcoming) fixture(m),
                CupSection(title: 'Результаты'),
                for (final m in played) fixture(m)
              ]),
              ListView(
                children: [
                  CupSection(
                      title: 'Личные встречи',
                      subtitle: 'Все опубликованные этапы этого Кубка'),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButton<String>(
                          isExpanded: true,
                          value: opponent,
                          hint: const Text('Выбери соперника'),
                          items: [
                            for (final t in widget.teams
                                .where((t) => t.id != widget.team.id))
                              DropdownMenuItem(
                                  value: t.fullName,
                                  child: Text(t.fullName,
                                      overflow: TextOverflow.ellipsis))
                          ],
                          onChanged: (v) => setState(() => opponent = v))),
                  if (opponent != null) ...[
                    CupCard(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                            '${h2h.length} матчей · Победы $wins : ${h2h.length - wins}\nШайбы $gf : $ga',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700))),
                    for (final m in h2h) fixture(m),
                    if (h2h.isEmpty)
                      const CupMessage(
                          title: 'Встреч пока нет',
                          message:
                              'Завершённые матчи этих команд не опубликованы.')
                  ]
                ],
              ),
              ListView(children: [
                CupCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      Text('Аналитика команды',
                          style: TextStyle(
                              color: CupUi.ice,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 9),
                      Text(
                          'Расчёт шансов, полезные для клуба исходы, путь в финал и влияние матчей',
                          style: TextStyle(
                              color: CupUi.soft, fontSize: 13, height: 1.5)),
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.radar_rounded),
                            label: const Text('Открыть аналитику'),
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => CommandCenterPage(
                                        matches: widget.matches,
                                        clubs: widget.teams,
                                        initialTeam: widget.team.fullName,
                                        onTeam: (name) {
                                          final found = widget.teams
                                              .where((t) =>
                                                  sameClub(t.fullName, name))
                                              .toList();
                                          if (found.isNotEmpty)
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) => TeamHubPage(
                                                        team: found.first,
                                                        matches: widget.matches,
                                                        teams: widget.teams)));
                                        },
                                        onMatch: open))),
                          )),
                    ])),
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ScenarioPage(
                                    matches: widget.matches,
                                    teams: widget.teams
                                        .map((t) => t.fullName)
                                        .toList(),
                                    teamLogos: {
                                      for (final t in widget.teams)
                                        t.fullName: t.logo
                                    },
                                    initialTeam: widget.team.fullName))),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Открыть симулятор'))),
                CupSection(
                    title: 'Путь в золотой финал',
                    subtitle: 'Первые 8 мест общей квалификации'),
                if (rank != null && bounds != null) ...[
                  CupCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Сейчас: ${table.indexOf(rank) + 1}-е место',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                            Text(
                                '${rank.pts} очков · осталось ${bounds.remaining} из 14 игр'),
                            const SizedBox(height: 14),
                            Text(
                                'Диапазон очков: ${bounds.minPoints}–${bounds.maxPoints}'),
                            Text(
                                'Границы места по очкам: ${bounds.bestBound}–${bounds.worstBound}'),
                            const SizedBox(height: 14),
                            Text(table.length != 20
                                ? 'Список участников неполный: вывод о проходе пока недоступен.'
                                : bounds.worstBound <= 8
                                    ? 'Место в восьмёрке обеспечено по очкам.'
                                    : bounds.bestBound > 8
                                        ? 'Войти в восьмёрку по очкам уже невозможно.'
                                        : 'Борьба за восьмёрку продолжается: результат зависит от своих матчей и соперников.'),
                            if (table.length >= 8)
                              Text(
                                  'Текущая граница восьмёрки: ${table[7].pts} очков. Это не итоговый проходной балл.')
                          ])),
                  const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                          'Границы консервативные: учитывают максимум 2 очка за победу и оставшиеся игры каждого клуба. Не все места внутри диапазона обязательно достижимы. При равенстве очков действуют дополнительные критерии ФХР; будущий рассев и ещё не опубликованные пары здесь не угадываются.')),
                ] else
                  const CupMessage(
                      title: 'Недостаточно данных',
                      message:
                          'Нужна таблица квалификации. Потяни календарь на главной вниз для обновления.')
              ]),
            ]))));
  }
}
