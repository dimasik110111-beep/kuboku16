import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_services.dart';
import 'command_center_page.dart';
import 'cup_data.dart';
import 'match_center.dart';
import 'player_statistics_page.dart';
import 'scenario_page.dart';
import 'team_hub.dart';
import 'team_pages.dart';
import 'tournament_page.dart';
import 'ui_kit.dart';

const fhrCupLogo = 'https://img.fhr.ru/tournaments/b6/ef/25008909.webp';

class JuniorApp extends StatefulWidget {
  final http.Client? client;
  const JuniorApp({super.key, this.client});
  @override
  State<JuniorApp> createState() => _JuniorAppState();
}

class _JuniorAppState extends State<JuniorApp> {
  bool light = true;
  @override
  void initState() {
    super.initState();
    CupUi.light = light;
    _restoreTheme();
  }

  Future<void> _restoreTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted)
        setState(() => light = prefs.getBool('junior_u16_light_theme') ?? true);
    } catch (e) {
      Diagnostics.record('theme read', e);
    }
  }

  Future<void> switchTheme() async {
    setState(() {
      light = !light;
      CupUi.light = light;
    });
    final saved = light;
    try {
      await (await SharedPreferences.getInstance())
          .setBool('junior_u16_light_theme', saved);
    } catch (e) {
      Diagnostics.record('theme save', e);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'JUNIOR U16 · Кубок России',
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: juniorTheme(light),
        themeAnimationDuration: const Duration(milliseconds: 220),
        themeAnimationCurve: Curves.easeOutCubic,
        home: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    light ? Brightness.dark : Brightness.light,
                statusBarBrightness: light ? Brightness.light : Brightness.dark,
                systemNavigationBarColor: CupUi.surface,
                systemNavigationBarIconBrightness:
                    light ? Brightness.dark : Brightness.light),
            child: ScoresHome(
                light: light,
                onSwitchTheme: switchTheme,
                client: widget.client)),
      );
}

class ScoresHome extends StatefulWidget {
  final bool light;
  final VoidCallback onSwitchTheme;
  final http.Client? client;
  const ScoresHome(
      {super.key,
      required this.light,
      required this.onSwitchTheme,
      this.client});
  @override
  State<ScoresHome> createState() => _ScoresHomeState();
}

