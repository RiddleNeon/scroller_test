import 'package:wurp/main.dart';

class Chat {
  String currentUserId;
  String partnerId;
  String partnerName;
  String partnerProfileImageUrl;
  
  Chat({String? currentUserReplacementId, required this.partnerId, required this.partnerProfileImageUrl, required this.partnerName}) : currentUserId = currentUserReplacementId ?? currentUser.id;
}

class ChatManager {
  static ChatManager? _currentInstance;
  factory ChatManager(){
    if(_currentInstance?.userId != currentUser.id || _currentInstance == null) {
      _currentInstance = ChatManager._internal(currentUser.id);
    }
    return _currentInstance!;
  }
  ChatManager._internal(this.userId);
  String userId;
  List<Chat> chats = [];
  
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