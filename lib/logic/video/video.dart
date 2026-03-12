import '../../base_logic.dart';
import '../../tools/supabase_tests/supabase_login_test.dart';
import '../models/user_model.dart';

class Video {
  final String id;
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

  factory Video.fromSupabase(Map<String, dynamic> data, String authorName, List<String> tags) {
    final durationMs = data['duration_ms'] as int?;
    return Video(
      id: data['id'].toString(),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoUrl: (data['video_url'] ?? '').toString().replaceAll("_large.", "_tiny.").replaceAll("_medium.", "_tiny.").replaceAll("_small.", "_tiny."),
      thumbnailUrl: data['thumbnail_url'] as String?,
      authorId: data['author_id'] ?? '',
      createdAt: DateTime.parse(data['created_at'] as String).toLocal(),
      likesCount: data['like_count'] as int?,
      viewsCount: data['view_count'] as int?,
      tags: tags,
      commentsCount: data['comment_count'] as int?,
      authorName: authorName,
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
    );
  }

  Future<UserProfile?> getAuthorProfile() async {
    try {
      return await userRepository.getUserSupabase(authorId);
    } catch (e) {
      print('Error fetching author profile: $e');
      return null;
    }
  }

  Future<bool> isLikedByUser(String userId) async {
    try {
      return (await supabaseClient.from('likes').select().eq('user_id', userId).eq('video_id', int.parse(id)).maybeSingle()) != null;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  Future<bool> isDislikedByUser(String userId) async {
    try {
      return (await supabaseClient.from('dislikes').select().eq('user_id', userId).eq('video_id', int.parse(id)).maybeSingle()) != null;
    } catch (e) {
      print('Error checking dislike status: $e');
      return false;
    }
  }

  Future<bool> isAuthorFollowedByUser(String userId) async {
    try {
      return userRepository.isFollowingSupabase(userId, authorId);
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  double get engagementRate {
    if (viewsCount == null || viewsCount == 0) return 0.0;
    final totalEngagements = (likesCount ?? 0) + (commentsCount ?? 0);
    return (totalEngagements / viewsCount!) * 100;
  }

  @override
  String toString() => 'Video{id: $id, title: $title, authorId: $authorId, author: $authorName, tags: $tags}';
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
    final profiles = await supabaseClient.from('profiles').select().inFilter('id', authorIds);
    return Map.fromEntries(
      profiles.map((profile) {
        final user = UserProfile.fromSupabase(profile);
        return MapEntry(user.id, user);
      }),
    );
  }
}
