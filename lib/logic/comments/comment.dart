
class Comment {
  String id;
  String userId;
  String username;
  String userProfileImageUrl;
  String message;
  DateTime date;
  int likeCount;
  bool likedByCurrentUser;
  int? replyCount;

  /// null  → top-level comment
  /// other → direct parent's id
  String? parentId;

  /// 0 = top-level, 1 = first reply level, etc.
  int depth;

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
    this.likedByCurrentUser = false,
  }) : _replies = replies ?? [];

  factory Comment.fromSupabase(Map<String, dynamic> data, {bool? likedByMe}) {
    print("liked by me: ${likedByMe ?? (data['liked_by_current_user'] as bool?)}");
    return Comment(
      id: data['id'].toString(),
      userId: data['author_id'] as String,
      username: data['profiles']['username'] as String,
      userProfileImageUrl: data['profiles']['avatar_url'] as String? ?? '',
      message: data['content'] as String,
      date: DateTime.parse(data['created_at']).toLocal(),
      likeCount: int.tryParse(data['like_count']?.toString() ?? '0') ?? 0,
      parentId: data['parent_id']?.toString(),
      depth: data['parent_id'] != null ? 1 : 0,
      replyCount: data['reply_count'] as int? ?? 0,
      likedByCurrentUser: likedByMe ?? (data['liked_by_current_user'] as bool?) ?? false,
    );
  }
  
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
