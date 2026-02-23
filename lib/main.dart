import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:wurp/firebase_options.dart';
import 'package:wurp/logic/comments/comment.dart';
import 'package:wurp/logic/feed_recommendation/user_preference_manager.dart';
import 'package:wurp/logic/local_storage/local_seen_service.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/ui/auth/auth_screen.dart';
import 'package:wurp/ui/feed_view_model.dart';
import 'package:wurp/ui/overlays.dart';
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

FeedViewModel get feedViewModel => _feedViewModel ??= FeedViewModel(videoProvider);
FeedViewModel? _feedViewModel;


final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  print("MAIN FUNCTION STARTED");
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith();
  app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseFirestore.instance.runTransaction((transaction) async {}); //whyever it fixes a crash on windows
  auth = FirebaseAuth.instanceFor(app: app!);
  _firestore = FirebaseFirestore.instance;
  print("adding comment");
  await VideoRepository().addComment("gYlpkVli3SAn1UHSv9K8", Comment(id: '${DateTime.now().millisecondsSinceEpoch}_${"ligma".hashCode.abs()}', userId: auth!.currentUser!.uid, message: "LIGMA", date: DateTime.now(), username: "MrRokfly", userProfileImageUrl: "https://api.dicebear.com/7.x/thumbs/png?seed=yoMama"));
  print("comment added");
  List<Comment> comments = (await videoRepo.getComments("gYlpkVli3SAn1UHSv9K8")).comments;
  print("comments: ${comments.toList()}");
  if (auth?.currentUser != null) {
    await onUserLogin();
  }

  runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        theme: ThemeData(primarySwatch: Colors.blue),
        home: auth?.currentUser == null
            ? const LoginScreen()
            : MyHomePage(),
      )
  );


  if (kIsWeb) auth!.setPersistence(Persistence.LOCAL);
  print(auth?.currentUser);
}

Future<void> onUserLogin([BuildContext? context]) async {
  print("login!");
  UserPreferenceManager.reset();
  await feedViewModel.dispose();
  await _localSeenService?.dispose();
  _localSeenService = LocalSeenService();
  await _localSeenService!.init();
  if(context != null) {
    rebuildAllChildren(context);
  }
  //videoPublishTest();
  //removeAllPreferencesOfCurrentUser();
}

void rebuildAllChildren(BuildContext context) {
  void rebuild(Element el) {
    el.markNeedsBuild();
    el.visitChildren(rebuild);
  }
  (context as Element).visitChildren(rebuild);
}

RecommendationVideoProvider? _videoProvider;
RecommendationVideoProvider get videoProvider => _videoProvider ??= RecommendationVideoProvider();

bool runningOnMobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;