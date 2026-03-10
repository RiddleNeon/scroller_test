import 'dart:convert';

import 'package:wurp/ui/screens/chat/chat_managing_screen.dart';

Future<void> setupMessaging() async {
  print('Push messaging setup skipped.');
}

void handleIncomingMessagePayload(String? body) {
  if (body == null) return;
  final bodyContent = jsonDecode(body) as Map<String, dynamic>;
  if (currentOpenChat?.partnerId == bodyContent['sender']) {
    currentOpenChatScreenKey?.currentState?.onReceiveMessage(bodyContent['message']);
  }
}
