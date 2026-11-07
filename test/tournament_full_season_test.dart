import 'package:flutter_test/flutter_test.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/tournament.dart';

void main(){
  const stages=['A','Б','В','Г'];
  final participants=List.generate(20,(index)=>'Команда ${index+1}');
  List<Match> games(CupTour tour) {
    final label=tour==CupTour.first?'I':tour==CupTour.second?'II':'III';
    final date=tour==CupTour.first?'2026-09-19':
      tour==CupTour.second?'2026-11-09':'2027-01-15';
    final items=<Match>[];
    for(var gi=0;gi<4;gi++){
      for(var i=0;i<5;i++){
        for(var j=i+1;j<5;j++){
          items.add(Match(date,participants[gi*5+i],participants[gi*5+j],
            (i%2==0)?'2:1':'1:3','Группа ${stages[gi]}-$label','',
            status:'FINAL'));
        }
      }
    }
    if(tour!=CupTour.first){
      for(var i=0;i<5;i++){
        items.add(Match(date,participants[i],participants[5+i],
          '2:1','Плей-офф А и Б - $label','',status:'FINAL'));
        items.add(Match(date,participants[10+i],participants[15+i],
          '3:2','Плей-офф В и Г - $label','',status:'FINAL',scoreNote:'ОТ'));
      }
    }
    return items;
  }

  test('Full mock 3-round regulation schedule has 140 qualifiers; 8 Gold, 12 Silver',(){
    final all=[...games(CupTour.first),...games(CupTour.second),...games(CupTour.third)];
    final cup=CupTournament(all,teams:participants,utcNow:DateTime.utc(2027,2,20));
    expect(all.length,140);
    expect(cup.overview(CupTour.first).played,40);
    expect(cup.overview(CupTour.second).played,50);
    expect(cup.overview(CupTour.third).played,50);
    expect(cup.qualificationComplete,true);
    expect(cup.qualifyingFixtureCount,140);
    expect(cup.qualificationRanking.length,20);
    expect(cup.goldQualifiers.length,8);
    expect(cup.silverQualifiers.length,12);
    expect(cup.goldQualifiers.map((e)=>e.team).toSet()
      .intersection(cup.silverQualifiers.map((e)=>e.team).toSet()),isEmpty);
    expect(cup.overview(CupTour.second).crossoverCount,10);
    expect(cup.overview(CupTour.third).crossoverCount,10);
    expect(cup.crossoverMatches().length,20);
    expect(cup.groupNames().length,12);
    expect(cup.finalTable(CupTour.gold),isEmpty);
  });

  test('Second-round groups and third-round snake include exactly 20 unique teams',(){
    final all=[...games(CupTour.first),...games(CupTour.second)];
    final cup=CupTournament(all,teams:participants,utcNow:DateTime.utc(2026,12,20));
    expect(cup.firstTwoComplete,true);
    final second=cup.secondTourPreview();
    final third=cup.thirdTourPreview();
    expect(second.length,4);expect(third.length,4);
    expect(second.every((group)=>group.length==5),true);
    expect(third.every((group)=>group.length==5),true);
    expect(second.expand((e)=>e).toSet().length,20);
    expect(third.expand((e)=>e).toSet().length,20);
  });

  test('No invented finals or assignments while first three rounds are incomplete',(){
    final all=games(CupTour.first);
    final cup=CupTournament(all,teams:participants,utcNow:DateTime.utc(2026,10,20));
    expect(cup.firstComplete,true);
    expect(cup.firstTwoComplete,false);
    expect(cup.qualificationComplete,false);
    expect(cup.goldQualifiers,isEmpty);
    expect(cup.silverQualifiers,isEmpty);
    expect(cup.goldFixturesPublished,false);
    expect(cup.silverFixturesPublished,false);
    expect(cup.thirdTourPreview()[0][0],'Место 1');
  });

  test('Third-tour snake forecast is visible before round two finishes',(){
    final cup=CupTournament(games(CupTour.first),teams:participants,
      utcNow:DateTime.utc(2026,10,20));
    expect(cup.firstTwoComplete,false);
    final projection=cup.thirdTourProjection();
    expect(projection.length,4);
    expect(projection.every((group)=>group.length==5),true);
    expect(projection.expand((group)=>group).toSet().length,20);
    expect(projection.expand((group)=>group).every((team)=>!team.startsWith('Место ')),true);
  });
}
