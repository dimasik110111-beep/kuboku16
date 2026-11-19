import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'player_statistics.dart';
import 'team_pages.dart';
import 'ui_kit.dart';
import 'player_insights.dart';
import 'app_services.dart';
import 'follow_store.dart';

class PlayerStatisticsPage extends StatefulWidget {
  final http.Client? client;
  const PlayerStatisticsPage({super.key, this.client});
  @override
  State<PlayerStatisticsPage> createState() => _PlayerStatisticsPageState();
}

class _PlayerStatisticsPageState extends State<PlayerStatisticsPage> {
  late final CupStatisticsClient api =
      CupStatisticsClient(widget.client ?? http.Client());
  Future<CupStatistics>? pending;
  CupStatistics? latest;
  String? group, team;
  String search = '';
  bool goalies = false;
  PlayerStatSort sort = PlayerStatSort.points;
  bool loading = false;
  bool cached = false;
  String? loadError;
  int requestGeneration = 0;
  @override
  void initState() {
    super.initState();
    restore();
  }

  @override
  void dispose() {
    if (widget.client == null) api.client.close();
    super.dispose();
  }

  Future<void> restore() async {
    final generation = ++requestGeneration;
    final requestedGroup = group;
    final data = await api.cached(group: requestedGroup);
    if (generation != requestGeneration) return;
    if (!mounted) return;
    if (data != null)
      setState(() {
        latest = data;
        cached = true;
      });
    await load(generation: generation, requestedGroup: requestedGroup);
  }

  Future<void> load({int? generation, String? requestedGroup}) async {
    final current = generation ?? ++requestGeneration;
    final selectedGroup = requestedGroup ?? group;
    if (!mounted) return;
    final future = api.fetch(group: selectedGroup);
    setState(() {
      loading = true;
      pending = future;
      loadError = null;
    });
    try {
      final data = await future;
      if (mounted && current == requestGeneration)
        setState(() {
          latest = data;
          cached = false;
          loadError = null;
          if (team != null && !data.teams.contains(team)) team = null;
        });
    } catch (e) {
      Diagnostics.record('stats', e);
      if (mounted && current == requestGeneration)
        setState(() => loadError =
            'Обновление не удалось. Показаны последние загруженные данные.');
    } finally {
      if (mounted && current == requestGeneration)
        setState(() => loading = false);
    }
  }

  String mskUpdate(DateTime? time) {
    if (time == null) return 'ФХР · время не указано';
    final local = time.toUtc().add(Duration(hours: 3));
    return 'ФХР · ${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} МСК';
  }

