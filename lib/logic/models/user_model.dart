import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video.dart';

class UserProfile {
  final String id;
  final String username;
  final String profileImageUrl;
  final String bio;
  final DateTime createdAt;
  final int followersCount;
  final int? followingCount;
  final int? totalVideosCount;
  final int? totalLikesCount;

  const UserProfile({
    required this.id,
    required this.username,
    required this.profileImageUrl,
    required this.bio,
    required this.createdAt,
    required this.followersCount,
    this.followingCount,
    this.totalVideosCount,
    this.totalLikesCount,
  });

  factory UserProfile.fromSupabase(Map<String, dynamic> data) {
    
    return UserProfile(
      id: data['id'],
      username: data['display_name'] ?? data['username'] ?? '',
      profileImageUrl: data['avatar_url'] ?? data['profileImageUrl'] ?? createUserProfileImageUrl(_avatarSeed(data)),
      bio: data['bio'] ?? '',
      createdAt: _parseDateTime(data['created_at'] ?? data['createdAt']),
      followersCount: data['followers_count'] ?? data['followersCount'] ?? 0,
      followingCount: data['following_count'] ?? data['followingCount'],
      totalVideosCount: data['total_videos_count'] ?? data['totalVideosCount'],
      totalLikesCount: data['total_likes_count'] ?? data['totalLikesCount'],
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> data) {
    return UserProfile(
      id: data['id'],
      username: data['display_name'] ?? data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? data['avatar_url'] ?? createUserProfileImageUrl(_avatarSeed(data)),
      bio: data['bio'] ?? '',
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
      followersCount: data['followersCount'] ?? data['followers_count'] ?? 0,
      followingCount: data['followingCount'] ?? data['following_count'],
      totalVideosCount: data['totalVideosCount'] ?? data['total_videos_count'],
      totalLikesCount: data['totalLikesCount'] ?? data['total_likes_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "username": username,
      "profileImageUrl": profileImageUrl,
      "bio": bio,
      "createdAt": createdAt,
      "followersCount": followersCount,
      "followingCount": followingCount,
      "totalVideosCount": totalVideosCount,
      "totalLikesCount": totalLikesCount,
    };
  }

  UserProfile copyWith({String? username, String? profileImageUrl, String? bio, int? followersCount, int? followingCount, int? totalVideosCount, int? totalLikesCount}) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      totalVideosCount: totalVideosCount ?? this.totalVideosCount,
      totalLikesCount: totalLikesCount ?? this.totalLikesCount,
    );
  }

  @override
  String toString() =>
      'UserProfile{id: $id, username: $username, profileImageUrl: $profileImageUrl, bio: $bio, createdAt: $createdAt, followersCount: $followersCount}';
}

DateTime _parseDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value);
  return DateTime.now();
}

String? _avatarSeed(Map<String, dynamic> data) => data['display_name'] ?? data['username'] ?? data['id']?.toString();

class CreatorUserProfile extends UserProfile {
  final List<String> publishedVideoIds;

  const CreatorUserProfile({
    required super.id,
    required super.username,
    required super.profileImageUrl,
    required super.bio,
    required super.createdAt,
    required super.followersCount,
    super.followingCount,
    super.totalVideosCount,
    super.totalLikesCount,
    required this.publishedVideoIds,
  });

  Future<List<Video>> getPublishedVideosDetailed() async {
    try {
      return videoRepo.fetchVideosByIds(publishedVideoIds);
    } catch (e) {
      print('Error fetching published videos: $e');
      return [];
    }
  }
}
