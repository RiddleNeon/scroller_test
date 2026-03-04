import 'package:flutter/material.dart';
import 'package:wurp/ui/screens/auth_screen.dart';

import '../../base_logic.dart';

class LogoutButton extends StatefulWidget {
  const LogoutButton({super.key});

  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton> {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "logout",
      child: InkWell(onTap: () async {
        await onUserLogout();
        await auth!.signOut();
        Navigator.of(context).push(MaterialPageRoute(builder: (context) {
          return const LoginScreen();
        },));      
      }, child: const Icon(Icons.logout_rounded)),
    );
  }
}
