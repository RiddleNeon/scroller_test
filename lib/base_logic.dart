import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wurp/logic/quests/quest_system.dart';
import 'package:wurp/logic/repositories/quest_repository.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';
import 'package:wurp/ui/feed_view_model.dart';

import 'logic/feed_recommendation/user_preference_manager.dart';
import 'logic/local_storage/local_seen_service.dart';
import 'logic/users/user_model.dart';
import 'logic/quests/quest_change_manager.dart';
import 'logic/repositories/chat_repository.dart';
import 'logic/repositories/user_repository.dart';
import 'logic/video/video_provider.dart';

GoTrueClient get auth => supabaseClient.auth;

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
  if(_currentUser != null) await onUserLogout();
  await ensureSupabaseInitialized();
  await questSystem.loadFromServer('');
  changeManager = QuestChangeManager(
    questSystem: questSystem,
    repo: questRepo,
  );
}

Future<void> onUserLogin(UserProfile user) async {
  print("User logged in: ${user.id}");
  _currentUser = user;
  await onUserLoginSupabaseTest();
  await initLocalSeenService();
  if (kIsWeb) {
    print("Using Supabase persisted auth session on web.");
  }
}

String currentAuthUserId() => auth.currentUser?.id ?? currentUser.id;

String currentAuthUsername() {
  final user = auth.currentUser;
  if (user == null) return currentUser.id;

  final displayName = user.userMetadata?['full_name'];
  if (displayName != null) return displayName;

  final email = user.email;
  if (email != null && email.contains('@')) {
    return email.split('@').first;
  }
  return user.id;
}

Future<void> onUserLogout() async {
  await auth.signOut();
  UserPreferenceManager.reset();
  await feedViewModel.dispose();
}

bool runningOnMobile = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;