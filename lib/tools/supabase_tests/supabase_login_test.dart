import 'package:wurp/base_logic.dart';
import 'package:wurp/base_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

void main() async {
  print("running main");
  await initLogic();
  print("logic initialized");
  
  
  startApp(true);
}

Future<void> onUserLoginSupabaseTest() async {
  print("logged into supabase, auth: ${auth?.currentUser?.id}");
  await ensureSupabaseInitialized();
  print("supabase initialized!");
  await userRepository.upsertCurrentUserProfile(currentUser);
}

Future<void> ensureSupabaseInitialized() async {
  if (_supabase != null) return;
  _supabase = await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
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
