import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/scenario_page.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Redesigned simulator shows standings and round filters',(tester)async{
    SharedPreferences.setMockInitialValues({});
    final teams=List.generate(20,(i)=>'Команда ${i+1}');
    final matches=<Match>[];
    for(var i=0;i<20;i+=2){
      matches.add(Match('2026-10-01',teams[i],teams[i+1],'','Группа 1-I','',gameId:i+1));
    }
    await tester.pumpWidget(MaterialApp(home:ScenarioPage(matches:matches,teams:teams)));
    await tester.pumpAndSettle();
    expect(find.text('ПРЕДИКТЫ'),findsOneWidget);
    expect(find.text('ТАБЛИЦА СЦЕНАРИЯ'),findsOneWidget);
    expect(find.text('СТЫКИ'),findsOneWidget);
    expect(find.text('III ТУР'),findsOneWidget);
    await tester.tap(find.text('СТЫКИ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });
}
