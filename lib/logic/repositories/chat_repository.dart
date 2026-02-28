import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:wurp/logic/chat/chat_message.dart';
import 'package:wurp/main.dart';

class ChatRepository {
  Future<void> sendNotification({
    required String receiverUid,
    required ChatMessage message,
  }) async {
    
    localSeenService.sendMessageLocal(receiverUid, message);
    
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverUid)
        .get();

    final token = doc.data()?['fcmToken'];
    if (token == null) return;
    
    String body = jsonEncode({
      'token': token,
      'title': 'new Message',
      'body': {
        "message": message.text,
        "sender": currentUser.id
      }.toString()
    });
    print("body: $body");

    await http.post(
      Uri.parse('https://wurp-fcm-server.onrender.com/send'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    
    String senderUid = currentUser.id;
    bool senderIsA = senderUid.hashCode > receiverUid.hashCode;
    
    
    String uidA = senderIsA ? senderUid : receiverUid;
    String uidB = senderIsA ? receiverUid : senderUid;

    await FirebaseFirestore.instance
        .collection('chat')
        .doc("$uidA-${uidB}")
        .collection('messages')
        .doc(message.id).set(message.toFirestore(receiverUid == uidB));
    print("set");
  }

  Future<List<ChatMessage>> getMessagesWith(
      String otherUserId, {
        int limit = 30,
      }) async {
    return localSeenService.getMessagesWith(otherUserId, limit: limit);
  }

  ChatMessage? getMessage(String otherUserId, String messageId) {
    return localSeenService.getMessage(otherUserId, messageId);
  }
}