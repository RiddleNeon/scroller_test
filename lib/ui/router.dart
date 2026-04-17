import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wurp/main.dart';
import 'package:wurp/transcription/uploading/video_upload_screen.dart';
import 'package:wurp/ui/animations/slide_morph_transitions.dart';
import 'package:wurp/ui/screens/auth_screen.dart';
import 'package:wurp/ui/screens/chat/chat_managing_screen.dart';
import 'package:wurp/ui/screens/profile_screen.dart';
import 'package:wurp/ui/screens/quests/quest_screen.dart';
import 'package:wurp/ui/screens/search_screen/search_screen.dart';
import 'package:wurp/ui/screens/tasks/task_quiz_workspace_screen.dart';
import 'package:wurp/ui/short_video_player.dart';
import 'package:wurp/ui/theme/theme_creation_screen.dart';
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
        if (navBarIndex != -1 && navBarKey.currentState?.currentSelectedIndex != navBarIndex) {
          if (navBarKey.currentState == null) {
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              navBarKey.currentState?.switchToIndex(navBarIndex);
            });
          } else {
            navBarKey.currentState?.switchToIndex(navBarIndex);
          }
        }
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
          GoRoute(
            path: '/feed',
            pageBuilder: (context, state) =>
                SlideMorphTransitions.page<void>(key: state.pageKey, child: const VideoFeed(), beginOffset: const Offset(0.02, 0.0), beginScale: 0.995),
          ),
          GoRoute(
            path: '/search_screen',
            pageBuilder: (context, state) =>
                SlideMorphTransitions.page<void>(key: state.pageKey, child: const SearchScreen(), beginOffset: const Offset(0.03, 0.0), beginScale: 0.993),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => SlideMorphTransitions.page<void>(
              key: state.pageKey,
              child: ProfileScreen(initialProfile: currentUser, ownProfile: true, onFollowChange: (bool followed) {}),
              beginOffset: const Offset(0.03, 0.0),
              beginScale: 0.993,
            ),
          ),
          GoRoute(
            path: '/chat',
            pageBuilder: (context, state) => SlideMorphTransitions.page<void>(
              key: state.pageKey,
              child: ChatManagingScreen(preloadMoreChats: (current) => chatRepository.getChats(currentUser.id, offset: current ?? 0, limit: 15), key: chatManagingScreenKey,),
              beginOffset: const Offset(0.03, 0.0),
              beginScale: 0.993,
            ),
          ),
          GoRoute(
            path: '/create',
            pageBuilder: (context, state) => SlideMorphTransitions.page<void>(
              key: state.pageKey,
              child: const Scaffold(body: VideoUploadWidget()),
              beginOffset: const Offset(0.03, 0.0),
              beginScale: 0.993,
            ),
          ),
          GoRoute(
            path: '/quests',
            pageBuilder: (context, state) => SlideMorphTransitions.page<void>(
              key: state.pageKey,
              child: const TestQuestScreen(subject: 'General'),
              beginOffset: const Offset(0.03, 0.0),
              beginScale: 0.993,
            ),
          ),
          GoRoute(
            path: '/themes',
            pageBuilder: (context, state) => SlideMorphTransitions.page<void>(
              key: state.pageKey,
              child: const ThemeManagerScreen(),
              beginOffset: const Offset(0.03, 0.0),
              beginScale: 0.993,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) {
          return SlideMorphTransitions.page<void>(key: state.pageKey, child: const LoginScreen(), beginOffset: const Offset(0.0, 0.07), beginScale: 0.985);
        },
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => const NoTransitionPage(child: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) {
          print("navigating to reset password screen");
          return SlideMorphTransitions.page<void>(
            key: state.pageKey,
            child: const ResetPasswordScreen(),
            beginOffset: const Offset(0.0, 0.07),
            beginScale: 0.985,
          );
        },
      ),
      GoRoute(
        path: '/task-editor',
        pageBuilder: (context, state) => SlideMorphTransitions.page<void>(
          key: state.pageKey,
          child: const TaskQuizWorkspaceScreen(),
          beginOffset: const Offset(0.03, 0.0),
          beginScale: 0.993,
        ),
      ),
    ],
  );
}

GlobalObjectKey<BottomNavBarState> navBarKey = const GlobalObjectKey('bottomNavBarKey');
final BottomNavBar _bottomNavBar = BottomNavBar(
  initialIndex: 2,
  key: navBarKey,
  onSelectionChange: (p0) {
    routerConfig.go(p0);
  },
  items: _navigationBarItems,
);

List<({IconData icon, String label, String id})> _navigationBarItems = [
  (icon: Icons.home, label: 'Home', id: '/feed'),
  (icon: Icons.search, label: 'Discover', id: '/search_screen'),
  //(icon: Icons.add_box_outlined, label: '', id: '/create'),
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
