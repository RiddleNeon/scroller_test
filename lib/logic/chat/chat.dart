import 'package:cloud_firestore/cloud_firestore.dart';

import '../../base_logic.dart';
import '../local_storage/local_seen_service.dart';
import '../models/user_model.dart';

class Chat {
  int? conversationId;
  DateTime createdAt;
  String currentUserId;
  String partnerId;
  String partnerName;
  String partnerProfileImageUrl;
  DateTime? lastMessageAt;
  String lastMessage;
  bool lastMessageByMe;

  Chat({
    this.conversationId,
    String? currentUserReplacementId,
    required this.partnerId,
    required this.partnerProfileImageUrl,
    required this.partnerName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageByMe,
    required this.createdAt,
  }) : currentUserId = currentUserReplacementId ?? currentUser.id;

  Map<String, dynamic> toJson() => {
    'conversationId': conversationId,
    'currentUserId': currentUserId,
    'partnerId': partnerId,
    'partnerName': partnerName,
    'partnerProfileImageUrl': partnerProfileImageUrl,
    'lastMessageAt': lastMessageAt,
    'lastMessage': lastMessage,
    'lastMessageByMe': lastMessageByMe,
    'createdAt': createdAt,
  };

  factory Chat.fromJson(Map<dynamic, dynamic> json, {String? customPartnerId}) {
    String currentUserId = json['currentUserId'] ?? currentUser.id;
    String partnerId = json['partnerId'] ?? customPartnerId ?? '';
    String partnerName = json['partnerName'];
    String partnerProfileImageUrl = json['partnerProfileImageUrl'];
    print("now the last message date: ${json['lastMessageAt']}");
    DateTime? lastMessageAt;
    if(json['lastMessageAt'] is Timestamp){
      print("cast to timestamp");
      print("test: ${(json['lastMessageAt'] as Timestamp)}");
      lastMessageAt = (json['lastMessageAt'] as Timestamp).toDate();
      print("done!");
    } else {
      lastMessageAt = (json['lastMessageAt'] as DateTime?);
    }
    print("DONE");
    String lastMessage = json['lastMessage'];
    bool lastMessageByMe = json['lastMessageByMe'] ?? true;
    print("is by me: $lastMessageByMe");
    DateTime createdAt;
    if(json['createdAt'] is Timestamp){
      print("cast to timestamp");
      print("test: ${(json['createdAt'] as Timestamp)}");
      createdAt = (json['createdAt'] as Timestamp).toDate();
      print("done!");
    } else {
      createdAt = (json['createdAt'] as DateTime);
    }
    print("everything else too");
    return Chat(
      conversationId: json['conversationId'] as int?,
      partnerId: partnerId,
      partnerProfileImageUrl: partnerProfileImageUrl,
      partnerName: partnerName,
      currentUserReplacementId: currentUserId,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      lastMessageByMe: lastMessageByMe,
      createdAt: createdAt,
    );
  }

  factory Chat.fromSupabase({
    required Map<String, dynamic> conversation,
    required UserProfile partner,
    required String currentUserId,
    Map<String, dynamic>? lastMessage,
  }) {
    final createdAtValue = conversation['created_at'];
    final updatedAtValue = conversation['updated_at'];
    final createdAt = _parseDateTime(createdAtValue);
    final lastMessageAt = lastMessage != null
        ? _parseDateTime(lastMessage['created_at'])
        : (updatedAtValue != null ? _parseDateTime(updatedAtValue) : null);

    return Chat(
      conversationId: conversation['id'] as int?,
      currentUserReplacementId: currentUserId,
      partnerId: partner.id,
      partnerProfileImageUrl: partner.profileImageUrl,
      partnerName: partner.username,
      lastMessage: lastMessage?['content'] as String? ?? '',
      lastMessageAt: lastMessageAt,
      lastMessageByMe: lastMessage?['sender_id'] == currentUserId,
      createdAt: createdAt,
    );
  }
}

class ChatManager {
  static ChatManager? _currentInstance;

  factory ChatManager() {
    if (_currentInstance?.userId != currentUser.id || _currentInstance == null) {
      _currentInstance = ChatManager._internal(currentUser.id);
    }
    return _currentInstance!;
  }

  ChatManager._internal(this.userId) : chats = localSeenService.getChats();
  String userId;
  List<Chat> chats;

  void addChat(Chat chat, {bool replaceExisting = true}) {
    if (!chats.any((element) => element.partnerId == chat.partnerId)) {
      chats.add(chat);
    } else if (replaceExisting) {
      chats.remove(chat);
      chats.add(chat);
    }
  }
}

ChatManager get chatManager => ChatManager();

DateTime _parseDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  return DateTime.now();
}
