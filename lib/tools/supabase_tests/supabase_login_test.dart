import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:wurp/base_logic.dart';
import 'package:wurp/base_ui.dart';

void main() async {
  print("running main");
  await initLogic();
  print("logic initialized");

  startApp();
}

Future<void> onUserLoginSupabaseTest() async {
  await ensureSupabaseInitialized();
  await userRepository.upsertCurrentUserProfile(currentUser);
  //await publishTestYoutube();
}

Future<void> ensureSupabaseInitialized() async {
  if (_supabase != null) return;

  _supabase = await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
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
