import 'package:flutter/material.dart';
import 'package:wurp/ui/router.dart';

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
        
        print("logged out, navigating to login screen");
        routerConfig.go('/login');
      }, child: const Icon(Icons.logout_rounded)),
    );
  }
}
