import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wurp/firebase_options.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/ui/auth/auth_screen.dart';
import 'package:wurp/ui/screens/home_screen.dart';
FirebaseApp? app;
FirebaseAuth? auth;

UserRepository? userRepository = UserRepository();

void main() async {
  print("MAIN FUNCTION STARTED");
  WidgetsFlutterBinding.ensureInitialized();
  app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  auth = FirebaseAuth.instanceFor(app: app!);
  if (kIsWeb) auth!.setPersistence(Persistence.LOCAL);
  print(auth?.currentUser);
  await FirebaseFirestore.instance.runTransaction((transaction) async {}); //whyever it fixes a crash on windows

  runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        home: auth?.currentUser == null
            ? const LoginScreen()
            : MyHomePage(),
      )
  );
}