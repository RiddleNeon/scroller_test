import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wurp/ui/router.dart';
import 'package:wurp/ui/theme/app_theme.dart';

import 'base_logic.dart';

void startApp() async {
  final session = auth.currentSession;
  if (session != null) {
    final authUser = session.user;
    try {
      final user = await userRepository.getUserSupabase(authUser.id);
      if(user == null) throw const AuthException("User not found in database");
      await onUserLogin(user);
    } on AuthException catch (e) {
      print("Error fetching user profile: $e");
      await auth.signOut();
    }
  }

  initRouter();
  routerConfig.refresh();

  runApp(
    ValueListenableBuilder<(ThemeData, String)>(
      valueListenable: appThemeNotifier,
      builder: (context, value, child) {
        print("building app with theme: ${value.$1.brightness}");
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: value.$1,
          themeMode: value.$1.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: routerConfig,
        );
      },
    ),
  );
}

final ValueNotifier<(ThemeData, String)> appThemeNotifier = ValueNotifier((AppTheme.light, 'default'));
