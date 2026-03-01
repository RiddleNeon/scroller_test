import 'package:wurp/main.dart';

class Chat {
  String currentUserId;
  String partnerId;
  String partnerName;
  String partnerProfileImageUrl;
  DateTime? lastMessageAt;
  String lastMessage;
  
  Chat({String? currentUserReplacementId, required this.partnerId, required this.partnerProfileImageUrl, required this.partnerName, required this.lastMessage, required this.lastMessageAt}) : currentUserId = currentUserReplacementId ?? currentUser.id;
  
  Map<String, dynamic> toJson() => {
    'currentUserId': currentUserId,
    'partnerId': partnerId,
    'partnerName': partnerName,
    'partnerProfileImageUrl': partnerProfileImageUrl,
    'lastMessageAt': lastMessageAt?.millisecondsSinceEpoch ?? 0,
    'lastMessage': lastMessage,
  };
  
  factory Chat.fromJson(Map<dynamic, dynamic> json) {
    String currentUserId = json['currentUserId'] ?? currentUser.id;
    String partnerId = json['partnerId'];
    String partnerName = json['partnerName'];
    String partnerProfileImageUrl = json['partnerProfileImageUrl'];
    DateTime lastMessageAt = DateTime.fromMillisecondsSinceEpoch(json['lastMessageAt']);
    String lastMessage = json['lastMessage'];
    return Chat(partnerId: partnerId, partnerProfileImageUrl: partnerProfileImageUrl, partnerName: partnerName, currentUserReplacementId: currentUserId, lastMessage: lastMessage, lastMessageAt: lastMessageAt);
  }
}

class ChatManager {
  static ChatManager? _currentInstance;
  factory ChatManager(){
    if(_currentInstance?.userId != currentUser.id || _currentInstance == null) {
      _currentInstance = ChatManager._internal(currentUser.id);
    }
    return _currentInstance!;
  }
  ChatManager._internal(this.userId) : chats = localSeenService.getChats();
  String userId;
  List<Chat> chats;
  
  void addChat(Chat chat, {bool replaceExisting = true}){
    if(!chats.any((element) => element.partnerId == chat.partnerId)) {
      chats.add(chat);
    } else if(replaceExisting) {
      chats.remove(chat); 
      chats.add(chat);
    }
  }
  
}

ChatManager get chatManager => ChatManager();