import 'package:flutter/material.dart';
import 'package:wurp/ui/router.dart';

import 'base_logic.dart';

void startApp() async {
  initRouter();
  routerConfig.refresh();
  if (auth?.currentUser != null) {
    await onUserLogin(await userRepository.getUser(auth!.currentUser!.uid));
  }
  
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.from(colorScheme: getColorScheme()).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B1220),
      ),
      routerConfig: routerConfig,
    ),
  );
}

ColorScheme getColorScheme() {
  return const ColorScheme.dark(
    secondary: Colors.blue,
    onSecondary: Color(0xFF002828),
    primary: Colors.teal,
    tertiary: Colors.tealAccent,
    brightness: Brightness.dark,
  );
}