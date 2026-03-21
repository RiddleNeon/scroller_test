import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/logic/repositories/quest_repository.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';
import 'package:wurp/ui/feed_view_model.dart';

import 'logic/feed_recommendation/user_preference_manager.dart';
import 'logic/local_storage/local_seen_service.dart';
import 'logic/models/user_model.dart';
import 'logic/quests/quest_change_manager.dart';
import 'logic/repositories/chat_repository.dart';
import 'logic/repositories/user_repository.dart';
import 'logic/video/video_provider.dart';

FirebaseAuth? auth;

UserRepository userRepository = UserRepository();
ChatRepository chatRepository = ChatRepository();

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
  debugPrint("Initializing logic...");
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith();
  await ensureSupabaseInitialized();
  await questSystem.loadFromServer('Brewing');
  changeManager = QuestChangeManager(
    questSystem: questSystem,
    repo: questRepo,
  );
  auth = FirebaseAuth.instance;
}

Future<void> onUserLogin(UserProfile user, [BuildContext? context]) async {
  _currentUser = user;
  await onUserLoginSupabaseTest();
  await onUserLogout();
  await initLocalSeenService();
  if (kIsWeb) {
    print("Using Supabase persisted auth session on web.");
  }
}

Future<void> onUserLogout() async {
  UserPreferenceManager.reset();
  await feedViewModel.dispose();
}

bool runningOnMobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

String currentAuthUserId() => auth?.currentUser?.uid ?? currentUser.id;

String currentAuthUsername() {
  final displayName = auth?.currentUser?.displayName;
  if (displayName != null && displayName.trim().isNotEmpty) return displayName;
  final email = auth?.currentUser?.email;
  if (email != null && email.contains('@')) {
    return email.split('@').first;
  }
  return auth?.currentUser?.uid ?? currentUser.id;
}
