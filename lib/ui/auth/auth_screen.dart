import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../logic/models/user_model.dart';
import '../../main.dart';
import '../screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Duration get loginTime => const Duration(milliseconds: 2250);
  bool enteredPasswordIncorrectly = false;

  Future<String?> _authUser(LoginData data) async {
    if(auth?.currentUser != null){
      await auth!.signOut();
    }
    
    UserCredential? credential;
    try {
      credential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: data.name, password: data.password);
    } on FirebaseAuthException catch (e) {
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

    UserProfile user = await userRepository!.getUser(credential.user!.uid);
    print(user);
    return null; //no error message -> success
  }

  Future<String?> _signupUser(SignupData data) async {
    if(auth?.currentUser != null){
      await auth!.signOut();
    }
    
    
    if (data.password == null || data.name == null) return "please enter a valid email or password!";
    UserCredential? credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: data.name!, password: data.password!);
    } on FirebaseAuthException catch (e) {
      String? fullMessage = e.message;
      print("$fullMessage");
      return fullMessage ?? "An unknown error has occurred!";
    } catch (e) {
      print("unknown signup error! $e");
      return "an unknown error has occurred!";
    }

    UserProfile user = await userRepository!.createUser(id: credential.user!.uid, username: credential.user?.displayName ?? credential.user!.email!.split("@").first);
    print(user);
    return null; //no error message -> success
  }

  Future<String?> _recoverPassword(String email) async {
    try {      
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Password reset failed';
    }
  }

  void completeLogin() async {
    print("completing login...");
    try {
      await onUserLogin();
      if(mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MyHomePage()),
        );
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
            callback: () => signInWithProvider(GoogleAuthProvider()),
          ),
      ],
    );
  }

  Future<String?> signInWithProvider(AuthProvider provider) async{
    if(auth?.currentUser != null){
      await auth!.signOut();
    }
    
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        print("trying to log in with provider");
        await FirebaseAuth.instance.signInWithProvider(provider);
      } else {
        return "Unsupported Device! Please use regular login!";
      }
    } on FirebaseAuthException catch(e) {
      return e.message;
    }
    return null;
  }

  bool get notWindows =>
      defaultTargetPlatform != TargetPlatform.windows && defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.linux;
}
