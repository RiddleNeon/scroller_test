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

import '../logic/chat/chat_message.dart';
import 'misc/youtube_player.dart';

late final GoRouter routerConfig;

void initRouter() {
  routerConfig = GoRouter(
    navigatorKey: appNavigatorKey,
    redirect: (context, state) {
      final navBarItem = _navigationBarItems.where((element) => element.id == state.matchedLocation).firstOrNull;
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
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
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
            path: '/call',
            builder: (context, state) => const CallingApp(name: "Yo Mama", profileImageUrl: "https://i.ebayimg.com/images/g/0GQAAOSwrIlasZ7p/s-l1200.jpg"),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) => FutureBuilder(
              future: localSeenService.getMessagesWith("MrROkFLyYpSqOuxwcePncM8Kk4B3", limit: 10),
              builder: (context, asyncSnapshot) {
                if(asyncSnapshot.data == null) return Container();
                
                return MessagingScreen(
                  key: _messagingScreenKey,
                  isOnline: true,
                  recipientName: "Julian",
                  recipientAvatarUrl: "https://res.cloudinary.com/dvw3vksqx/image/upload/v1772225146/jzrnlvckuyuojqiix37i.png",
                  onSend: (message) async {
                    chatRepository.sendNotification(
                      receiverUid: "MrROkFLyYpSqOuxwcePncM8Kk4B3",
                      message: ChatMessage(id: "MrROkFLyYpSqOuxwcePncM8Kk4B3-${DateTime.now().microsecondsSinceEpoch}", text: message, isMe: true, timestamp: DateTime.now()),
                    );
                    print("sent: $message");
                  },
                  initialMessages: asyncSnapshot.data!,
                );
              }
            ),
          ),
          GoRoute(
            path: '/rick',
            builder: (context, state) =>
                YouTubePlayerWidget(autoPlay: true, showControls: false, videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', key: _youtubePlayerWidgetKey),
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