  Widget sectionButton(String label, bool active, VoidCallback onTap) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
              color: active ? CupUi.red : CupUi.raised,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: active ? CupUi.red : CupUi.stroke)),
          child: Text(label,
              maxLines: 1,
              style: TextStyle(
                  color: active ? Colors.white : CupUi.soft,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ));
  }

  Widget filterWrap(String title, Widget child) => CupCard(
      margin: EdgeInsets.fromLTRB(12, 3, 12, 5),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        SizedBox(
            width: 72,
            child: Text(title,
                style: TextStyle(
                    color: CupUi.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800))),
        Expanded(child: child),
      ]));
  Widget groupFilter(CupStatistics source) => filterWrap(
      'ЭТАП',
      DropdownButtonHideUnderline(
          child: DropdownButton<String>(
        isExpanded: true,
        dropdownColor: CupUi.surface,
        value: group ?? '',
        style: TextStyle(
            color: CupUi.white, fontSize: 11, fontWeight: FontWeight.w700),
        items: [
          DropdownMenuItem(
              value: '',
              child: Text('ВЕСЬ ТУРНИР', overflow: TextOverflow.ellipsis)),
          for (final group in <String>{
            ...source.availableGroups
                .where((e) => e.isNotEmpty && e != 'Общая статистика'),
            if (this.group != null) this.group!,
          })
            DropdownMenuItem(
                value: group,
                child:
                    Text(group, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (next) {
          if (next == null || next == (group ?? '')) return;
          setState(() {
            group = next.isEmpty ? null : next;
            team = null;
            latest = null;
            pending = null;
            loadError = null;
            cached = false;
          });
          restore();
        },
      )));
  Widget teamFilter(CupStatistics source) => filterWrap(
      'КОМАНДА',
      DropdownButtonHideUnderline(
          child: DropdownButton<String>(
        isExpanded: true,
        dropdownColor: CupUi.surface,
        value: team ?? '',
        style: TextStyle(
            color: CupUi.white, fontSize: 11, fontWeight: FontWeight.w700),
        items: [
          DropdownMenuItem(
              value: '',
              child: Text('ВСЕ КОМАНДЫ', overflow: TextOverflow.ellipsis)),
          for (final club in source.teams.toSet())
            DropdownMenuItem(
                value: club,
                child:
                    Text(club, overflow: TextOverflow.ellipsis, maxLines: 1)),
        ],
        onChanged: (value) => setState(
            () => team = value == null || value.isEmpty ? null : value),
      )));

  List<PlayerStatSort> get filters => goalies
      ? const [
          PlayerStatSort.savesPercentage,
          PlayerStatSort.gaa,
          PlayerStatSort.wins,
          PlayerStatSort.saves
        ]
      : const [
          PlayerStatSort.points,
          PlayerStatSort.goals,
          PlayerStatSort.assists,
          PlayerStatSort.plusMinus,
          PlayerStatSort.pim,
          PlayerStatSort.pointsPerGame
        ];

  String statValue(CupPlayerStats p, PlayerStatSort s) {
    switch (s) {
      case PlayerStatSort.points:
        return '${p.points}';
      case PlayerStatSort.goals:
        return '${p.goals}';
      case PlayerStatSort.assists:
        return '${p.assists}';
      case PlayerStatSort.plusMinus:
        return p.plusMinus > 0 ? '+${p.plusMinus}' : '${p.plusMinus}';
      case PlayerStatSort.pim:
        return '${p.pim}';
      case PlayerStatSort.pointsPerGame:
        return p.pointsPerGame?.toStringAsFixed(2) ?? '—';
      case PlayerStatSort.savesPercentage:
        return p.savePercentText;
      case PlayerStatSort.gaa:
        return p.gaaText;
      case PlayerStatSort.wins:
        return '${p.wins}';
      case PlayerStatSort.saves:
        return '${p.saves}';
    }
  }

  List<CupPlayerStats> filtered(CupStatistics data) {
    final q = search.toLowerCase().replaceAll('ё', 'е').trim();
    final rows = (goalies ? data.goalies : data.skaters).where((p) {
      if (team != null && p.fullClub != team) return false;
      return q.isEmpty ||
          p.name.toLowerCase().replaceAll('ё', 'е').contains(q) ||
          p.fullClub.toLowerCase().replaceAll('ё', 'е').contains(q) ||
          p.number.contains(q);
    });
    return sortCupPlayers(rows, sort);
  }

  Widget _playerRow(CupPlayerStats player, int index) => InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CupPlayerProfilePage(player: player))),
      child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(children: [
            Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: index < 3 ? CupUi.redMuted : CupUi.raised,
                    borderRadius: BorderRadius.circular(9)),
                child: Text('${index + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: index < 3 ? CupUi.red : CupUi.muted))),
            fhrPlayerPhoto(player.photo, size: 43),
            SizedBox(width: 9),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: CupUi.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Row(children: [
                    fhrTeamLogo(player.teamLogo, size: 17),
                    SizedBox(width: 5),
                    Expanded(
                        child: Text(player.fullClub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: CupUi.muted, fontSize: 10))),
                  ]),
                  SizedBox(height: 3),
                  Text('№${player.number} · ${player.games} игр',
                      style: TextStyle(color: CupUi.dim, fontSize: 10)),
                ])),
            SizedBox(width: 5),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(statValue(player, sort),
                  style: TextStyle(
                      color: CupUi.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text(labelForSort(sort),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: CupUi.muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w800)),
            ]),
            Icon(Icons.chevron_right_rounded, color: CupUi.dim, size: 17),
          ])));

  Widget _podium(List<CupPlayerStats> rows) {
    if (rows.length < 3) return SizedBox.shrink();
    return CupCard(
      margin: EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final i in [0, 1, 2])
          Expanded(
              child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CupPlayerProfilePage(player: rows[i]))),
                  child: Column(children: [
                    Text('${i + 1} МЕСТО',
                        style: TextStyle(
                            color: i == 0 ? CupUi.yellow : CupUi.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 10),
                    Container(
                        padding: EdgeInsets.all(3),
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: i == 0 ? CupUi.yellow : CupUi.stroke,
                                width: 1.5),
                            borderRadius: BorderRadius.circular(12)),
                        child: fhrPlayerPhoto(rows[i].photo, size: 42)),
                    SizedBox(height: 8),
                    Text(rows[i].name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: CupUi.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 5),
                    Text(statValue(rows[i], sort),
                        style: TextStyle(
                            color: i == 0 ? CupUi.yellow : CupUi.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    Text(rows[i].team,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: CupUi.muted, fontSize: 9)),
                  ]))),
      ]),
    );
  }

  Widget _content(CupStatistics data) {
    final rows = filtered(data);
    return CustomScrollView(
        key: const PageStorageKey('player-stats'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverList.list(children: [
            if (loading) const LinearProgressIndicator(),
            if (cached || loadError != null)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child:
                      Text(loadError ?? 'Сохранённая статистика · обновляю…')),
            CupSection(
                title: 'СТАТИСТИКА ИГРОКОВ',
                subtitle: 'Кубок России · сезон 2026/27'),
            CupCard(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                              Text('${data.skaters.length}',
                                  style: TextStyle(
                                      color: CupUi.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(width: 7),
                              Text('ПОЛЕВЫХ',
                                  style: TextStyle(
                                      color: CupUi.muted, fontSize: 10)),
                            ])),
                        Expanded(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                              Text('${data.goalies.length}',
                                  style: TextStyle(
                                      color: CupUi.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(width: 7),
                              Text('ВРАТАРЕЙ',
                                  style: TextStyle(
                                      color: CupUi.muted, fontSize: 10)),
                            ])),
                      ]),
                      const SizedBox(height: 8),
                      Text(mskUpdate(data.updatedAt),
                          style: TextStyle(color: CupUi.muted, fontSize: 11)),
                    ])),
            Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 9),
                child: Row(children: [
                  Expanded(
                      child: sectionButton(
                          'ПОЛЕВЫЕ',
                          !goalies,
                          () => setState(() {
                                goalies = false;
                                sort = PlayerStatSort.points;
                              }))),
                  SizedBox(width: 8),
                  Expanded(
                      child: sectionButton(
                          'ВРАТАРИ',
                          goalies,
                          () => setState(() {
                                goalies = true;
                                sort = PlayerStatSort.savesPercentage;
                              }))),
                ])),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PlayerComparisonPage(data: data))),
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Сравнить игроков'))),
            groupFilter(data),
            teamFilter(data),
            Padding(
                padding: EdgeInsets.fromLTRB(12, 5, 12, 12),
                child: TextField(
                    onChanged: (value) => setState(() => search = value),
                    style: TextStyle(color: CupUi.white, fontSize: 12),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded,
                          color: CupUi.muted, size: 20),
                      hintText: 'Поиск по фамилии, клубу или номеру',
                      hintStyle: TextStyle(color: CupUi.dim, fontSize: 11),
                      filled: true,
                      fillColor: CupUi.surface,
                      border: OutlineInputBorder(
                          borderSide: BorderSide(color: CupUi.stroke),
                          borderRadius: BorderRadius.circular(11)),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: CupUi.stroke),
                          borderRadius: BorderRadius.circular(11)),
                    ))),
            CupSection(
                title: 'РЕЙТИНГ',
                subtitle: 'Сортировка по выбранному показателю'),
            SizedBox(
                height: 48,
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final metric in filters)
                        Padding(
                            padding: EdgeInsets.only(right: 7),
                            child: sectionButton(
                                labelForSort(metric),
                                sort == metric,
                                () => setState(() => sort = metric))),
                    ])),
            if (goalies)
              Padding(
                  padding: EdgeInsets.fromLTRB(17, 10, 17, 3),
                  child: Text(
                      'Отбитые броски показаны в процентах (1,00 у ФХР = 100%). '
                      'Рейтинг учитывает все опубликованные результаты, включая малое число бросков.',
                      style: TextStyle(
                          color: CupUi.muted, fontSize: 10, height: 1.4))),
            _podium(rows),
            CupSection(
                title: 'ВСЕ ИГРОКИ · ${rows.length}',
                subtitle: 'Рейтинги обновляются по публикациям ФХР'),
            if (rows.isEmpty)
              CupMessage(
                  title: 'Ничего не найдено',
                  message: 'Выбери другой этап, команду или поисковый запрос.'),
          ]),
          SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) => _playerRow(rows[i], i)),
          SliverList.list(children: [
            Padding(
                padding: EdgeInsets.fromLTRB(17, 2, 17, 22),
                child: Text(
                    'Рейтинг включает игроков, имеющих запись в официальной статистике ФХР. '
                    'Игроки без опубликованной статистики доступны в общих составах команд. '
                    'При отсутствии данных показатель не вычисляется самостоятельно.',
                    style: TextStyle(
                        color: CupUi.muted, fontSize: 11, height: 1.5))),
          ])
        ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CupStatistics>(
        future: pending,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              latest == null) {
            return const LoadingCards();
          }
          if (snapshot.hasError && latest == null) {
            return CupMessage(
                icon: Icons.cloud_off_outlined,
                title: 'Статистика ФХР временно недоступна',
                message:
                    'Не удалось загрузить статистику. Проверь соединение и попробуй снова.',
                retry: load);
          }
          final data = latest;
          if (data == null) return SizedBox.shrink();
          return RefreshIndicator(onRefresh: load, child: _content(data));
        });
  }
}

