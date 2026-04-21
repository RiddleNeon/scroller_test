class ChatMessage {
  final String id;
  final String? replyToMessageId;
  final String type;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  MessageStatus status;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.replyToMessageId,
    this.type = 'text',
    this.editedAt,
    this.deletedAt,
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
      type = doc['type'] ?? 'text',
      editedAt = doc['edited_at'] == null ? null : _parseDateTime(doc['edited_at']),
      deletedAt = doc['deleted_at'] == null ? null : _parseDateTime(doc['deleted_at']);

  bool get isEdited => editedAt != null;
}

class MessageVersion {
  final int id;
  final String messageId;
  final int versionNo;
  final String content;
  final DateTime editedAt;
  final String? editedBy;
  final String changeType;

  const MessageVersion({
    required this.id,
    required this.messageId,
    required this.versionNo,
    required this.content,
    required this.editedAt,
    required this.changeType,
    this.editedBy,
  });

  factory MessageVersion.fromSupabase(Map<String, dynamic> row) {
    return MessageVersion(
      id: row['id'] as int,
      messageId: row['message_id'].toString(),
      versionNo: (row['version_no'] as num).toInt(),
      content: row['content'] as String? ?? '',
      editedAt: _parseDateTime(row['edited_at']),
      editedBy: row['edited_by'] as String?,
      changeType: row['change_type'] as String? ?? 'edit',
    );
  }
}

enum MessageStatus { sending, sent, delivered, read }

DateTime _parseDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  if (value == null) return DateTime.now();
  throw FormatException('Unsupported chat message timestamp type: ${value.runtimeType}');
}
