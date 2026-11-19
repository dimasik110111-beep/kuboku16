import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/scenario_page.dart';
import 'package:junior_u16/tournament_page.dart';
import 'package:junior_u16/ui_kit.dart';

void main() {
  testWidgets('General standings open immediately and follow changed results',
      (tester) async {
    CupUi.light = true;
    Widget standings(String score) => MaterialApp(
          home: Scaffold(
            body: TournamentPage(
              matches: [
                Match('2026-11-10', 'Альфа', 'Бета', score, 'Группа А-II', '',
                    status: 'FINAL', gameId: 1),
              ],
              teams: const ['Альфа', 'Бета'],
              teamLogo: (_) => null,
              onTeam: (_) {},
              onMatch: (_) {},
            ),
          ),
        );
    await tester.pumpWidget(standings('3:1'));
    expect(find.text('Общая таблица'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Альфа')).dy,
        lessThan(tester.getTopLeft(find.text('Бета')).dy));

    await tester.pumpWidget(standings('1:4'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Бета')).dy,
        lessThan(tester.getTopLeft(find.text('Альфа')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phone standings show rows without a promotional header',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CupUi.light = true;
    final teams =
        List.generate(20, (i) => 'Клуб ${i.toString().padLeft(2, '0')}');
    final matches = [
      for (var i = 0; i < 20; i += 2)
        Match('2026-11-10', teams[i], teams[i + 1], '3:1', 'Группа А-II', '',
            status: 'FINAL', gameId: i + 1)
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      const SizedBox(height: 88),
      Expanded(
          child: TournamentPage(
              matches: matches,
              teams: teams,
              teamLogo: (_) => null,
              onTeam: (_) {},
              onMatch: (_) {})),
      const SizedBox(height: 72),
    ]))));
    expect(tester.getTopLeft(find.text(teams[0])).dy, lessThan(300));
    expect(tester.getBottomLeft(find.text(teams[14])).dy, lessThan(772));
    expect(find.byTooltip('Интерактивные расклады'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Интерактивные расклады'));
    await tester.pumpAndSettle();
    expect(find.text('ПРЕДИКТЫ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Editing a restored forecast recalculates and saves its score',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'junior_scenario_2026_27': jsonEncode({
        '1': {'home': 3, 'away': 1, 'overtime': false},
        '999': {'home': 9, 'away': 1, 'overtime': false},
      }),
    });
    const game = Match('2099-11-19', 'Альфа', 'Бета', '', 'Группа А-II', '',
        status: 'SCHEDULED', gameId: 1);
    await tester.pumpWidget(const MaterialApp(
      home: ScenarioPage(matches: [game], teams: ['Альфа', 'Бета']),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('3:1'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3:1'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('scenario-home-score')), '1');
    await tester.enterText(
        find.byKey(const ValueKey('scenario-away-score')), '4');
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(find.text('1:4'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(prefs.getString('junior_scenario_2026_27')!) as Map;
    expect(saved['1'], {'home': 1, 'away': 4, 'overtime': false});
    expect(saved.containsKey('999'), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
