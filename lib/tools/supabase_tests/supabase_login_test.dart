import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wurp/base_logic.dart';
import 'package:wurp/base_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../logic/firebase_options.dart';

void main() async {
  print("running main");
  await initLogic();
  print("logic initialized");
  
  
  startApp();
}

Future<void> onUserLoginSupabaseTest() async {
  await ensureSupabaseInitialized();
  await userRepository.upsertCurrentUserProfile(currentUser);
}

Future<void> ensureSupabaseInitialized() async {
  if (_supabase != null && Firebase.apps.isNotEmpty) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  if (_supabase != null) return;
  _supabase = await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    accessToken: () async {
      final token = await auth?.currentUser?.getIdToken();
      return token;
    },
  );
}

Supabase? _supabase;
Supabase get supabase {
  if (_supabase == null) {
    throw StateError('Supabase has not been initialized yet.');
  }
  return _supabase!;
}
SupabaseClient get supabaseClient => supabase.client;
