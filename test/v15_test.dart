import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:junior_u16/cup_data.dart';
import 'package:junior_u16/insights.dart';
import 'package:junior_u16/app_services.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Cache round trip preserves stage, OT and live status',(){
    final m=Match('2026-10-01','A','B','3:2','Группа 1-I','',gameId:1,status:'FINAL',scoreNote:'ОТ');
    final restored=FhrFeed.fromApi(FhrFeed([m],DateTime.utc(2026),[],1,false,90).toCache()).matches.single;
    expect(restored.stage,m.stage);expect(restored.overtime,true);expect(restored.isFinalConfirmed,true);
    expect(ranking([restored]).first.pts,2);expect(ranking([restored]).last.pts,1);
  });
  test('Duplicate fixtures do not award points twice',(){
    final m=Match('2026-10-01','A','B','3:2','Группа 1-I','',gameId:1,status:'FINAL');
    expect(ranking([m,m]).first.gp,1);expect(ranking([m,m]).first.pts,2);
  });
  test('Bounds allow equal-point rivals and do not claim qualification',(){
    final a=Rank('A')..pts=20..gp=14;
    final rivals=List.generate(19,(i)=>Rank('$i')..pts=18..gp=13);
    final b=QualificationBounds.forTeam([a,...rivals],a);
    expect(b.minPoints,20);expect(b.maxPoints,20);expect(b.worstBound,20);
  });
  test('Bounds prove elimination only with eight strictly higher teams',(){
    final a=Rank('A')..pts=0..gp=13;
    final rivals=List.generate(8,(i)=>Rank('$i')..pts=3..gp=13);
    expect(QualificationBounds.forTeam([a,...rivals],a).bestBound,9);
  });
  test('Head to head excludes other opponents and handles home-away',(){
    final games=[Match('2026-01-01','A','B','2:1','Группа 1-I',''),Match('2026-02-01','B','A','3:1','Группа 1-I',''),Match('2026-03-01','A','C','3:1','Группа 1-I','')];
    expect(meetings(games,'A','B').length,2);
  });
  test('Cache isolates groups and ignores corrupt data',()async{
    SharedPreferences.setMockInitialValues({'v15:broken':'{'});
    await FeedCache.write('stats:A',{'ok':true});
    expect((await FeedCache.read('stats:A'))?['ok'],true);
    expect(await FeedCache.read('stats:B'),null);expect(await FeedCache.read('broken'),null);
  });
  test('Release version is numeric including prerelease tags',(){
    expect(releaseNumber('v15.0.0'),15);expect(releaseNumber('v9.0.0'),9);expect(releaseNumber('garbage'),0);
  });
}
