import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wurp/main.dart';
import 'package:wurp/transcription/uploading/video_upload_screen.dart';
import 'package:wurp/ui/screens/auth_screen.dart';
import 'package:wurp/ui/screens/chat/chat_managing_screen.dart';
import 'package:wurp/ui/screens/profile_screen.dart';
import 'package:wurp/ui/screens/quests/test_quest_screen.dart';
import 'package:wurp/ui/screens/search_screen/search_screen.dart';
import 'package:wurp/ui/short_video_player.dart';
import 'package:wurp/ui/widgets/bottom_navigation_bar.dart';

import '../base_logic.dart';

late final GoRouter routerConfig;

void initRouter() {
  routerConfig = GoRouter(
    navigatorKey: appNavigatorKey,
    observers: [RouteObserver()],
    redirect: (context, state) {
      final navBarItem = _navigationBarItems.where((element) => element.id == state.matchedLocation).firstOrNull;
      if (navBarItem != null) {
        int navBarIndex = _navigationBarItems.indexOf(navBarItem);
        if (navBarIndex != -1) navBarKey.currentState?.switchToIndex(navBarIndex);
      }

      final onLogin = state.matchedLocation == '/login';

      if (!userLoggedIn && !onLogin) return '/login';
      if (userLoggedIn && onLogin) return '/feed';
      if (userLoggedIn && state.matchedLocation == '/') return '/feed';
      print("no redirect");
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
            builder: (context, state) =>
                ChatManagingScreen(preloadMoreChats: (current) => chatRepository.getChats(currentUser.id, offset: current ?? 0, limit: 15)),
          ),
          GoRoute(
            path: '/create',
            builder: (context, state) => const Scaffold(
              // appBar: AppBar(title: const Text('Not yet implemented')),
              body: VideoUploadWidget()
            ),
          ), //indicator that this is not implemented yet,
          GoRoute(
            path: '/quests',
            builder: (context, state) => const TestQuestScreen(subject: 'General')
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (context, state) {
          print("matched /");
          return const SizedBox.shrink();
        },
      ),
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
  (icon: Icons.person_outline, label: 'Profile', id: '/profile'),
  (icon: Icons.chat, label: 'Chat', id: '/chat'),
  (icon: CupertinoIcons.map, label: 'Quests', id: '/quests'),
];

class RouteObserver extends NavigatorObserver {
  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    super.didChangeTop(topRoute, previousTopRoute);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) => navBarKey.currentState?.switchToId((topRoute.settings.name?..replaceFirst("/", "")) ?? ''));
  }
}
