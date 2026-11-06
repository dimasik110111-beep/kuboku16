import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'home_app.dart';
import 'app_services.dart';

void main(){
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError=(details){
    Diagnostics.record('flutter',details.exception);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError=(error,stack){
    Diagnostics.record('platform',error);
    return false;
  };
  runApp(const JuniorApp());
}
