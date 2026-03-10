import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
    if(auth?.currentUser != null){
      await auth!.signOut();
    }

    try {
      final response = await supabaseClient.auth.signInWithPassword(email: data.name, password: data.password);
      final signedInUser = response.user;
      if (signedInUser == null) return "Unable to sign in.";
      user = await userRepository.getUserSupabase(signedInUser.id) ?? await userRepository.getOrCreateCurrentUser();
      print(user);
      return null;
    } on AuthException catch (e) {
      String? fullMessage = e.message;
      print("$fullMessage");
      if (fullMessage?.contains("internal") ?? false) {
        setState(() {
          enteredPasswordIncorrectly = true;
        });
      }
      return fullMessage ?? "An unknown error has occurred!";
    } catch (e) {
      print("unknown signup error! $e");
      return "an unknown error has occurred!";
    }
  }

  Future<String?> _signupUser(SignupData data) async {
    if(auth?.currentUser != null){
      await auth!.signOut();
    }
    
    
    if (data.password == null || data.name == null) return "please enter a valid email or password!";
    try {
      final response = await supabaseClient.auth.signUp(email: data.name!, password: data.password!);
      if (response.user == null) return "Unable to create user.";
      user = await userRepository.createCurrentUser(
        username: currentAuthUsername(),
      );
      print(user);
      return null;
    } on AuthException catch (e) {
      String? fullMessage = e.message;
      print("$fullMessage");
      return fullMessage ?? "An unknown error has occurred!";
    } catch (e) {
      print("unknown signup error! $e");
      return "an unknown error has occurred!";
    }
  }

  Future<String?> _recoverPassword(String email) async {
    try {
      await supabaseClient.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message ?? 'Password reset failed';
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
      loginProviders: <LoginProvider>[
        if (notWindows || kIsWeb)
          LoginProvider(
            icon: FontAwesomeIcons.google,
            label: 'Google',
            callback: signInWithGoogle,
          ),
      ],
    );
  }

  Future<String?> signInWithGoogle() async{
    if(auth?.currentUser != null){
      await auth!.signOut();
    }

    try {
      await supabaseClient.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.wurp://login-callback/',
      );
      return null;
    } on AuthException catch(e) {
      return e.message;
    }
  }

  bool get notWindows =>
      defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.linux;
}
