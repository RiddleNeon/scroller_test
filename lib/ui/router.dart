import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/screens/auth_screen.dart';
import 'package:wurp/ui/screens/bottom_navigation_bar.dart';
import 'package:wurp/ui/screens/chat/chat_managing_screen.dart';
import 'package:wurp/ui/screens/profile_screen.dart';
import 'package:wurp/ui/screens/search_screen/search_screen.dart';
import 'package:wurp/ui/short_video_player.dart';

import '../base_logic.dart';

late final GoRouter routerConfig;

void initRouter([bool onlyLogin = false]) {
  routerConfig = GoRouter(
    navigatorKey: appNavigatorKey,
    redirect: (context, state) {
      if(userLoggedIn) return null;
      final navBarItem = _navigationBarItems.where((element) => element.id == state.matchedLocation).firstOrNull;
      if (navBarItem != null) {
        int navBarIndex = _navigationBarItems.indexOf(navBarItem);
        if (navBarIndex != -1) navBarKey.currentState?.switchToIndex(navBarIndex);
      }

      final loggedIn = userLoggedIn;
      final onLogin = state.matchedLocation == '/login';

      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/feed';
      if (loggedIn && state.matchedLocation == '/' &&!onlyLogin) return '/feed';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return Scaffold(body: child, bottomNavigationBar: _bottomNavBar);
        },
        routes: [
          GoRoute(path: '/feed', builder: (context, state) => const VideoFeed()),
          GoRoute(path: '/search_screen', builder: (context, state) => const SearchScreen()),
          GoRoute(
            path: '/profile',
            builder: (context, state) => ProfileScreen(initialProfile: currentUser, ownProfile: true, onFollowChange: (bool followed) {}),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => ChatManagingScreen(
              preloadMoreChats: (current) => chatRepository.getChats(currentUser.id, offset: current, limit: 15),
            )
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
    ],
  );
}

late final GoRouter loginOnlyRouterConfig;

void initLoginOnlyRouter() {
  loginOnlyRouterConfig = GoRouter(
    navigatorKey: appNavigatorKey,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
    ],
  );
}

GlobalObjectKey<BottomNavBarState> navBarKey = const GlobalObjectKey('bottomNavBarKey');
BottomNavBar _bottomNavBar = BottomNavBar(
  key: navBarKey,
  onSelectionChange: (p0) {
    routerConfig.go(p0);
  },
  items: _navigationBarItems,
);

List<({IconData icon, String label, String id})> _navigationBarItems = [
  (icon: Icons.home, label: 'Home', id: '/feed'),
  (icon: Icons.search, label: 'Discover', id: '/search_screen'),
  (icon: Icons.add_box_outlined, label: '', id: '/create'),
  (icon: Icons.notifications_none, label: 'Inbox', id: '/notifications'),
  (icon: Icons.person_outline, label: 'Profile', id: '/profile'),
  (icon: Icons.chat, label: 'Chat', id: '/chat'),
];
