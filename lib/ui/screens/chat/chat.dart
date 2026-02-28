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
  List<Chat> chats = [
    Chat(partnerId: "gKp7WtS40RVFeFUXHoYZ76LfBo73", partnerProfileImageUrl: "https://res.cloudinary.com/dvw3vksqx/image/upload/v1772302017/gk8v7xns1n0j4yum11ty.png", partnerName: "JuSer"),
    Chat(partnerId: "MrROkFLyYpSqOuxwcePncM8Kk4B3", partnerProfileImageUrl: "https://res.cloudinary.com/dvw3vksqx/image/upload/v1772225146/jzrnlvckuyuojqiix37i.png", partnerName: "Julian")
  ];
}

ChatManager get chatManager => ChatManager();