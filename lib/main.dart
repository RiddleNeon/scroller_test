import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:wurp/firebase_options.dart';
import 'package:wurp/logic/local_storage/local_seen_service.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/ui/auth/auth_screen.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/screens/home_screen.dart';


FirebaseApp? app;
FirebaseAuth? auth;

UserRepository? userRepository = UserRepository();

FirebaseFirestore get firestore {
  if (_firestore == null) throw StateError("Firestore isnt initialized yet!");
  return _firestore!;
}
FirebaseFirestore? _firestore;

LocalSeenService get localSeenService {
  if (_localSeenService == null) throw StateError("Local Seen Service isnt initialized yet!");
  return _localSeenService!;
}
LocalSeenService? _localSeenService;

FeedViewModel get feedViewModel => _feedViewModel ??= FeedViewModel();
FeedViewModel? _feedViewModel;

void main() async {
  print("MAIN FUNCTION STARTED");
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith();
  app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseFirestore.instance.runTransaction((transaction) async {}); //whyever it fixes a crash on windows
  auth = FirebaseAuth.instanceFor(app: app!);
  _firestore = FirebaseFirestore.instance;
  VideoRepository().addComment("MrROkFLyYpSqOuxwcePncM8Kk4B3", "gYlpkVli3SAn1UHSv9K8", "HEHEHEHEHAAAA");

  if (auth?.currentUser != null) {
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
  await _feedViewModel?.dispose();
  await _localSeenService?.dispose();
  _localSeenService = LocalSeenService();
  await _localSeenService!.init();
  //videoPublishTest();
  //removeAllPreferencesOfCurrentUser();
}

RecommendationVideoProvider? _videoProvider;

RecommendationVideoProvider get videoProvider => _videoProvider ??= RecommendationVideoProvider(userId: auth!.currentUser!.uid);

bool runningOnMobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;