class _ScoresHomeState extends State<ScoresHome> with WidgetsBindingObserver {
  late final api = FhrApiClient(widget.client ?? http.Client());
  Timer? timer;
  final visited = <int>{0};
  int tab = 0, filter = 0;
  bool loading = false, loadingTeams = false, cached = false;
  DateTime? date, updatedAt;
  String? error, teamError;
  String search = '';
  List<Match> games = [];
  List<TeamInfo> clubs = [];
  Set<String> favorites = {};
  Future<void>? _refreshing, _clubsLoading;
  Future<void> _favoriteWrites = Future.value();
  static const filters = ['Все', 'LIVE', 'Результаты', 'Расписание'];
  DateTime get mskNow => DateTime.now().toUtc().add(const Duration(hours: 3));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _startPolling();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('junior_u16_calendar_v9');
      final savedClubs = await FeedCache.read('/api/v1/teams');
      if (!mounted) return;
      setState(() {
        favorites = (p.getStringList('junior_favorites') ?? []).toSet();
        tab = (p.getInt('junior_tab') ?? 0).clamp(0, 5);
        visited.add(tab);
      });
      // A damaged feed must not discard independent preferences and teams.
      try {
        if (raw != null) {
          final feed = FhrFeed.fromApi(
              Map<String, dynamic>.from(jsonDecode(raw) as Map));
          setState(() {
            games = feed.matches;
            updatedAt = feed.updatedAt;
            cached = true;
          });
        }
      } catch (e) {
        Diagnostics.record('calendar restore', e);
      }
      try {
        if (savedClubs?['teams'] is List)
          setState(() => clubs = (savedClubs!['teams'] as List)
              .whereType<Map>()
              .map((t) => TeamInfo.fromApi(Map<String, dynamic>.from(t)))
              .toList());
      } catch (e) {
        Diagnostics.record('teams restore', e);
      }
    } catch (e) {
      Diagnostics.record('preferences read', e);
    }
    if (mounted) {
      unawaited(refresh());
      unawaited(loadClubs());
    }
  }

  void _startPolling() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true))
        unawaited(refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    timer?.cancel();
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(refresh());
      if (clubs.isEmpty) unawaited(loadClubs());
      _startPolling();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.client == null) api.client.close();
    super.dispose();
  }

  Future<void> refresh() =>
      _refreshing ??= _refreshData().whenComplete(() => _refreshing = null);
  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final feed = await api.calendar();
      if (!mounted) return;
      final emptyFallback = feed.matches.isEmpty && games.isNotEmpty;
      final published = feed.matches.map((m) => m.key).toSet();
      final issues = [
        ...feed.issues,
        if (emptyFallback) 'Сервер вернул пустой календарь'
      ];
      var rows =
          reconcileCalendar(games, feed.matches, partial: issues.isNotEmpty)
              .map((m) {
        // A retained LIVE row is historical until the current feed verifies it.
        if (!emptyFallback && m.isLive && !published.contains(m.key)) {
          return Match(m.date, m.home, m.away, m.score, m.stage, m.arena,
              timeMsk: m.timeMsk,
              status: 'UNKNOWN',
              scoreNote: m.scoreNote,
              gameId: m.gameId,
              matchUrl: m.matchUrl);
        }
        return m;
      }).toList();
      final stamp = emptyFallback ? updatedAt : feed.updatedAt;
      setState(() {
        games = rows;
        updatedAt = stamp;
        cached = emptyFallback;
        error = issues.isNotEmpty
            ? 'Показаны последние данные · календарь ФХР неполный'
            : null;
      });
      Future<void> saveRows() async {
        try {
          final p = await SharedPreferences.getInstance();
          await p.setString(
              'junior_u16_calendar_v9',
              jsonEncode(FhrFeed(
                      rows,
                      stamp,
                      issues,
                      feed.groupsFetched,
                      feed.allStagesComplete && issues.isEmpty,
                      feed.expectedMatchCount)
                  .toCache()));
        } catch (e) {
          Diagnostics.record('calendar save', e);
        }
      }

      await saveRows();
      if (!mounted) return;
      // Calendar appears immediately; verification of LIVE runs afterwards.
      try {
        final details =
            await api.liveCheck().timeout(const Duration(seconds: 8));
        if (!mounted) return;
        final indexed = {for (final d in details) '${d['gameId']}': d};
        rows = rows
            .map((m) => indexed.containsKey('${m.gameId}')
                ? m.withDetail(indexed['${m.gameId}']!)
                : m)
            .toList();
        setState(() => games = rows);
      } catch (e) {
        Diagnostics.record('live verification', e);
      }
      await saveRows();
    } catch (e) {
      Diagnostics.record('calendar', e);
      if (mounted)
        setState(() {
          cached = games.isNotEmpty;
          error = cached
              ? 'Нет связи · показаны сохранённые данные'
              : 'Не удалось загрузить матчи';
        });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadClubs() =>
      _clubsLoading ??= _loadClubs().whenComplete(() => _clubsLoading = null);
  Future<void> _loadClubs() async {
    if (!mounted) return;
    setState(() => loadingTeams = true);
    try {
      final data = await api.teams();
      if (!mounted) return;
      setState(() {
        if (data.isNotEmpty) clubs = data;
        teamError =
            data.length < 20 ? 'ФХР передала неполный список команд' : null;
      });
    } catch (e) {
      Diagnostics.record('teams', e);
      if (mounted)
        setState(() => teamError = 'Не удалось обновить список команд');
    } finally {
      if (mounted) setState(() => loadingTeams = false);
    }
  }

  void selectTab(int value) {
    if (tab == value) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      tab = value;
      visited.add(value);
    });
    _saveTab(value);
  }

  Future<void> _saveTab(int value) async {
    try {
      await (await SharedPreferences.getInstance()).setInt('junior_tab', value);
    } catch (e) {
      Diagnostics.record('tab save', e);
    }
  }

  String normalize(String s) => s
      .toUpperCase()
      .replaceAll('Ё', 'Е')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  TeamInfo? findClub(String team) {
    final key = normalize(team);
    for (final t in clubs) {
      if (normalize(t.fullName) == key || normalize(t.name) == key) return t;
    }
    return null;
  }

  void openMatch(Match match) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => MatchCenterPage(
              match: match,
              homeTeam: findClub(match.home),
              awayTeam: findClub(match.away),
              matches: games)));
  void openClub(TeamInfo team) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              TeamHubPage(team: team, matches: games, teams: clubs)));
  void _openTeam(String name) {
    final club = findClub(name);
    if (club != null)
      openClub(club);
    else
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Карточка команды ещё не загружена')));
  }

  void openCommandCenter() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CommandCenterPage(
              matches: games,
              clubs: clubs,
              onTeam: _openTeam,
              onMatch: openMatch)));
  void openScenarios() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ScenarioPage(
              matches: games,
              teams: clubs.map((t) => t.fullName).toList(),
              teamLogos: {for (final t in clubs) t.fullName: t.logo})));
  void toggleFavorite(Match match) {
    setState(() {
      if (!favorites.remove(match.key)) favorites.add(match.key);
    });
    final saved = favorites.toList();
    _favoriteWrites = _favoriteWrites.then((_) async {
      try {
        await (await SharedPreferences.getInstance())
            .setStringList('junior_favorites', saved);
      } catch (e) {
        Diagnostics.record('favorite save', e);
      }
    });
  }

  String dayText(DateTime d) {
    if (DateUtils.isSameDay(d, mskNow)) return 'Сегодня';
    if (DateUtils.isSameDay(d, mskNow.add(const Duration(days: 1))))
      return 'Завтра';
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  String refreshTime() {
    if (updatedAt == null) return 'Официальные данные ФХР';
    final d = updatedAt!.toUtc().add(const Duration(hours: 3));
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${cached ? 'Сохранено' : 'Обновлено'} ${DateUtils.isSameDay(d, mskNow) ? '' : '${d.day}.${d.month.toString().padLeft(2, '0')} · '}$time МСК';
  }

  Widget _header() => Container(
      color: CupUi.surface,
      child: SafeArea(
          bottom: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 9, 8, 9),
              child: Row(children: [
                Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: CupUi.red,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('u16',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1))),
                const SizedBox(width: 11),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('JUNIOR',
                          style: TextStyle(
                              fontFamily: 'Manrope',
                              color: CupUi.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                      Text('Кубок России · 2026/27',
                          style: TextStyle(color: CupUi.muted, fontSize: 10)),
                    ])),
                IconButton(
                    tooltip: 'Избранное',
                    onPressed: () => selectTab(5),
                    icon: Icon(
                        tab == 5
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: tab == 5 ? CupUi.action : CupUi.soft)),
                PopupMenuButton<String>(
                    tooltip: 'Разделы',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) {
                      switch (value) {
                        case 'players':
                          selectTab(3);
                        case 'teams':
                          selectTab(4);
                        case 'command':
                          openCommandCenter();
                        case 'scenario':
                          openScenarios();
                        case 'theme':
                          widget.onSwitchTheme();
                        case 'settings':
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AppSettingsPage()));
                        case 'refresh':
                          unawaited(refresh());
                      }
                    },
                    itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'players', child: Text('Игроки')),
                          PopupMenuItem(value: 'teams', child: Text('Команды')),
                          PopupMenuItem(
                              value: 'command',
                              child: Text('Аналитика турнира')),
                          PopupMenuItem(
                              value: 'scenario', child: Text('Мой прогноз')),
                          PopupMenuItem(
                              value: 'theme', child: Text('Сменить тему')),
                          PopupMenuItem(
                              value: 'settings', child: Text('Настройки')),
                          PopupMenuItem(
                              value: 'refresh', child: Text('Обновить ФХР')),
                        ]),
              ]))));
  Widget _syncStatus() => Padding(
      padding: const EdgeInsets.fromLTRB(20, 5, 12, 5),
      child: Row(children: [
        if (loading)
          const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5))
        else
          Icon(
              error != null || cached
                  ? Icons.cloud_off_outlined
                  : Icons.check_circle_outline_rounded,
              size: 13,
              color: error != null || cached ? CupUi.yellow : CupUi.green),
        const SizedBox(width: 7),
        Expanded(
            child: Text(error ?? refreshTime(),
                maxLines: 2,
                style:
                    TextStyle(color: CupUi.muted, fontSize: 10, height: 1.4))),
        if (error != null)
          SizedBox(
              height: 44,
              child: TextButton(
                  onPressed: loading ? null : refresh,
                  child: const Text('Повторить'))),
      ]));
  Widget _nav() {
    const labels = ['Обзор', 'Матчи', 'Таблица', 'Игроки', 'Команды'];
    const icons = [
      Icons.grid_view_rounded,
      Icons.sports_hockey_rounded,
      Icons.leaderboard_rounded,
      Icons.person_rounded,
      Icons.groups_rounded
    ];
    return Container(
        decoration: BoxDecoration(
            color: CupUi.surface,
            border: Border(top: BorderSide(color: CupUi.stroke))),
        child: SafeArea(
            top: false,
            child: Row(children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                    child: Semantics(
                        selected: tab == i,
                        button: true,
                        child: InkWell(
                            onTap: () => selectTab(i),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          width: 46,
                                          height: 32,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: tab == i
                                                  ? CupUi.redMuted
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(11)),
                                          child: Icon(icons[i],
                                              size: 21,
                                              color: tab == i
                                                  ? CupUi.action
                                                  : CupUi.muted)),
                                      const SizedBox(height: 5),
                                      Text(labels[i],
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: tab == i
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: tab == i
                                                  ? CupUi.white
                                                  : CupUi.muted)),
                                    ]))))),
            ])));
  }

  List<Match> _ordered(Iterable<Match> source) => source.toList()
    ..sort((a, b) {
      int rank(Match m) => m.isLive
          ? 0
          : m.finished
              ? 2
              : 1;
      final group = rank(a).compareTo(rank(b));
      if (group != 0) return group;
      final aStamp = '${a.date} ${a.timeMsk}',
          bStamp = '${b.date} ${b.timeMsk}';
      return a.finished ? bStamp.compareTo(aStamp) : aStamp.compareTo(bStamp);
    });
  List<Match> _filtered() => _ordered(games.where((m) {
        if (filter == 1 && !m.isLive) return false;
        if (filter == 2 && !m.finished) return false;
        if (filter == 3 && (m.finished || m.isLive)) return false;
        return date == null || DateUtils.isSameDay(m.matchDate, date);
      }));
  Widget _matchCard(Match game) {
    final score = game.goals;
    final scored = game.finished || game.isLive || game.hasScore;
    final live = game.isLive && !cached;
    Widget team(String name, String? logo, int index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          fhrTeamLogo(logo, size: 26),
          const SizedBox(width: 10),
          Expanded(
              child: Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: CupUi.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35))),
          const SizedBox(width: 12),
          if (scored)
            Text('${score?[index] ?? '–'}',
                style: TextStyle(
                    color: CupUi.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()])),
        ]));
    return RepaintBoundary(
        child: CupCard(
            key: ValueKey('match-${game.key}'),
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: InkWell(
                onTap: () => openMatch(game),
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 8, 8, 12),
                    child: Column(children: [
                      Row(children: [
                        if (live) ...[
                          const CupLivePulse(),
                          const SizedBox(width: 6)
                        ],
                        Expanded(
                            child: Text(
                                live
                                    ? 'В эфире'
                                    : game.isLive && cached
                                        ? 'Счёт из кэша'
                                        : game.finished
                                            ? 'Завершён${game.scoreNote.isEmpty ? '' : ' · ${game.scoreNote}'}'
                                            : game.timeMsk.isEmpty
                                                ? 'Время уточняется'
                                                : '${game.timeMsk} МСК',
                                style: TextStyle(
                                    color: live ? CupUi.green : CupUi.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600))),
                        IconButton(
                            tooltip: favorites.contains(game.key)
                                ? 'Убрать из избранного'
                                : 'Сохранить матч',
                            onPressed: () => toggleFavorite(game),
                            icon: Icon(
                                favorites.contains(game.key)
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                size: 19,
                                color: favorites.contains(game.key)
                                    ? CupUi.action
                                    : CupUi.dim)),
                      ]),
                      Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Column(children: [
                            team(game.home, findClub(game.home)?.logo, 0),
                            team(game.away, findClub(game.away)?.logo, 1),
                          ])),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: Text(game.stage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(color: CupUi.dim, fontSize: 10))),
                        Icon(Icons.chevron_right_rounded,
                            size: 16, color: CupUi.dim),
                      ]),
                    ])))));
  }

  Widget _homePage() {
    final today =
        _ordered(games.where((m) => DateUtils.isSameDay(m.matchDate, mskNow)));
    final live = cached ? <Match>[] : games.where((m) => m.isLive).toList();
    final upcoming = _ordered(games.where((m) =>
        !m.finished &&
        !m.isLive &&
        (m.matchDate == null ||
            !m.matchDate!
                .isBefore(DateTime(mskNow.year, mskNow.month, mskNow.day)))));
    final recent = _ordered(games.where((m) => m.finished));
    final focus = live.isNotEmpty
        ? live
        : today.isNotEmpty
            ? today
            : upcoming.isNotEmpty
                ? upcoming
                : recent;
    final heading = live.isNotEmpty
        ? 'Сейчас на льду'
        : today.isNotEmpty
            ? 'Матчи сегодня'
            : upcoming.isNotEmpty
                ? 'Ближайшие игры'
                : 'Последние результаты';
    return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
            key: const PageStorageKey('overview'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Обзор турнира',
                                  style: TextStyle(
                                      color: CupUi.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 5),
                              Text('Кубок России',
                                  style: TextStyle(
                                      color: CupUi.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                      letterSpacing: -1.1)),
                            ])),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                                color: CupUi.redMuted,
                                borderRadius: BorderRadius.circular(9)),
                            child: Text('U16',
                                style: TextStyle(
                                    color: CupUi.action,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800))),
                      ])),
              Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: CupUi.navy,
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.emoji_events_outlined,
                            color: CupUi.signal, size: 26)),
                    const SizedBox(width: 13),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Сезон 2026/27',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                              '${clubs.isEmpty ? 'Кубок России' : '${clubs.length} команд'} · ${games.where((m) => m.finished).length} игр сыграно',
                              style: const TextStyle(
                                  color: Color(0xFFB9C9CC), fontSize: 11)),
                        ])),
                    IconButton(
                        tooltip: 'Турнирная таблица',
                        onPressed: () => selectTab(2),
                        icon: const Icon(Icons.arrow_forward_rounded,
                            color: CupUi.signal, size: 21)),
                  ])),
              CupSection(
                  title: heading,
                  subtitle: live.isNotEmpty
                      ? 'Статус подтверждён ФХР'
                      : today.isNotEmpty
                          ? '${today.length} игр · время московское'
                          : 'Официальный календарь ФХР',
                  trailing: TextButton(
                      onPressed: () => selectTab(1),
                      child: const Text('Все игры'))),
              if (loading && games.isEmpty)
                const SizedBox(height: 240, child: LoadingCards())
              else if (focus.isEmpty)
                CupMessage(
                    icon: Icons.sports_hockey_outlined,
                    title: error == null
                        ? 'Календарь пока пуст'
                        : 'Матчи недоступны',
                    message: error == null
                        ? 'Опубликованные игры появятся после обновления.'
                        : 'Проверь подключение и попробуй ещё раз.',
                    retry: refresh)
              else
                for (final game in focus.take(4)) _matchCard(game),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                  child: Row(children: [
                    Expanded(
                        child: _quickAction(
                            'Мой прогноз',
                            'Расставь свои счёты',
                            Icons.tune_rounded,
                            openScenarios)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _quickAction('Аналитика', 'Форма и шансы команд',
                            Icons.insights_rounded, openCommandCenter)),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Text('Результаты, составы и статистика — ФХР Джуниор.',
                      style: TextStyle(
                          color: CupUi.dim, fontSize: 10, height: 1.5))),
            ]));
  }

  Widget _quickAction(
          String title, String subtitle, IconData icon, VoidCallback onTap) =>
      Material(
          color: CupUi.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: CupUi.stroke)),
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: CupUi.action, size: 23),
                        const SizedBox(height: 14),
                        Text(title,
                            style: TextStyle(
                                color: CupUi.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text(subtitle,
                            style: TextStyle(
                                color: CupUi.muted, fontSize: 10, height: 1.5)),
                      ]))));
  Widget _matchFilters() => Column(children: [
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              for (var i = 0; i < filters.length; i++)
                Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                        label: Text(filters[i]),
                        selected: filter == i,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: filter == i ? CupUi.action : CupUi.muted),
                        selectedColor: CupUi.redMuted,
                        backgroundColor: CupUi.surface,
                        side: BorderSide(
                            color: filter == i
                                ? Colors.transparent
                                : CupUi.stroke),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        onSelected: (_) => setState(() => filter = i)))
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              OutlinedButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text(date == null ? 'Любая дата' : dayText(date!))),
              if (date != null)
                IconButton(
                    tooltip: 'Все даты',
                    onPressed: () => setState(() => date = null),
                    icon: const Icon(Icons.close_rounded, size: 19)),
              const Spacer(),
              TextButton(
                  onPressed: () => setState(() {
                        date = mskNow;
                        filter = 0;
                      }),
                  child: const Text('Сегодня')),
            ])),
      ]);
  Future<void> _chooseDate() async {
    final days = games.map((m) => m.matchDate).whereType<DateTime>().toList()
      ..sort();
    final first = days.isEmpty ? DateTime(2026, 8) : days.first;
    final last = days.isEmpty ? DateTime(2027, 12, 31) : days.last;
    var initial = date ?? mskNow;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last);
    if (picked != null && mounted) setState(() => date = picked);
  }

  Widget _matchesPage({bool saved = false}) {
    final visible = saved
        ? _ordered(games.where((m) => favorites.contains(m.key)))
        : _filtered();
    final items = <Object>[];
    String? previous;
    for (final game in visible) {
      final label = game.isLive
          ? 'В эфире'
          : game.matchDate == null
              ? 'Дата уточняется'
              : dayText(game.matchDate!);
      if (label != previous) {
        items.add(label);
        previous = label;
      }
      items.add(game);
    }
    // Build only visible cards, even with hundreds of games in the season.
    return RefreshIndicator(
        onRefresh: refresh,
        child: ListView.builder(
            key: PageStorageKey(saved ? 'favorites' : 'matches'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: items.isEmpty ? 2 : items.length + 1,
            itemBuilder: (context, index) {
              if (index == 0)
                return Column(children: [
                  CupSection(
                      title: saved ? 'Избранное' : 'Матчи',
                      subtitle: saved
                          ? '${visible.length} сохранено на этом устройстве'
                          : 'Календарь и результаты турнира'),
                  if (!saved) _matchFilters(),
                ]);
              if (items.isEmpty)
                return loading && games.isEmpty
                    ? const SizedBox(height: 320, child: LoadingCards())
                    : CupMessage(
                        icon: saved
                            ? Icons.bookmark_border_rounded
                            : Icons.event_outlined,
                        title:
                            saved ? 'Сохрани важные матчи' : 'Игр не найдено',
                        message: saved
                            ? 'Нажми на закладку в карточке матча — он появится здесь.'
                            : 'Попробуй другую дату или сбрось фильтры.',
                        actionLabel: 'Сбросить фильтры',
                        retry: saved
                            ? null
                            : () => setState(() {
                                  date = null;
                                  filter = 0;
                                }));
              final item = items[index - 1];
              if (item is Match) return _matchCard(item);
              return Padding(
                  padding: const EdgeInsets.fromLTRB(21, 17, 21, 7),
                  child: Text('$item',
                      style: TextStyle(
                          color: CupUi.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)));
            }));
  }

  Widget _teamPage() {
    final query = normalize(search);
    final list = clubs
        .where((t) => normalize('${t.name} ${t.city}').contains(query))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return RefreshIndicator(
        onRefresh: loadClubs,
        child: ListView.builder(
            key: const PageStorageKey('teams'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: list.length + 1,
            itemBuilder: (context, index) {
              if (index == 0)
                return Column(children: [
                  CupSection(
                      title: 'Команды',
                      subtitle:
                          '${clubs.length} участников · составы и статистика'),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
                      child: TextField(
                          onChanged: (value) => setState(() => search = value),
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search_rounded),
                              hintText: 'Команда или город'))),
                  if (loadingTeams && clubs.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator()),
                  if (teamError != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(children: [
                          Expanded(
                              child: Text(teamError!,
                                  style: TextStyle(
                                      color: CupUi.muted, fontSize: 12))),
                          TextButton(
                              onPressed: loadClubs,
                              child: const Text('Повторить')),
                        ])),
                  if (list.isEmpty && !loadingTeams)
                    CupMessage(
                        icon: Icons.search_off_rounded,
                        title: clubs.isEmpty
                            ? 'Команды недоступны'
                            : 'Нет такой команды',
                        message: clubs.isEmpty
                            ? 'Загрузи список участников, когда появится связь.'
                            : 'Проверь название команды или города.',
                        retry: clubs.isEmpty ? loadClubs : null),
                ]);
              final team = list[index - 1];
              return CupCard(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 7),
                      leading: fhrTeamLogo(team.logo, size: 38),
                      onTap: () => openClub(team),
                      title: Text(team.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      subtitle: Text(team.city,
                          style: TextStyle(color: CupUi.muted, fontSize: 12)),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: CupUi.dim, size: 20)));
            }));
  }

  Widget _page(int index) {
    switch (index) {
      case 0:
        return _homePage();
      case 1:
        return _matchesPage();
      case 2:
        return TournamentPage(
            matches: games,
            teams: clubs.map((t) => t.fullName),
            teamLogo: (name) => findClub(name)?.logo,
            onTeam: _openTeam,
            onMatch: openMatch);
      case 3:
        return const PlayerStatisticsPage();
      case 4:
        return _teamPage();
      default:
        return _matchesPage(saved: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          _header(),
          _syncStatus(),
          Expanded(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: IndexedStack(index: tab, children: [
                        for (var i = 0; i < 6; i++)
                          if (visited.contains(i))
                            TickerMode(enabled: tab == i, child: _page(i))
                          else
                            const SizedBox.shrink(),
                      ])))),
        ]),
        bottomNavigationBar: _nav(),
      );
}
