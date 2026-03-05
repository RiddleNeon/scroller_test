import 'package:firebase_auth/firebase_auth.dart';
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
  print("logged into supabase, auth: ${auth?.currentUser?.uid}");
  supabase = await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    accessToken: () async {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      return token;
    },
  );
  print("supabase initialized!");
  await supabase.client.from("profiles").insert({
    "id": currentUser.id,
    "username": currentUser.username,
    "display_name": currentUser.username,
    "avatar_url": currentUser.profileImageUrl,
    "bio": currentUser.bio,
  });
}

late final Supabase supabase;
SupabaseClient get supabaseClient => supabase.client;