class CupPlayerProfilePage extends StatefulWidget {
  final CupPlayerStats player;
  const CupPlayerProfilePage({super.key, required this.player});
  @override
  State<CupPlayerProfilePage> createState() => _CupPlayerProfilePageState();
}

class _CupPlayerProfilePageState extends State<CupPlayerProfilePage> {
  CupPlayerStats get player => widget.player;
  bool following = false, followBusy = false, comparing = false;
  @override
  void initState() {
    super.initState();
    restoreFollow();
  }

  Future<void> restoreFollow() async {
    try {
      final set = await FollowStore.players();
      if (mounted) setState(() => following = set.contains(player.id));
    } catch (e) {
      Diagnostics.record('player follows', e);
    }
  }

  Future<void> toggleFollow() async {
    if (followBusy) return;
    setState(() => followBusy = true);
    try {
      final result = await FollowStore.togglePlayer(player.id);
      if (mounted) setState(() => following = result);
    } catch (e) {
      Diagnostics.record('player follow', e);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Не удалось сохранить игрока. Попробуй ещё раз.')));
    } finally {
      if (mounted) setState(() => followBusy = false);
    }
  }

  Widget _impactProfile() {
    if (player.goalie) {
      final pct =
          double.tryParse(player.savePercentText.replaceAll('%', '')) ?? 0;
      return Column(children: [
        CupSection(
            title: 'ВРАТАРСКИЙ ПРОФИЛЬ',
            subtitle: 'Показатели по официальной статистике ФХР'),
        CupCard(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.shield_rounded, color: CupUi.ice, size: 19),
                const SizedBox(width: 9),
                const Expanded(
                    child: Text('ПРОЦЕНТ ОТРАЖЁННЫХ',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w900))),
                Text(player.savePercentText,
                    style: TextStyle(
                        color: CupUi.ice,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: CupUi.raised,
                      valueColor: AlwaysStoppedAnimation<Color>(CupUi.ice))),
              const SizedBox(height: 13),
              Text(
                  '${player.saves} сейвов · ${player.shotsAgainst} бросков · ${player.shutouts} сухих матчей',
                  style:
                      TextStyle(color: CupUi.soft, fontSize: 11, height: 1.5)),
            ])),
      ]);
    }
    final total = player.goals + player.assists;
    final share = total == 0 ? 0.0 : player.goals / total;
    return Column(children: [
      CupSection(
          title: 'ПРОФИЛЬ РЕЗУЛЬТАТИВНОСТИ',
          subtitle: 'Распределение голов и передач в очках игрока'),
      CupCard(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.sports_hockey_rounded, color: CupUi.ice, size: 19),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('АТАКУЮЩИЙ ВКЛАД',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900))),
              CupTag(
                  text: '${player.points} ОЧКОВ',
                  color: CupUi.ice,
                  filled: true),
            ]),
            const SizedBox(height: 18),
            ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Row(children: [
                  if (total == 0)
                    Expanded(child: Container(height: 12, color: CupUi.raised))
                  else ...[
                    if (player.goals > 0)
                      Expanded(
                          flex: player.goals,
                          child: Container(height: 12, color: CupUi.ice)),
                    if (player.assists > 0)
                      Expanded(
                          flex: player.assists,
                          child: Container(height: 12, color: CupUi.red)),
                  ],
                ])),
            const SizedBox(height: 12),
            Row(children: [
              _legend('ГОЛЫ', player.goals, CupUi.ice),
              const SizedBox(width: 16),
              _legend('ПЕРЕДАЧИ', player.assists, CupUi.red),
            ]),
            const SizedBox(height: 14),
            Text(
                'Доля голов среди голов и передач: ${(share * 100).round()}%. Очков за игру: ${player.pointsPerGame?.toStringAsFixed(2) ?? '—'}.',
                style: TextStyle(color: CupUi.soft, fontSize: 11, height: 1.5)),
          ])),
    ]);
  }

  Widget _legend(String title, int value, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text('$title $value',
            style: TextStyle(
                color: CupUi.soft, fontSize: 10, fontWeight: FontWeight.w900)),
      ]);
  Future<void> _compare(BuildContext context) async {
    if (comparing) return;
    setState(() => comparing = true);
    final client = http.Client();
    try {
      final data = await CupStatisticsClient(client).fetch();
      if (!context.mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  PlayerComparisonPage(data: data, initial: player)));
    } catch (e) {
      Diagnostics.record('player comparison', e);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Не удалось загрузить статистику для сравнения.')));
    } finally {
      client.close();
      if (mounted) setState(() => comparing = false);
    }
  }

  Future<void> _openProfile(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Profile launch failed');
      }
    } catch (e) {
      Diagnostics.record('player profile link', e);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось открыть профиль ФХР.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = player.goalie
        ? <({String label, String value})>[
            (label: 'МАТЧИ', value: '${player.games}'),
            (label: 'ПОБЕДЫ', value: '${player.wins}'),
            (label: 'ПОРАЖЕНИЯ', value: '${player.losses}'),
            (label: '% ОБ', value: player.savePercentText),
            (label: 'КН', value: player.gaaText),
            (label: 'БРОСКИ', value: '${player.shotsAgainst}'),
            (label: 'СЕЙВЫ', value: '${player.saves}'),
            (label: 'ПРОПУЩЕНО', value: '${player.goalsAgainst}'),
            (label: 'СУХИЕ', value: '${player.shutouts}'),
            (label: 'МИНУТЫ', value: player.timeOnIce),
          ]
        : <({String label, String value})>[
            (label: 'МАТЧИ', value: '${player.games}'),
            (label: 'ШАЙБЫ', value: '${player.goals}'),
            (label: 'ПЕРЕДАЧИ', value: '${player.assists}'),
            (label: 'ОЧКИ', value: '${player.points}'),
            (label: '+/-', value: '${player.plusMinus}'),
            (label: 'ШТРАФ', value: '${player.pim}'),
            (
              label: 'О/И',
              value: player.pointsPerGame?.toStringAsFixed(2) ?? '—'
            ),
          ];
    final uri = Uri.tryParse(player.profile);
    final trusted =
        uri != null && uri.scheme == 'https' && uri.host == 'junior.fhr.ru';
    return Scaffold(
      backgroundColor: CupUi.background,
      appBar: AppBar(
          title: Text('ИГРОК · КУБОК РОССИИ U16',
              style: TextStyle(
                  color: CupUi.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
                tooltip:
                    following ? 'Убрать из избранного' : 'Добавить в избранное',
                icon: Icon(
                    following ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: following ? CupUi.yellow : CupUi.soft),
                onPressed: followBusy ? null : toggleFollow),
            IconButton(
                tooltip: 'Поделиться',
                icon: const Icon(Icons.ios_share),
                onPressed: () => shareCard(context, player.name, [
                      player.fullClub,
                      '${player.games} игр',
                      if (!player.goalie)
                        '${player.goals} голов · ${player.assists} передач · ${player.points} очков',
                      if (player.goalie)
                        'Отражено ${player.savePercentText} · КН ${player.gaaText}'
                    ]))
          ]),
      body: ListView(children: [
        CupSection(
            title: 'Профиль игрока', subtitle: 'Официальная статистика ФХР'),
        CupCard(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            padding: const EdgeInsets.fromLTRB(15, 22, 15, 20),
            child: Column(children: [
              fhrPlayerPhoto(player.photo, size: 96),
              SizedBox(height: 15),
              Text(player.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: CupUi.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 9),
              CupTag(
                  text: '№${player.number} · ${player.position.toUpperCase()}',
                  color: CupUi.red,
                  filled: true),
              SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                fhrTeamLogo(player.teamLogo, size: 27),
                SizedBox(width: 8),
                Flexible(
                    child: Text(player.fullClub,
                        style: TextStyle(
                            color: CupUi.soft,
                            fontWeight: FontWeight.w700,
                            fontSize: 12))),
              ]),
            ])),
        CupSection(
            title: 'СТАТИСТИКА В ТУРНИРЕ',
            subtitle: 'Сезон 2026/27 · данные ФХР'),
        CupCard(
            padding: EdgeInsets.all(12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: stats.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 9,
                  childAspectRatio: 1.55),
              itemBuilder: (_, i) => Container(
                decoration: BoxDecoration(
                    color: CupUi.raised,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(stats[i].value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: CupUi.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text(stats[i].label,
                          maxLines: 1,
                          style: TextStyle(
                              color: CupUi.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ]),
              ),
            )),
        _impactProfile(),
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 5),
            child: FilledButton.icon(
                icon: const Icon(Icons.compare_arrows_rounded),
                onPressed: comparing ? null : () => _compare(context),
                label: const Text('СРАВНИТЬ С ДРУГИМ ИГРОКОМ'))),
        RecentPlayerGames(player: player),
        if (trusted)
          Padding(
              padding: EdgeInsets.fromLTRB(12, 13, 12, 2),
              child: FilledButton.icon(
                  onPressed: () => _openProfile(uri),
                  icon: Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text('ПРОФИЛЬ НА ФХР'))),
        Padding(
            padding: EdgeInsets.fromLTRB(15, 10, 15, 26),
            child: Text(
                'Сезонная статистика обновляется на основе официальных публикаций ФХР. '
                'Показатели вратарей могут зависеть от числа сыгранных минут и бросков.',
                style:
                    TextStyle(color: CupUi.muted, fontSize: 11, height: 1.5))),
      ]),
    );
  }
}
