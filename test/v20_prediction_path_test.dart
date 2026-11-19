import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/scenario_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Prediction page shows projected third-tour groups and scenario compare',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final teams = List.generate(20, (i) => 'Команда ${i + 1}');
    final matches = <Match>[];
    for (var i = 0; i < 20; i += 2) {
      matches.add(Match(
          '2026-09-20', teams[i], teams[i + 1], '2:1', 'Группа А-I', '',
          status: 'FINAL', gameId: i + 1));
    }
    await tester.pumpWidget(
        MaterialApp(home: ScenarioPage(matches: matches, teams: teams)));
    await tester.pumpAndSettle();
    final saveVariant = find.text('Сохранить вариант');
    await tester.scrollUntilVisible(saveVariant, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(saveVariant);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Мой вариант');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(
        (await SharedPreferences.getInstance())
            .getString('junior_saved_scenarios_2026_27'),
        contains('Мой вариант'));
    // Comparison precedes the fixtures; the third-tour map is below them.
    await tester.scrollUntilVisible(find.text('МАШИНА ВРЕМЕНИ'), 240,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('МАШИНА ВРЕМЕНИ'), findsOneWidget);
    expect(find.text('Мой вариант'), findsWidgets);
    await tester.scrollUntilVisible(find.text('ПУТЬ В III ТУР'), 240,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('ПУТЬ В III ТУР'), findsOneWidget);
    expect(find.text('ГРУППА А'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
