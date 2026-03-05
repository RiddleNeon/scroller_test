import 'package:cloud_firestore/cloud_firestore.dart';

import '../../base_logic.dart';
import '../models/user_model.dart';

class Video {
  final String id; // Added video ID
  final String title;
  final String description;
  final String videoUrl;
  final String? thumbnailUrl;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final List<String> tags;
  final Duration? duration;

  final int? likesCount;
  final int? commentsCount;
  final int? viewsCount;

  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.authorId,
    required this.createdAt,
    required this.tags,
    this.likesCount,
    this.commentsCount,
    this.viewsCount,
    required this.authorName,
    this.duration,
  });

  factory Video.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Video(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoUrl: (data['videoUrl'] ?? '').toString().replaceAll("_large.", "_tiny.").replaceAll("_medium.", "_tiny.").replaceAll("_small.", "_tiny."),
      thumbnailUrl: data['thumbnailUrl'],
      authorId: data['authorId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      tags: data['tags'] != null ? List<String>.from(data['tags']) : [],
      likesCount: data['likesCount'],
      commentsCount: data['commentsCount'],
      viewsCount: data['viewsCount'],
      authorName: data['authorName'] ?? "No Name Provided",
    );
  }

  factory Video.fromSupabase(Map<String, dynamic> data, String authorName, List<String> tags) {
    return Video(
      id: data['id'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoUrl: (data['videoUrl'] ?? '').toString().replaceAll("_large.", "_tiny.").replaceAll("_medium.", "_tiny.").replaceAll("_small.", "_tiny."), //fixme only tmp solution
      thumbnailUrl: data['thumbnail_url'],
      authorId: data['author_id'] ?? '',
      createdAt: DateTime.parse(data['created_at']).toLocal(),
      likesCount: data['like_count'],
      viewsCount: data['view_count'],
      tags: tags,
      commentsCount: data['comment_count'],
      authorName: authorName,
      duration: Duration(milliseconds: data['duration_ms'])
    );
  }

  /// Get the author's profile
  Future<UserProfile?> getAuthorProfile() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(authorId).get();

      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching author profile: $e');
      return null;
    }
  }

  /// Check if a user has liked this video
  Future<bool> isLikedByUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('videos').doc(id).collection('likes').doc(userId).get();

      return doc.exists;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  /// Check if a user has disliked this video
  Future<bool> isDislikedByUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('videos').doc(id).collection('dislikes').doc(userId).get();

      return doc.exists;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  /// Check if a user is following the video author
  Future<bool> isAuthorFollowedByUser(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).collection('following').doc(authorId).get();

      return doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  /// Get engagement rate (percentage of viewers who engaged)
  double get engagementRate {
    if (viewsCount == null || viewsCount == 0) return 0.0;

    final totalEngagements = (likesCount ?? 0) + (commentsCount ?? 0);

    return (totalEngagements / viewsCount!) * 100;
  }

  @override
  String toString() => 'Video{id: $id, title: $title, authorId: $authorId, tags: $tags}';
}

class VideoWithAuthor {
  final Video video;
  final UserProfile author;
  final bool isLiked;
  final bool isAuthorFollowed;

  VideoWithAuthor({required this.video, required this.author, this.isLiked = false, this.isAuthorFollowed = false});

  static Future<VideoWithAuthor?> fromVideo(Video video, String currentUserId) async {
    final author = await video.getAuthorProfile();
    if (author == null) return null;

    final isLiked = await video.isLikedByUser(currentUserId);
    final isFollowed = await video.isAuthorFollowedByUser(currentUserId);

    return VideoWithAuthor(video: video, author: author, isLiked: isLiked, isAuthorFollowed: isFollowed);
  }

  static Future<Map<String, UserProfile>> fetchAuthorProfiles(List<Video> videos) async {
    final authorIds = videos.map((v) => v.authorId).toSet().toList();

    final snapshot = await firestore.collection('users').where(FieldPath.documentId, whereIn: authorIds).get();

    return Map.fromEntries(snapshot.docs.map((doc) => MapEntry(doc.id, UserProfile.fromFirestore(doc))));
  }
}
