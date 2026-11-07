import 'package:shared_preferences/shared_preferences.dart';

/// On-device follows, not a remote account or push subscription.
class FollowStore {
  static const _teams='v26:followedTeams';
  static const _players='v26:followedPlayers';
  static Future<Set<String>> teams()async=>
    (await SharedPreferences.getInstance()).getStringList(_teams)?.toSet()??<String>{};
  static Future<Set<int>> players()async=>
    ((await SharedPreferences.getInstance()).getStringList(_players)??[])
      .map(int.tryParse).whereType<int>().toSet();
  static Future<bool> toggleTeam(String team)async{
    final set=await teams();
    final enabled=!set.remove(team);
    if(enabled)set.add(team);
    await (await SharedPreferences.getInstance()).setStringList(_teams,set.toList());
    return enabled;
  }
  static Future<bool> togglePlayer(int id)async{
    final set=await players();
    final enabled=!set.remove(id);
    if(enabled)set.add(id);
    await (await SharedPreferences.getInstance()).setStringList(
      _players,set.map((e)=>e.toString()).toList());
    return enabled;
  }
}
