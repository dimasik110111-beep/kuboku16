import 'package:flutter_test/flutter_test.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/scenario.dart';

void main(){
  test('scenario creates the regulation third-tour snake schedule',(){
    final teams=List.generate(20,(i)=>'Team ${i+1}');
    final fixtures=<Match>[];
    for(var i=0;i<teams.length;i+=2){
      fixtures.add(Match('2026-10-01',teams[i],teams[i+1],'','Группа 1-I','',gameId:i+1));
    }
    final generated=scenarioFixtures(fixtures);
    final third=generated.where((m)=>m.stage.contains('III')).toList();
    expect(third.length,50);
    expect(third.where((m)=>m.stage.startsWith('ГРУППА ')).length,40);
    expect(third.where((m)=>m.stage.startsWith('Стыковые ')).length,10);
    expect(third.every((m)=>m.date.isEmpty&&m.gameId!<0),isTrue);
  });

  test('scenario score on a generated match affects projected standings',(){
    final fixtures=<Match>[];
    for(var i=0;i<20;i+=2){
      fixtures.add(Match('2026-10-01','Team ${i+1}','Team ${i+2}','','Группа 1-I','',gameId:i+1));
    }
    final first=scenarioFixtures(fixtures).firstWhere((m)=>m.stage.startsWith('ГРУППА '));
    final simulated=applyScenario(fixtures,{first.key:const ScenarioScore(4,1)});
    expect(simulated.applied,1);
    expect(simulated.matches.any((m)=>m.key==first.key&&m.score=='4:1'),isTrue);
  });

  test('second-tour crossovers appear when only one group pair is published',(){
    final fixtures=<Match>[];
    for(var i=0;i<5;i++){
      fixtures.add(Match('2026-11-08','A$i','A${(i+1)%5}','','Группа A-II','',gameId:100+i));
      fixtures.add(Match('2026-11-08','Б$i','Б${(i+1)%5}','','Группа Б-II','',gameId:200+i));
    }
    final generated=scenarioFixtures(fixtures);
    final crossovers=generated.where((m)=>m.stage=='Стыковые А и Б - II').toList();
    expect(crossovers.length,5);
    expect(crossovers.every((m)=>m.gameId!<0&&m.date.isEmpty),isTrue);
    expect(generated.where((m)=>m.stage.contains(' - II')).length,5);
  });
}
