import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toSupabase({
    required int conversationId,
    required String senderId,
    int? replyToMessageId,
  }) => {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': text,
        'type': 'text',
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      };

  ChatMessage.fromFirestore(Map<String, dynamic> doc, String id, bool isA)
      : id = id,
        text = doc['message'] ?? '',
        timestamp = (doc['createdAt'] as dynamic).toDate() as DateTime,
        isMe = doc['isA'] == isA,
        status = MessageStatus.delivered;

  ChatMessage.fromSupabase(Map<String, dynamic> doc, {required String currentUserId})
      : id = '${doc['id']}',
        text = doc['content'] as String? ?? '',
        timestamp = _parseDateTime(doc['created_at']),
        isMe = doc['sender_id'] == currentUserId,
        status = MessageStatus.delivered;

}

enum MessageStatus { sending, sent, delivered, read }

DateTime _parseDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value == null) return DateTime.now();
  throw FormatException('Unsupported chat message timestamp type: ${value.runtimeType}');
}
