import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:wurp/firebase_options.dart';
import 'package:wurp/ui/scrolling_container.dart';

FirebaseApp? app;
FirebaseAuth? auth;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  auth = FirebaseAuth.instanceFor(app: app!);

  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      print("User id: ${user.uid}");
    }
  });

  runApp(const MyApp());
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Duration get loginTime => const Duration(milliseconds: 2250);
  bool enteredPasswordIncorrectly = false;

  Future<String?> _authUser(LoginData data) async {
    print("login data ${data.name}, ${data.password}");

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: data.name, password: data.password);
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
  }

  Future<String?> _signupUser(SignupData data) async {
    print("signup data ${data.name}, ${data.password}, additional: ${data.additionalSignupData}");

    if (data.password == null || data.name == null) return "please enter a valid email or password!";

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: data.name!, password: data.password!);
    } on FirebaseAuthException catch (e) {
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
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      print("sent to '$email'");
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Password reset failed';
    }
  }

  Future<String?> _sendCode(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print("Password Recovery error! $e");
      return e.message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      onLogin: _authUser,
      onSignup: _signupUser,
      onRecoverPassword: _recoverPassword,
      onConfirmRecover: null,
      onResendCode: null,

      onSubmitAnimationCompleted: () {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const MyHomePage(title: "scroller test")));
      },

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

class ResetPasswordButton extends StatelessWidget {
  const ResetPasswordButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showMenu(
        context: context,
        items: [PopupMenuItem(child: ResetPasswordPopup())],
        position: RelativeRect.fill,
      ),
      child: Text("forgot password"),
    );
  }
}

class ResetPasswordPopup extends StatelessWidget {
  const ResetPasswordPopup({super.key});

  @override
  Widget build(BuildContext context) => Card(child: Text("send email"), margin: EdgeInsets.all(10));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Lerntok halt', home: const LoginScreen(), debugShowCheckedModeBanner: false);
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(widget.title),
      ),
      body: Center(child: ScrollingContainer()),
    );
  }
}
