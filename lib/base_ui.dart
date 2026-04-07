import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wurp/ui/router.dart';

import 'base_logic.dart';

void startApp() async {
  print("starting app");
  
  final session = auth.currentSession;
  if (session != null) {
    final authUser = session.user;
    try {
      final user = await userRepository.getUserSupabase(authUser.id) ?? await userRepository.getOrCreateCurrentUser();
      await onUserLogin(user);
    } on AuthException catch (e) {
      print("Error fetching user profile: $e");
      await auth.signOut();
    }
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
