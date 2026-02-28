import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class ChatRepository {
  Future<void> sendNotification({
    required String receiverUid,
    required String title,
    required String body,
  }) async {
    
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverUid)
        .get();

    final token = doc.data()?['fcmToken'];
    if (token == null) return;

    await http.post(
      Uri.parse('https://wurp-fcm-server.onrender.com/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'title': title,
        'body': body,
      }),
    );
  }
  
}