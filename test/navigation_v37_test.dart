import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/home_app.dart';

Map<String, dynamic> calendarFixture({int count = 12}) => FhrFeed(
        List.generate(
            count,
            (i) => Match(
                '2026-11-${(10 + i % 8).toString().padLeft(2, '0')}',
                'Крылья Советов Москва',
                'Авангард Омск',
                '4:2',
                'Группа В-II',
                'Арена',
                status: 'FINAL',
                timeMsk: '18:00',
                gameId: 1000 + i)),
        DateTime.utc(2026, 11, 18, 10),
        [],
        10,
        true,
        count)
    .toCache();

Map<String, dynamic> teamsFixture() => {
      'ok': true,
      'teams': [
        {
          'id': 1,
          'name': 'Крылья Советов',
          'city': 'Москва',
          'fullName': 'Крылья Советов Москва'
        },
        {
          'id': 2,
          'name': 'Авангард',
          'city': 'Омск',
          'fullName': 'Авангард Омск'
        },
      ]
    };

http.Response jsonResponse(Object value) =>
    http.Response(jsonEncode(value), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

MockClient fixtureClient(
        {Map<String, dynamic>? calendar, Future<http.Response>? live}) =>
    MockClient((r) async {
      if (r.url.path == '/api/v1/matches')
        return jsonResponse(calendar ?? calendarFixture());
      if (r.url.path == '/api/v1/teams') return jsonResponse(teamsFixture());
      if (r.url.path == '/api/v1/live') {
        if (live != null) return await live;
        return jsonResponse({'ok': true, 'checkedMatches': []});
      }
      return http.Response('Unavailable', 503);
    });

void phone(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Calendar is visible and saved while LIVE verification is pending',
      (tester) async {
    phone(tester);
    final live = Completer<http.Response>();
    final client = fixtureClient(live: live.future);
    addTearDown(client.close);
    await tester.pumpWidget(JuniorApp(client: client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Крылья Советов Москва'), findsWidgets);
    final saved = (await SharedPreferences.getInstance())
        .getString('junior_u16_calendar_v9');
    expect(saved, isNotNull);
    expect(FhrFeed.fromApi(jsonDecode(saved!)).matches.length, 12);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    live.complete(jsonResponse({'ok': true, 'checkedMatches': []}));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bookmarks persist and can be removed from the saved list',
      (tester) async {
    phone(tester, width: 360);
    final client = fixtureClient();
    addTearDown(client.close);
    await tester.pumpWidget(JuniorApp(client: client));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Сохранить матч').first);
    await tester.pumpAndSettle();
    expect(
        (await SharedPreferences.getInstance())
            .getStringList('junior_favorites'),
        hasLength(1));
    await tester.tap(find.byTooltip('Избранное'));
    await tester.pumpAndSettle();
    expect(find.text('1 сохранено на этом устройстве'), findsOneWidget);
    await tester.tap(find.byTooltip('Убрать из избранного'));
    await tester.pumpAndSettle();
    expect(find.text('Сохрани важные матчи'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance())
            .getStringList('junior_favorites'),
        isEmpty);
    await tester.tap(find.text('Таблица'));
    await tester.pumpAndSettle();
    expect(find.text('Кубок России'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Empty successful feed preserves cache and its original timestamp',
      (tester) async {
    phone(tester);
    final old = calendarFixture(count: 1);
    SharedPreferences.setMockInitialValues(
        {'junior_u16_calendar_v9': jsonEncode(old)});
    final client = fixtureClient(
        calendar:
            FhrFeed([], DateTime.utc(2026, 11, 19), [], 0, true, 0).toCache());
    addTearDown(client.close);
    await tester.pumpWidget(JuniorApp(client: client));
    await tester.pumpAndSettle();
    expect(find.text('Показаны последние данные · календарь ФХР неполный'),
        findsOneWidget);
    final saved = FhrFeed.fromApi(jsonDecode(
        (await SharedPreferences.getInstance())
            .getString('junior_u16_calendar_v9')!));
    expect(saved.matches, hasLength(1));
    expect(saved.updatedAt, DateTime.utc(2026, 11, 18, 10));
    expect(saved.issues, isNotEmpty);
    expect(saved.allStagesComplete, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Team search accepts city and an empty result can be cleared',
      (tester) async {
    phone(tester);
    final client = fixtureClient();
    addTearDown(client.close);
    await tester.pumpWidget(JuniorApp(client: client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Команды'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'омск');
    await tester.pumpAndSettle();
    expect(find.text('Авангард'), findsOneWidget);
    expect(find.text('Крылья Советов'), findsNothing);
    await tester.enterText(find.byType(TextField), 'нет команды');
    await tester.pumpAndSettle();
    expect(find.text('Нет такой команды'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Крылья Советов'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Capture overview matches and dark theme', (tester) async {
    if (!const bool.fromEnvironment('DESIGN_CAPTURE')) return;
    phone(tester);
    final fonts = FontLoader('Manrope');
    for (final style in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/Manrope-$style.ttf'));
    }
    await fonts.load();
    Map<String, dynamic>? calendar;
    Map<String, dynamic>? teams;
    const dataDir = String.fromEnvironment('PREVIEW_DATA_DIR');
    if (dataDir.isNotEmpty) {
      calendar = jsonDecode(await File('$dataDir/matches.json').readAsString());
      teams = jsonDecode(await File('$dataDir/teams.json').readAsString());
    }
    final client = MockClient((r) async {
      if (r.url.path == '/api/v1/matches')
        return jsonResponse(calendar ?? calendarFixture());
      if (r.url.path == '/api/v1/teams')
        return jsonResponse(teams ?? teamsFixture());
      return jsonResponse({'ok': true, 'checkedMatches': []});
    });
    addTearDown(client.close);
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('capture'), child: JuniorApp(client: client)));
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')));
      await tester.runAsync(() async {
        final shot = await boundary.toImage(pixelRatio: 2);
        final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        shot.dispose();
      });
    }

    await capture('overview-v37');
    await tester.tap(find.text('Матчи'));
    await tester.pumpAndSettle();
    await capture('matches-v37');
    await tester.tap(find.byTooltip('Разделы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сменить тему'));
    await tester.pumpAndSettle();
    await capture('matches-dark-v37');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
