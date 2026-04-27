import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video.dart';

class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String profileImageUrl;
  final String bio;
  final DateTime createdAt;
  final int followersCount;
  final int? followingCount;
  final int? totalVideosCount;
  final int? totalLikesCount;
  final bool acceptedEula;
  final bool acceptedDataProcessing;
  final bool onboardingCompleted;

  final bool isBot;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.profileImageUrl,
    required this.bio,
    required this.createdAt,
    required this.followersCount,
    this.followingCount,
    this.totalVideosCount,
    this.totalLikesCount,
    this.acceptedEula = false,
    this.acceptedDataProcessing = false,
    this.onboardingCompleted = false,
    this.isBot = false,
  });

  factory UserProfile.fromSupabase(Map<String, dynamic> data) {
    return UserProfile(
      id: data['id'],
      username: data['username'] ?? '',
      displayName: data['display_name'] ?? data['username'] ?? '',
      profileImageUrl: data['avatar_url'] ?? data['profileImageUrl'] ?? createUserProfileImageUrl(_avatarSeed(data)),
      bio: data['bio'] ?? '',
      createdAt: _parseDateTime(data['created_at'] ?? data['createdAt']),
      followersCount: data['followers_count'] ?? data['followersCount'] ?? 0,
      followingCount: data['following_count'] ?? data['followingCount'],
      totalVideosCount: data['total_videos_count'] ?? data['totalVideosCount'],
      totalLikesCount: data['total_likes_count'] ?? data['totalLikesCount'],
      acceptedEula: data['accepted_eula'] ?? data['acceptedEula'] ?? false,
      acceptedDataProcessing: data['accepted_data_processing'] ?? data['acceptedDataProcessing'] ?? false,
      onboardingCompleted: data['onboarding_completed'] ?? data['onboardingCompleted'] ?? false,
      isBot: data['is_bot'] ?? data['isBot'] ?? false,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> data) {
    return UserProfile(
      id: data['id'],
      username: data['username'] ?? '',
      displayName: data['display_name'] ?? data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? data['avatar_url'] ?? createUserProfileImageUrl(_avatarSeed(data)),
      bio: data['bio'] ?? '',
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
      followersCount: data['followersCount'] ?? data['followers_count'] ?? 0,
      followingCount: data['followingCount'] ?? data['following_count'],
      totalVideosCount: data['totalVideosCount'] ?? data['total_videos_count'],
      totalLikesCount: data['totalLikesCount'] ?? data['total_likes_count'],
      acceptedEula: data['acceptedEula'] ?? data['accepted_eula'] ?? false,
      acceptedDataProcessing: data['acceptedDataProcessing'] ?? data['accepted_data_processing'] ?? false,
      onboardingCompleted: data['onboardingCompleted'] ?? data['onboarding_completed'] ?? false,
      isBot: data['isBot'] ?? data['is_bot'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "username": username,
      "displayName": displayName,
      "profileImageUrl": profileImageUrl,
      "bio": bio,
      "createdAt": createdAt,
      "followersCount": followersCount,
      "followingCount": followingCount,
      "totalVideosCount": totalVideosCount,
      "totalLikesCount": totalLikesCount,
      "acceptedEula": acceptedEula,
      "acceptedDataProcessing": acceptedDataProcessing,
      "onboardingCompleted": onboardingCompleted,
      "isBot": isBot,
    };
  }

  UserProfile copyWith({
    String? username,
    String? displayName,
    String? profileImageUrl,
    String? bio,
    int? followersCount,
    int? followingCount,
    int? totalVideosCount,
    int? totalLikesCount,
    bool? acceptedEula,
    bool? acceptedDataProcessing,
    bool? onboardingCompleted,
    bool? isBot,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      totalVideosCount: totalVideosCount ?? this.totalVideosCount,
      totalLikesCount: totalLikesCount ?? this.totalLikesCount,
      acceptedEula: acceptedEula ?? this.acceptedEula,
      acceptedDataProcessing: acceptedDataProcessing ?? this.acceptedDataProcessing,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isBot: isBot ?? this.isBot,
    );
  }

  bool get hasAcceptedRequiredAgreements => acceptedEula && acceptedDataProcessing;

  @override
  String toString() =>
      'UserProfile{id: $id, username: $username, displayName: $displayName, profileImageUrl: $profileImageUrl, bio: $bio, createdAt: $createdAt, followersCount: $followersCount, followingCount: $followingCount, totalVideosCount: $totalVideosCount, totalLikesCount: $totalLikesCount, acceptedEula: $acceptedEula, acceptedDataProcessing: $acceptedDataProcessing, onboardingCompleted: $onboardingCompleted, isBot: $isBot}';
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
    required super.displayName,
    required super.profileImageUrl,
    required super.bio,
    required super.createdAt,
    required super.followersCount,
    super.followingCount,
    super.totalVideosCount,
    super.totalLikesCount,
    super.acceptedEula,
    super.acceptedDataProcessing,
    super.onboardingCompleted,
    super.isBot,
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
