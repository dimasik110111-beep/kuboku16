import 'package:shared_preferences/shared_preferences.dart';

/// On-device follows, not a remote account or push subscription.
class FollowStore {
  static const _teams='v26:followedTeams';
  static const _players='v26:followedPlayers';
  // Each toggle is a read-modify-write operation. Serialize them so quick taps
  // on different clubs/players cannot overwrite the previous tap's changes.
  static Future<void> _writes=Future<void>.value();
  static Future<bool> _toggle(String key,String value) {
    final operation=_writes.then((_)async{
      final prefs=await SharedPreferences.getInstance();
      final set=(prefs.getStringList(key)??<String>[]).toSet();
      final enabled=!set.remove(value);
      if(enabled)set.add(value);
      if(!await prefs.setStringList(key,set.toList())) {
        throw StateError('Не удалось сохранить избранное');
      }
      return enabled;
    });
    // A failed write must not prevent subsequent changes from being saved.
    _writes=operation.then<void>((_){},onError:(Object _,StackTrace __){});
    return operation;
  }
  static Future<Set<String>> teams()async{
    await _writes;
    return (await SharedPreferences.getInstance()).getStringList(_teams)?.toSet()??<String>{};
  }
  static Future<Set<int>> players()async{
    await _writes;
    return ((await SharedPreferences.getInstance()).getStringList(_players)??[])
      .map(int.tryParse).whereType<int>().toSet();
  }
  static Future<bool> toggleTeam(String team)=>_toggle(_teams,team);
  static Future<bool> togglePlayer(int id)=>_toggle(_players,id.toString());
}
