import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wurp/ui/router.dart';

import '../../base_logic.dart';
import '../../logic/models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Duration get loginTime => const Duration(milliseconds: 2250);
  bool enteredPasswordIncorrectly = false;
  
  UserProfile? user;

  Future<String?> _authUser(LoginData data) async {
    try {
      final response = await auth!.signInWithPassword(
        email: data.name,
        password: data.password,
      );

      final signedInUser = response.user;
      if (signedInUser == null) return "Unable to sign in.";

      user = await userRepository.getUserSupabase(signedInUser.id) ?? await userRepository.getOrCreateCurrentUser();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unknown error occurred!";
    }
  }
  
  Future<String?> _signupUser(SignupData data) async {
    if (data.password == null || data.name == null) return "Please enter credentials!";
    try {
      final response = await auth!.signUp(
        email: data.name!,
        password: data.password!,
      );

      if (response.user == null) return "Unable to create user.";

      user = await userRepository.createCurrentUser(
        username: currentAuthUsername(),
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> _recoverPassword(String email) async {
    try {
      await auth!.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : 'de.riddleneon.wurp://reset-callback/', //todo
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An error occurred.";
    }
  }

  void completeLogin() async {
    assert(user != null, "Login completed but no user is logged in!");
    print("completing login...");
    try {
      await onUserLogin(user!, context);
      if(mounted) {
        routerConfig.push('/feed');
      }
    } catch (e, st) {
      print('Login failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      onLogin: _authUser,
      onSignup: _signupUser,
      onRecoverPassword: _recoverPassword,
      onConfirmRecover: null,
      onResendCode: null,
      theme: LoginTheme(primaryColor: Colors.blueAccent),
      messages: LoginMessages(recoverPasswordDescription: "Enter your email to receive a password reset link.", recoverPasswordSuccess: "Password reset email sent!"),
      onSubmitAnimationCompleted: completeLogin,
    );
  }

  bool get notWindows =>
      defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.linux;
}
