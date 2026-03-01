import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:wurp/logic/firebase_options.dart';
import 'package:wurp/logic/feed_recommendation/user_preference_manager.dart';
import 'package:wurp/logic/local_storage/local_seen_service.dart';
import 'package:wurp/logic/models/user_model.dart';
import 'package:wurp/logic/repositories/chat_repository.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/ui/router.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/screens/chat/chat_managing_screen.dart';


FirebaseApp? app;
FirebaseAuth? auth;
UserRepository userRepository = UserRepository();
ChatRepository chatRepository = ChatRepository();

FirebaseFirestore get firestore {
  if (_firestore == null) throw StateError("Firestore isn't initialized yet!");
  return _firestore!;
}
FirebaseFirestore? _firestore;

LocalSeenService get localSeenService {
  if (_localSeenService == null) throw StateError("Local Seen Service isn't initialized yet!");
  return _localSeenService!;
}
LocalSeenService? _localSeenService;

FeedViewModel get feedViewModel => _feedViewModel ??= FeedViewModel(videoProvider);
FeedViewModel? _feedViewModel;

RecommendationVideoProvider? _videoProvider;
RecommendationVideoProvider get videoProvider => _videoProvider ??= RecommendationVideoProvider();


final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

UserProfile get currentUser {
  assert(_currentUser != null, "No user is currently logged in!");
  return _currentUser!;
}

set currentUser(UserProfile newUser) {
  _currentUser = newUser;
}

UserProfile? _currentUser;

bool get userLoggedIn => _currentUser != null;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith();
  app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseFirestore.instance.runTransaction((transaction) async {}); //somehow it fixes a crash on windows
  auth = FirebaseAuth.instanceFor(app: app!);
  _firestore = FirebaseFirestore.instance;
  _firestore?.settings = const Settings(persistenceEnabled: true);
  await _setupMessaging();
  FirebaseMessaging.onBackgroundMessage((message) async {
    print("MESSAGE: ${message}");
  },);
  initRouter();
  routerConfig.refresh();
  if (auth?.currentUser != null) {
    print("user not null");
    await onUserLogin(await userRepository.getUser(auth!.currentUser!.uid));
  }

  print("running now ");
  runApp(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.from(colorScheme: getColorScheme()).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B1220),
      ),
      routerConfig: routerConfig,
    ),
  );

  print(auth?.currentUser);
}
FirebaseMessaging messaging = FirebaseMessaging.instance;
Future<void> _setupMessaging() async {
  
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground: ${message.notification?.title}');
    print("data: ${message.notification?.body}");
    Map<String, dynamic> bodyContent = jsonDecode(message.notification!.body!);
    if(currentOpenChat?.partnerId == bodyContent['sender']) {currentOpenChatScreenKey?.currentState?.onReceiveMessage(bodyContent['message']);}
  });
  FirebaseMessaging.onBackgroundMessage((message) async {
    print('Background: ${message.notification?.title}');
    print("data: ${message.notification?.body}");
    Map<String, dynamic> bodyContent = jsonDecode(message.notification!.body!);
    if(currentOpenChat?.partnerId == bodyContent['sender']) {currentOpenChatScreenKey?.currentState?.onReceiveMessage(bodyContent['message']);}
  });
  
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Opened app via Notification: ${message.data}');
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': newToken,
      });
    }
  });
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

Future<void> onUserLogin(UserProfile user, [BuildContext? context]) async {
  await onUserLogout();
  _currentUser = user;
  if (kIsWeb) {
    auth!.setPersistence(Persistence.LOCAL);
  }
  _localSeenService = LocalSeenService();
  await _localSeenService!.init();
  final token = await messaging.getToken(vapidKey: "BMzrcPy9WqWjCd72OCbRQS2hdTXcMN2khJ3sZcUED9xRHZq6TQjVDo6y2icQtweVaFOp7kRAS085VeQgqZlFK0E");
  await FirebaseFirestore.instance.collection('users').doc(currentUser.id).update({
    'fcmToken': token,
  });
}

Future<void> onUserLogout() async {
  UserPreferenceManager.reset();
  await feedViewModel.dispose();
  await _localSeenService?.dispose();
}

void rebuildAllChildren(BuildContext context) {
  void rebuild(Element el) {
    el.markNeedsBuild();
    el.visitChildren(rebuild);
  }
  (context as Element).visitChildren(rebuild);
}

bool runningOnMobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;