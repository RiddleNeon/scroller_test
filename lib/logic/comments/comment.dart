
class Comment {
  /// Unique document ID – use the Firestore doc ID here.
  String id;
  String userId;
  String username;
  String userProfileImageUrl;
  String message;
  DateTime date;
  int likeCount;

  /// null  → top-level comment
  /// other → direct parent's id
  String? parentId;

  /// 0 = top-level, 1 = first reply level, etc.
  /// Stored in Firestore so you can query/order by depth if needed.
  int depth;

  /// Client-only – NOT stored in Firestore.
  /// Populated by [buildCommentTree] after loading a flat list.
  List<Comment> replies;

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
  }) : replies = replies ?? [];

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
      );
  
  @override
  String toString() => "Comment '$message' by $username ($userProfileImageUrl) with $likeCount likes, written at $date";
}