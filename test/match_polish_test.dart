import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:junior_u16/match_center.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/team_hub.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Unpublished match has a terminal state and no invalid FHR action',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const match = Match('', 'Крылья Советов Москва', 'Авангард Омск', '',
        'Стыковые А и Б - II', '',
        gameId: -2000);
    await tester
        .pumpWidget(const MaterialApp(home: MatchCenterPage(match: match)));
    await tester.pumpAndSettle();
    expect(find.text('Протокол ещё не опубликован'), findsOneWidget);
    expect(find.text('Загружаю протокол'), findsNothing);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Источник ФХР'))
            .onPressed,
        isNull);
    await tester.tap(find.text('СОБЫТИЯ'));
    await tester.pumpAndSettle();
    expect(find.text('Протокол ещё не опубликован'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Cached live protocol remains readable and is labelled as saved',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'v15:/api/v1/matches/44': jsonEncode({
        'ok': true,
        'gameId': '44',
        'status': 'LIVE',
        'statusText': 'LIVE',
        'homeScore': 2,
        'awayScore': 1,
        'timeline': <dynamic>[],
      }),
    });
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      const match = Match(
          '2026-11-19', 'ЦСКА Москва', 'Авангард Омск', '', 'Группа А-II', '',
          gameId: 44);
      await tester
          .pumpWidget(const MaterialApp(home: MatchCenterPage(match: match)));
      await tester.pump();
      await tester.pump();
      expect(find.text('2 : 1'), findsOneWidget);
      expect(find.text('Сохранённый протокол'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
      response.complete(http.Response('Unavailable', 503));
      await tester.pumpAndSettle();
      expect(find.text('2 : 1'), findsOneWidget);
      expect(find.text('Показан сохранённый протокол. Обновление не удалось.'),
          findsOneWidget);
      expect(find.text('Загружаю протокол'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((_) => response.future));
  });

  testWidgets('Closing a match while the request runs is safe', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      const match = Match(
          '2026-11-19', 'ЦСКА Москва', 'Авангард Омск', '', 'Группа А-II', '',
          gameId: 45);
      await tester
          .pumpWidget(const MaterialApp(home: MatchCenterPage(match: match)));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(http.Response('Unavailable', 503));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) => response.future));
  });

  testWidgets('Team form wraps on a narrow screen and opens a contextual match',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const home = TeamInfo(
        1, 'Крылья Советов', 'Москва', 'Крылья Советов Москва', '', null);
    const away = TeamInfo(2, 'Авангард', 'Омск', 'Авангард Омск', '', null);
    final games = List.generate(
        5,
        (i) => Match('2026-11-${10 + i}', home.fullName, away.fullName, '3:1',
            'Группа А-II', '',
            status: 'FINAL'));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: TeamHubPage(
              team: home, matches: games, teams: const [home, away])));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('В').first);
      await tester.pumpAndSettle();
      final page = tester.widget<MatchCenterPage>(find.byType(MatchCenterPage));
      expect(page.matches, games);
      expect(page.homeTeam, home);
      expect(page.awayTeam, away);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((_) async => http.Response('Unavailable', 503)));
  });
}
