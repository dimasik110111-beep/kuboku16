import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/app_services.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/follow_store.dart';
import 'package:junior_u16/match_lineups.dart';
import 'package:junior_u16/player_statistics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Concurrent follows retain every selection and double taps cancel', () async {
    await Future.wait([
      FollowStore.toggleTeam('Крылья Советов'),
      FollowStore.toggleTeam('ЦСКА'),
      FollowStore.togglePlayer(7),
      FollowStore.togglePlayer(9),
    ]);
    expect(await FollowStore.teams(), {'Крылья Советов', 'ЦСКА'});
    expect(await FollowStore.players(), {7, 9});
    final toggles = await Future.wait([
      FollowStore.togglePlayer(11),
      FollowStore.togglePlayer(11),
    ]);
    expect(toggles, [true, false]);
    expect(await FollowStore.players(), {7, 9});
  });

  test('Offline calendar retains completeness warnings and provenance', () {
    const game = Match('2026-11-01', 'А', 'Б', '3:2', 'Группа А-II', '',
        gameId: 12, status: 'FINAL', scoreNote: 'ОТ');
    final original = FhrFeed([game], DateTime.utc(2026, 11, 1),
        ['Одна группа недоступна'], 9, false, 90);
    final restored = FhrFeed.fromApi(original.toCache());
    expect(restored.issues, original.issues);
    expect(restored.groupsFetched, 9);
    expect(restored.allStagesComplete, false);
    expect(restored.expectedMatchCount, 90);
    expect(restored.updatedAt, original.updatedAt);
    expect(restored.matches.single.overtime, true);
    expect(FhrFeed.fromApi(FhrFeed([game], null, [], 10, true, 90)
        .toCache()).allStagesComplete, true);
  });

  test('Malformed successful response cannot erase valid cached teams', () async {
    const key = '/api/v1/teams';
    final good = {'ok': true, 'teams': [
      {'id': 1, 'fullName': 'Крылья Советов Москва'},
    ]};
    await FeedCache.write(key, good);
    final client = MockClient((_) async => http.Response(
        jsonEncode({'ok': true, 'teams': [null]}), 200));
    addTearDown(client.close);
    await expectLater(FhrApiClient(client).teams(), throwsFormatException);
    expect(await FeedCache.read(key), good);
  });

  test('Duplicate requests share transport and retry after an error', () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final client = MockClient((_) {
      requests++;
      return requests == 1 ? response.future : Future.value(http.Response(
          jsonEncode({'ok': true, 'checkedMatches': []}), 200));
    });
    addTearDown(client.close);
    final api = FhrApiClient(client);
    final first = api.liveCheck();
    final second = api.liveCheck();
    final result = expectLater(Future.wait([first, second]), throwsException);
    response.complete(http.Response('Service unavailable', 503));
    await result;
    expect(requests, 1);
    expect(await api.liveCheck(), isEmpty);
    expect(requests, 2);
  });

  test('A mismatched match protocol never enters the offline cache', () async {
    final client = MockClient((_) async => http.Response(
        jsonEncode({'ok': true, 'gameId': 99}), 200));
    addTearDown(client.close);
    await expectLater(FhrApiClient(client).detail(12), throwsFormatException);
    expect(await FeedCache.read('/api/v1/matches/12'), isNull);
  });

  test('Lowercase provider statuses preserve live and finished semantics', () {
    final live = Match.fromApi({'home': 'А', 'away': 'Б',
      'homeScore': 2, 'awayScore': 1, 'status': ' live_paused '});
    expect(live.isLive, true);
    expect(live.finished, false);
    final finalGame = Match.fromApi({'home': 'А', 'away': 'Б',
      'homeScore': 2, 'awayScore': 1, 'status': ' final '});
    expect(finalGame.isFinalConfirmed, true);
  });

  test('Two copies of home lineup cannot claim a complete match roster', () {
    final result = GameLineups.fromDetail({'matchLineups': {
      'available': true,
      'teams': [{'side': 'home'}, {'side': 'home'}],
    }});
    expect(result.available, false);
    expect(result.partial, true);
  });

  testWidgets('Players without a published position remain visible', (tester) async {
    final result = GameLineups.fromDetail({'matchLineups': {
      'available': true,
      'teams': [
        {'side': 'home', 'players': [{'name': 'Иван Петров', 'number': '7'}]},
        {'side': 'away', 'players': []},
      ],
    }});
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:MatchLineupPanel(
        lineups:result, home:'Крылья', away:'ЦСКА')))));
    expect(find.text('Иван Петров'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Stats requests normalize groups and preserve valid cache on failure', () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final client = MockClient((request) {
      expect(request.url.queryParameters['group'], 'Группа А-I');
      requests++;
      return requests == 1 ? response.future : Future.value(http.Response(
          jsonEncode({'ok': true, 'complete': false}), 200));
    });
    addTearDown(client.close);
    final api = CupStatisticsClient(client);
    final first = api.fetch(group:' Группа А-I ');
    final second = api.fetch(group:'Группа А-I');
    final raw = {'ok': true, 'complete': true, 'group': 'Группа А-I',
      'skaters': [], 'goalies': [], 'skaterCount': '0', 'goalieCount': '0'};
    response.complete(http.Response(jsonEncode(raw), 200,
      headers:{'content-type':'application/json; charset=utf-8'}));
    await Future.wait([first, second]);
    expect(requests, 1);
    await expectLater(api.fetch(group:'Группа А-I'), throwsFormatException);
    expect((await api.cached(group:' Группа А-I '))?.complete, true);
  });
}
