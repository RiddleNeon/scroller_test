import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:wurp/logic/chat/chat_message.dart';
import 'package:wurp/main.dart';

import '../chat/chat.dart';

class ChatRepository {
  Future<void> sendNotification({
    required Chat chat,
    required ChatMessage message,
  }) async {
    String receiverUid = chat.partnerId;


    String? token = await localSeenService.getFcmToken(receiverUid);
    if(token == null) {
      print("Targeted User has no fcm token!");
      //return; //todo re-add
    }

    final ref = firestore
        .collection('users')
        .doc(currentUser.id)
        .collection('contacts')
        .doc(receiverUid);
    
    if(!localSeenService.hasChatWith(receiverUid)){
      print("opened new chat with $receiverUid");
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': message.text,
        'partnerName': chat.partnerName,
        'partnerProfileImageUrl': chat.partnerProfileImageUrl
      }, SetOptions(merge: true));
    } else {
      print("alr has chat with that person, updating");
      await ref.set({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': message.text,
        'partnerName': chat.partnerName,
        'partnerProfileImageUrl': chat.partnerProfileImageUrl
      }, SetOptions(merge: true));
    }

    final inner = jsonEncode({
      'message': message.text,
      'sender': currentUser.id,
    });

    if(token != null){
      String body = jsonEncode({
        'token': token,
        'title': 'new Message',
        'body': inner
      });
      print("body: $body");

      await http.post(
        Uri.parse('https://wurp-fcm-server.onrender.com/send'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    }
    
    await firestore
        .collection('chats')
        .doc(getChatId(receiverId: receiverUid))
        .collection('messages')
        .doc(message.id).set(message.toFirestore(currentUser.id.compareTo(receiverUid) > 0));
    print("set");

    await localSeenService.sendMessageLocal(chat, message);
    chat.lastMessage = message.text;
    chat.lastMessageAt = DateTime.now();
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

String getChatId({String? currentUserId, required String receiverId}){
  currentUserId ??= currentUser.id;
  final ids = [currentUser.id, receiverId]..sort();
  return "${ids[0]}-${ids[1]}";
}