
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:wurp/ui/screens/chat/chat_managing_screen.dart';

import 'base_logic.dart';

FirebaseMessaging messaging = FirebaseMessaging.instance;
Future<void> setupMessaging() async {
  if (!await FirebaseMessaging.instance.isSupported()) {
    print("Messaging not supported! skipping!");
    return;
  }

  messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Foreground: ${message.notification?.title}');
    print("data: ${message.notification?.body}");
    Map<String, dynamic> bodyContent = jsonDecode(message.notification!.body!);
    if(currentOpenChat?.partnerId == bodyContent['sender']) {currentOpenChatScreenKey?.currentState?.onReceiveMessage(bodyContent['message']);}
  });
  FirebaseMessaging.onBackgroundMessage((message) async {
    print('Background: ${message.notification?.title}');
    print("data: ${message.notification?.body}");
    Map<String, dynamic> bodyContent = jsonDecode(message.notification!.body!);
    if(currentOpenChat?.partnerId == bodyContent['sender']) {currentOpenChatScreenKey?.currentState?.onReceiveMessage(bodyContent['message']);}
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Opened app via Notification: ${message.data}');
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await userRepository.updateFcmTokenSupabase(uid, newToken);
    }
  });
}
