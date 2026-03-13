class ChatMessage {
  final String id;
  final String? replyToMessageId;
  final String type;
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
    this.replyToMessageId,
    this.type = 'text',
  });

  Map<String, dynamic> toSupabase({required int conversationId, required String senderId}) => {
    'conversation_id': conversationId,
    'sender_id': senderId,
    'content': text,
    'type': type,
    if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
  };

  ChatMessage.fromSupabase(Map<String, dynamic> doc, {required String currentUserId})
    : id = '${doc['id']}',
      text = doc['content'] as String? ?? '',
      timestamp = _parseDateTime(doc['created_at']),
      isMe = doc['sender_id'] == currentUserId,
      status = MessageStatus.delivered,
      replyToMessageId = doc['reply_to_message_id']?.toString(),
      type = doc['type'] ?? 'text';
}

enum MessageStatus { sending, sent, delivered, read }

DateTime _parseDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value == null) return DateTime.now();
  throw FormatException('Unsupported chat message timestamp type: ${value.runtimeType}');
}
