import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/screens/auth_screen.dart';
import 'package:wurp/ui/screens/bottom_navigation_bar.dart';
import 'package:wurp/ui/screens/chat/calling_screen.dart';
import 'package:wurp/ui/screens/chat/chat_screen.dart';
import 'package:wurp/ui/screens/profile_screen.dart';
import 'package:wurp/ui/screens/search_screen/search_screen.dart';
import 'package:wurp/ui/short_video_player.dart';

import 'misc/youtube_player.dart';

late final GoRouter routerConfig;

void initRouter() {
  routerConfig = GoRouter(
    navigatorKey: appNavigatorKey,
    redirect: (context, state) {
      final navBarItem = _navigationBarItems
          .where(
            (element) => element.id == state.matchedLocation,
          )
          .firstOrNull;
      if (navBarItem != null) {
        int navBarIndex = _navigationBarItems.indexOf(navBarItem);
        if (navBarIndex != -1) navBarKey.currentState?.switchToIndex(navBarIndex);
      }

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
            builder: (context, state) => const VideoFeed(),
          ),
          GoRoute(
            path: '/search_screen',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => ProfileScreen(profile: currentUser, ownProfile: true),
          ),          
          GoRoute(
            path: '/call',
            builder: (context, state) => const CallingApp(),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => MessagingScreen(
              key: _messagingScreenKey,
              isOnline: true,
              recipientName: "Donald Trump",
              recipientAvatarUrl: "https://i.ebayimg.com/images/g/0GQAAOSwrIlasZ7p/s-l1200.jpg",
              onSend: (message) async {
                chatRepository.sendNotification(receiverUid: currentUser.id, title: 'New Message by trump!', body: message);
                Future.delayed(
                    const Duration(milliseconds: 500), () => _messagingScreenKey.currentState?.onReceiveMessage('heheheha make amerriikkka kreat agaiin blub'));
                print("sent: $message");
              },
              initialMessages: [
                ChatMessage(id: "${DateTime.now().hashCode}", text: "hii", isMe: true, timestamp: DateTime.now().subtract(const Duration(minutes: 1))),
                ChatMessage(id: "${DateTime.now().hashCode+1}", text: "no hii", isMe: false, timestamp: DateTime.now().subtract(const Duration(minutes: 2))),
                ChatMessage(id: "${DateTime.now().hashCode+2}", text: "yes hii", isMe: true, timestamp: DateTime.now().subtract(const Duration(minutes: 3))),
                ChatMessage(id: "${DateTime.now().hashCode+3}", text: "bye", isMe: false, timestamp: DateTime.now().subtract(const Duration(minutes: 4))),
                ChatMessage(id: "${DateTime.now().hashCode+3}", text: "bye", isMe: false, timestamp: DateTime.now().subtract(const Duration(minutes: 4))),
                ChatMessage(id: "${DateTime.now().hashCode+3}", text: "bye", isMe: false, timestamp: DateTime.now().subtract(const Duration(minutes: 4))),
              ],
            ),
          ),
          GoRoute(
            path: '/rick',
            builder: (context, state) => YouTubePlayerWidget(
              autoPlay: true,
              showControls: false,
              videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
              key: _youtubePlayerWidgetKey,
            ),
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

GlobalObjectKey<YouTubePlayerWidgetState> _youtubePlayerWidgetKey = GlobalObjectKey(DateTime.now());
GlobalObjectKey<MessagingScreenState> _messagingScreenKey = const GlobalObjectKey("messaging_screen");

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
