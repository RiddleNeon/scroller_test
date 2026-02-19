import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:provider/provider.dart';
import 'package:wurp/firebase_options.dart';
import 'package:wurp/logic/local_storage/local_seen_service.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/ui/auth/auth_screen.dart';
import 'package:wurp/ui/screens/home_screen.dart';

import 'next_try/home_screen.dart';
import 'next_try/video_feed_state.dart';

FirebaseApp? app;
FirebaseAuth? auth;

UserRepository? userRepository = UserRepository();

void main() async {
  print("MAIN FUNCTION STARTED");
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith();
  app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseFirestore.instance.runTransaction((transaction) async {}); //whyever it fixes a crash on windows
  auth = FirebaseAuth.instanceFor(app: app!);

  if(auth?.currentUser != null) {
    await onUserLogin();
  }
  
  runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        home: auth?.currentUser == null
            ? const LoginScreen()
            : MyHomePage(),
      )
  );
  
  
  if (kIsWeb) auth!.setPersistence(Persistence.LOCAL);
  print(auth?.currentUser);
}

Future<void> onUserLogin() async {
  print("login!");
  await LocalSeenService.init();
  //videoPublishTest();
  //removeAllPreferencesOfCurrentUser();
}

bool runningOnMobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
VideoProvider? videoProvider;
class TikTokCloneApp extends StatelessWidget {
  TikTokCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    videoProvider ??= RecommendationVideoProvider(userId: auth!.currentUser!.uid);
    return ChangeNotifierProvider(
      create: (_) => VideoFeedState(
        provider: videoProvider!,       // ← your VideoProvider implementation
        currentUserId: auth!.currentUser!.uid,   // ← FirebaseAuth.instance.currentUser!.uid
      ),
      child: MaterialApp(
        title: 'TikTok Clone',
        key: GlobalObjectKey("main_scaffold"),
        navigatorKey: GlobalObjectKey("main_navigator"),
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.grey,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF0050),
            secondary: Color(0xFF69C9D0),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
