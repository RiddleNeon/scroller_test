import 'package:cloud_firestore/cloud_firestore.dart';
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
    );
  }
  
  static Future<List<UserProfile>> _fetchProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final profiles = <UserProfile>[];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      profiles.addAll(snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)));
    }
    return profiles;
  }

  static Future<List<Video>> _fetchVideosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final videos = <Video>[];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      videos.addAll(snapshot.docs.map((doc) => Video.fromFirestore(doc)));
    }
    return videos;
  }
  
  
  Future<List<String>> getFollowingIds() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .collection('following')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<List<Video>> getPublishedVideos({int limit = 20}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('authorId', isEqualTo: id)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching published videos: $e');
      return [];
    }
  }

  Future<List<Video>> getLikedVideos({int limit = 20}) async {
    try {
      final likedSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .collection('liked_videos')
          .orderBy('likedAt', descending: true)
          .limit(limit)
          .get();

      final videoIds = likedSnapshot.docs.map((doc) => doc.id).toList();
      return _fetchVideosByIds(videoIds);
    } catch (e) {
      print('Error fetching liked videos: $e');
      return [];
    }
  }

  Future<List<Video>> getDislikedVideos({int limit = 20}) async {
    try {
      final dislikedSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .collection('disliked_videos')
          .orderBy('dislikedAt', descending: true)
          .limit(limit)
          .get();

      final videoIds = dislikedSnapshot.docs.map((doc) => doc.id).toList();
      return _fetchVideosByIds(videoIds);
    } catch (e) {
      print('Error fetching disliked videos: $e');
      return [];
    }
  }

  Future<List<UserProfile>> getFollowers({int limit = 50}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .collection('followers')
          .limit(limit)
          .get();

      final followerIds = snapshot.docs.map((doc) => doc.id).toList();
      return _fetchProfilesByIds(followerIds);
    } catch (e) {
      print('Error fetching followers: $e');
      return [];
    }
  }

  Future<List<UserProfile>> getFollowing({int limit = 50}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .collection('following')
          .limit(limit)
          .get();

      final followingIds = snapshot.docs.map((doc) => doc.id).toList();
      return _fetchProfilesByIds(followingIds);
    } catch (e) {
      print('Error fetching following: $e');
      return [];
    }
  }

  Future<bool> isFollowedBy(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('following')
          .doc(id)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  @override
  String toString() =>
      'UserProfile{id: $id, username: $username, profileImageUrl: $profileImageUrl, bio: $bio, createdAt: $createdAt, followersCount: $followersCount}';
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
  });

  Future<List<Video>> getPublishedVideosDetailed() async {
    try {
      return UserProfile._fetchVideosByIds(publishedVideoIds);
    } catch (e) {
      print('Error fetching published videos: $e');
      return [];
    }
  }
}