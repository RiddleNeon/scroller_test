class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  MessageStatus status;


  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });

  Map<String, dynamic> toFirestore(bool isA) =>
      {
        'message': text,
        'isA': isA,
        'createdAt': timestamp,
      };

  ChatMessage.fromFirestore(Map<String, dynamic> doc, String id, bool isA)
      : id = id,
        text = doc['message'] ?? '',
        timestamp = (doc['createdAt'] as dynamic).toDate() as DateTime,
        isMe = doc['isA'] == isA,
        status = MessageStatus.delivered;

}

enum MessageStatus { sending, sent, delivered, read }