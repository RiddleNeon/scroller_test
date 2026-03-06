
class Comment {
  /// Unique document ID – use the Firestore doc ID here.
  String id;
  String userId;
  String username;
  String userProfileImageUrl;
  String message;
  DateTime date;
  int likeCount;
  int? replyCount;

  /// null  → top-level comment
  /// other → direct parent's id
  String? parentId;

  /// 0 = top-level, 1 = first reply level, etc.
  /// Stored in Firestore so you can query/order by depth if needed.
  int depth;

  /// Client-only – NOT stored in Firestore.
  /// Populated by [buildCommentTree] after loading a flat list.
  List<Comment> _replies;

  Comment({
    required this.id,
    required this.userId,
    required this.message,
    required this.date,
    required this.username,
    required this.userProfileImageUrl,
    this.likeCount = 0,
    this.parentId,
    this.depth = 0,
    List<Comment>? replies,
    required this.replyCount,
  }) : _replies = replies ?? [];

  // ── Firestore helpers ────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'username': username,
    'userProfileImageUrl': userProfileImageUrl,
    'message': message,
    'date': date,
    'likeCount': likeCount,
    'parentId': parentId,
    'depth': depth,
    'replyCount': replyCount,
    // replies is client-only – never written to Firestore
  };

  factory Comment.fromFirestore(String docId, Map<String, dynamic> data) =>
      Comment(
        id: docId,
        userId: data['userId'] as String,
        username: data['username'] as String,
        userProfileImageUrl: data['userProfileImageUrl'] as String,
        message: data['message'] as String,
        // Firestore Timestamps need .toDate(); cast via dynamic to avoid
        // importing firebase_core here.
        date: (data['date'] as dynamic).toDate() as DateTime,
        likeCount: (data['likeCount'] as int?) ?? 0,
        parentId: data['parentId'] as String?,
        depth: (data['depth'] as int?) ?? 0,
        replyCount: (data['replyCount'] as int?) ?? 0,
      );

  factory Comment.fromSupabase(Map<String, dynamic> data) => Comment(
    id: data['id'].toString(),
    userId: data['author_id'] as String,
    username: data['profiles']['username'] as String,
    userProfileImageUrl: data['profiles']['avatar_url'] as String? ?? '',
    message: data['content'] as String,
    date: DateTime.parse(data['created_at']).toLocal(),
    likeCount: 0, //todo
    parentId: data['parent_id']?.toString(),
    depth: data['parent_id'] != null ? 1 : 0,
    replyCount: data['reply_count'] as int? ?? 0,
  );
  
  void addReply(Comment reply) {
    _replies.add(reply);
    replyCount ??= _replies.length;
    replyCount = (replyCount ?? _replies.length) + 1;
  }

  void addReplies(List<Comment> replies) {
    _replies.addAll(replies);
    replyCount = (replyCount ?? _replies.length) + 1;
  }
  
  List<Comment> getReplies(){
    return _replies;
  }
  
  @override
  String toString() => "Comment '$message' by $username ($userProfileImageUrl) with $likeCount likes, written at $date";
}