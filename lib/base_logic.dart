import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';
import 'package:wurp/ui/feed_view_model.dart';

import 'logic/feed_recommendation/user_preference_manager.dart';
import 'logic/firebase_options.dart';
import 'logic/local_storage/local_seen_service.dart';
import 'logic/models/user_model.dart';
import 'logic/repositories/chat_repository.dart';
import 'logic/repositories/user_repository.dart';
import 'logic/video/video_provider.dart';
import 'messaging_base.dart';

FirebaseApp? app;
FirebaseAuth? auth;

UserRepository userRepository = UserRepository();
ChatRepository chatRepository = ChatRepository();

FirebaseFirestore get firestore {
  if (_firestore == null) throw StateError("Firestore isn't initialized yet!");
  return _firestore!;
}
FirebaseFirestore? _firestore;


UserProfile get currentUser {
  assert(_currentUser != null, "No user is currently logged in!");
  return _currentUser!;
}
set currentUser(UserProfile newUser) {
  _currentUser = newUser;
}
UserProfile? _currentUser;
bool get userLoggedIn => _currentUser != null;


FeedViewModel get feedViewModel => _feedViewModel ??= FeedViewModel(videoProvider);
FeedViewModel? _feedViewModel;

RecommendationVideoProvider? _videoProvider;
RecommendationVideoProvider get videoProvider => _videoProvider ??= RecommendationVideoProvider();



Future<void> initLogic() async {
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith();
  app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseFirestore.instance.runTransaction((transaction) async {}); //somehow it fixes a crash on windows
  auth = FirebaseAuth.instanceFor(app: app!);
  _firestore = FirebaseFirestore.instance;
  _firestore?.settings = const Settings(persistenceEnabled: true);
}

Future<void> onUserLogin(UserProfile user, [BuildContext? context]) async {
  await onUserLoginSupabaseTest();
  await onUserLogout();
  _currentUser = user;
  if (kIsWeb) {
    auth!.setPersistence(Persistence.LOCAL);
  }
  await initLocalSeenService();
  if (!await FirebaseMessaging.instance.isSupported()) {
    print("Messaging not supported! skipping uploading!");
    return;
  }
  final token = await messaging.getToken(vapidKey: "BMzrcPy9WqWjCd72OCbRQS2hdTXcMN2khJ3sZcUED9xRHZq6TQjVDo6y2icQtweVaFOp7kRAS085VeQgqZlFK0E");
  await userRepository.updateFcmTokenSupabase(currentUser.id, token);
}

Future<void> onUserLogout() async {
  UserPreferenceManager.reset();
  await feedViewModel.dispose();
  
}


bool runningOnMobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
