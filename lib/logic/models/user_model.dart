import 'package:cloud_firestore/cloud_firestore.dart';
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
  final int? totalDislikesCount;
  final bool usesCustomProfileImage;

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
    this.totalDislikesCount, 
    required this.usesCustomProfileImage,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      id: doc.id,
      username: data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      bio: data['bio'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'],
      totalVideosCount: data['totalVideosCount'],
      totalLikesCount: data['totalLikesCount'],
      totalDislikesCount: data['totalDislikesCount'],
      usesCustomProfileImage: data['usesCustomProfileImage'] ?? false,
    );
  }
  
  
  UserProfile copyWith({
    String? username,
    String? profileImageUrl,
    String? bio,
    int? followersCount,
    bool? usesCustomProfileImage,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      totalVideosCount: totalVideosCount,
      totalLikesCount: totalLikesCount,
      totalDislikesCount: totalDislikesCount,
      usesCustomProfileImage: usesCustomProfileImage ?? this.usesCustomProfileImage,
    );
  }
  

  @override
  String toString() =>
      'UserProfile{id: $id, username: $username, profileImageUrl: $profileImageUrl ${usesCustomProfileImage ? "(custom)" : "(inherited from account)"}, bio: $bio, createdAt: $createdAt, followersCount: $followersCount}';
}

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
    super.totalDislikesCount,
    required this.publishedVideoIds, 
    required super.usesCustomProfileImage,
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