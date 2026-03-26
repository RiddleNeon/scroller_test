import 'package:flutter/material.dart';
import 'package:wurp/base_logic.dart';
import 'package:wurp/tools/video_generator.dart';

import 'base_ui.dart';
import 'messaging_base.dart';


final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {  
  await initLogic();
  await setupMessaging();
  //await publishTest();
  startApp();
}
