import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:wurp/firebase_options.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/ui/auth/auth_screen.dart';
import 'package:wurp/ui/screens/home_screen.dart';

FirebaseApp? app;
FirebaseAuth? auth;

UserRepository? userRepository = UserRepository();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  auth = FirebaseAuth.instanceFor(app: app!);
  auth!.setPersistence(Persistence.LOCAL);
  print(auth?.currentUser);
  await FirebaseFirestore.instance.runTransaction((transaction) async {});
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    if(auth?.currentUser != null) {
      return MaterialApp(title: 'Lerntok halt', home: const MyHomePage(), debugShowCheckedModeBanner: false, theme: ThemeData(
        primarySwatch: Colors.blue,
      ));
    }
    return MaterialApp(title: 'Lerntok halt', home: const LoginScreen(), debugShowCheckedModeBanner: false, theme: ThemeData(
      primarySwatch: Colors.blue,
    ));
  }
}