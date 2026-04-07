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
      print("navigating to ${state.uri.path}");
      
      final navBarItem = _navigationBarItems.where((element) => element.id == state.uri.path).firstOrNull;
      if (navBarItem != null) {
        int navBarIndex = _navigationBarItems.indexOf(navBarItem);
        if (navBarIndex != -1) navBarKey.currentState?.switchToIndex(navBarIndex);
      }

      final path = state.uri.path;

      final onLogin = path == '/login';
      final onResetPassword = path == '/reset-password';

      if (!userLoggedIn && !onResetPassword) {
        return '/login';
      }
      if (userLoggedIn && onLogin) {
        print("user is already logged in, redirecting to profile");
        return '/profile';
      }
      if (userLoggedIn && state.matchedLocation == '/') return '/profile';
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
            builder: (context, state) => const Scaffold(body: VideoUploadWidget()),
          ),
          GoRoute(
            path: '/quests',
            builder: (context, state) => const TestQuestScreen(subject: 'General'),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          print("login!");
          return const LoginScreen();
        },
      ),
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          print("navigating to reset password screen");
          return const ResetPasswordScreen();
        },
      ),
    ],
  );
}

GlobalObjectKey<BottomNavBarState> navBarKey = const GlobalObjectKey('bottomNavBarKey');
BottomNavBar _bottomNavBar = BottomNavBar(
  initialIndex: 3,
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
