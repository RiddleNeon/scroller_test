import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:wurp/logic/chat/chat_message.dart';

import '../../base_logic.dart';
import '../chat/chat.dart';
import '../local_storage/local_seen_service.dart';

class ChatRepository {
  Future<void> sendNotification({required Chat chat, required ChatMessage message}) async {
    String receiverUid = chat.partnerId;

    String? token = await localSeenService.getFcmToken(receiverUid);
    if (token == null) {
      print("Targeted User has no fcm token!");
      //return; //todo re-add
    }
    
    print("sending notification");

    final ref = firestore.collection('users').doc(currentUser.id).collection('contacts').doc(receiverUid);
    final partnerRef = firestore.collection('users').doc(receiverUid).collection('contacts').doc(currentUser.id);

    if (!localSeenService.hasChatWith(receiverUid)) {
      print("opened new chat with $receiverUid");
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': message.text,
        'partnerName': chat.partnerName,
        'partnerProfileImageUrl': chat.partnerProfileImageUrl,
        'lastMessageByMe': true,
      }, SetOptions(merge: true));
      await partnerRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': message.text,
        'partnerName': currentUser.username,
        'partnerProfileImageUrl': currentUser.profileImageUrl,
        'lastMessageByMe': false,
      }, SetOptions(merge: true));
    } else {
      print("alr has chat with that person, updating");
      await ref.set({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': message.text,
        'partnerName': chat.partnerName,
        'partnerProfileImageUrl': chat.partnerProfileImageUrl,
        'lastMessageByMe': true,
      }, SetOptions(merge: true));
      await partnerRef.set({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': message.text,
        'partnerName': currentUser.username,
        'partnerProfileImageUrl': currentUser.profileImageUrl,
        'lastMessageByMe': false,
      }, SetOptions(merge: true));
    }

    final inner = jsonEncode({'message': message.text, 'sender': currentUser.id});

    if (token != null) {
      String body = jsonEncode({'token': token, 'title': 'new Message', 'body': inner});
      print("body: $body");

      await http.post(Uri.parse('https://wurp-fcm-server.onrender.com/send'), headers: {'Content-Type': 'application/json'}, body: body);
    }

    await firestore
        .collection('chats')
        .doc(getChatId(receiverId: receiverUid))
        .collection('messages')
        .doc(message.id)
        .set(message.toFirestore(currentUser.id.compareTo(receiverUid) > 0));
    print("set");

    await localSeenService.sendMessageLocal(chat, message);
    chat.lastMessage = message.text;
    chat.lastMessageAt = DateTime.now();
  }

  Future<List<ChatMessage>> getMessagesWith(String otherUserId, {int limit = 30}) async {
    return localSeenService.getMessagesWith(otherUserId, limit: limit);
  }

  ChatMessage? getMessage(String otherUserId, String messageId) {
    return localSeenService.getMessage(otherUserId, messageId);
  }

  Future<({DocumentSnapshot? newCurrent, List<Chat> result})> getChats(
      String userId, {
        int limit = 10,
        DocumentSnapshot? offset,
      }) async {
    Query baseQuery = firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .orderBy('lastMessageAt', descending: true);

    if (offset != null) {
      baseQuery = baseQuery.startAfterDocument(offset);
    }

    final snapshot = await baseQuery.limit(limit).get();
    
    print("got chat snapshot with length ${snapshot.docs.length}, from cache: ${snapshot.metadata.isFromCache}");

    final result = snapshot.docs
        .map((e) => Chat.fromJson(e.data() as Map<String, dynamic>, customPartnerId: e.id))
        .toList();
    
    print("results: $result");

    return (result: result, newCurrent: snapshot.docs.lastOrNull);
  }
}

String getChatId({String? currentUserId, required String receiverId}) {
  currentUserId ??= currentUser.id;
  final ids = [currentUser.id, receiverId]..sort();
  return "${ids[0]}-${ids[1]}";
}
