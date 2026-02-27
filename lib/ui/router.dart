import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/screens/auth_screen.dart';
import 'package:wurp/ui/screens/bottom_navigation_bar.dart';
import 'package:wurp/ui/screens/profile_screen.dart';
import 'package:wurp/ui/screens/search_screen/search_screen.dart';
import 'package:wurp/ui/short_video_player.dart';

late final GoRouter routerConfig;

void initRouter(){
  routerConfig = GoRouter(
    navigatorKey: appNavigatorKey,
    redirect: (context, state) {
      final loggedIn = userLoggedIn;
      final onLogin = state.matchedLocation == '/login';

      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/feed';
      if (loggedIn && state.matchedLocation == '/') return '/feed';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return Scaffold(
            body: child,
            bottomNavigationBar: _bottomNavBar,
          );
        },
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) =>
            const VideoFeed(),
          ),

          GoRoute(
            path: '/search_screen',
            builder: (context, state) =>
            const SearchScreen(),
          ),

          GoRoute(
            path: '/profile',
            builder: (context, state) =>
                ProfileScreen(profile: currentUser, ownProfile: true),
          ),

        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
}

BottomNavBar _bottomNavBar = BottomNavBar(
  key: const ValueKey('bottomNavBar'),
  onSelectionChange: (p0) {
    print("pushing $p0");
    routerConfig.push("/$p0");
  },
  items: [
    (icon: Icons.home, label: 'Home', id: 'feed'),
    (icon: Icons.search, label: 'Discover', id: 'search_screen'),
    (icon: Icons.add_box_outlined, label: '', id: 'create'),
    (icon: Icons.notifications_none, label: 'Inbox', id: 'notifications'),
    (icon: Icons.person_outline, label: 'Profile', id: 'profile'),
  ],
);