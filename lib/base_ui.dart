import 'package:flutter/material.dart';
import 'package:wurp/ui/router.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

import 'base_logic.dart';

void startApp() async {
  print("starting app");
  if (auth?.currentUser != null) {
    print("user logged in, ensuring supabase is initialized");
    await ensureSupabaseInitialized();
    print("initialized supabase");
    final user = await userRepository.getUserSupabase(auth!.currentUser!.uid) ?? await userRepository.getOrCreateCurrentUser();
    print("got user");
    await onUserLogin(user);
    print("user logged in");
  }
  
  initRouter();
  print("initialized router");
  routerConfig.refresh();

  print("running");
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
