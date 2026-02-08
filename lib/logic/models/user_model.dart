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

  factory UserProfile.fromFirestore(DocumentSnapshot doc, {bool includePublishedVideos = false, bool includeFollowingIds = false}) {
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
    );
  }

  Future<List<String>> getFollowingIds() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .collection('following')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Get user's published videos
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

  /// Get user's liked videos
  Future<List<Video>> getLikedVideos({int limit = 20}) async {
    try {
      // First get the liked video IDs
      final likedSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .collection('liked_videos')
          .orderBy('likedAt', descending: true)
          .limit(limit)
          .get();

      final videoIds = likedSnapshot.docs.map((doc) => doc.id).toList();

      if (videoIds.isEmpty) return [];

      // Fetch the actual videos
      final videos = <Video>[];
      for (final videoId in videoIds) {
        final videoDoc = await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .get();

        if (videoDoc.exists) {
          videos.add(Video.fromFirestore(videoDoc));
        }
      }

      return videos;
    } catch (e) {
      print('Error fetching liked videos: $e');
      return [];
    }
  }

  /// Get followers list
  Future<List<UserProfile>> getFollowers({int limit = 50}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .collection('followers')
          .limit(limit)
          .get();

      final followers = <UserProfile>[];
      for (final doc in snapshot.docs) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .get();

        if (userDoc.exists) {
          followers.add(UserProfile.fromFirestore(userDoc));
        }
      }

      return followers;
    } catch (e) {
      print('Error fetching followers: $e');
      return [];
    }
  }

  /// Get following list
  Future<List<UserProfile>> getFollowing({int limit = 50}) async {
    try {
      final followingIds = await getFollowingIds();
      final following = <UserProfile>[];

      for (final userId in followingIds.take(limit)) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          following.add(UserProfile.fromFirestore(userDoc));
        }
      }

      return following;
    } catch (e) {
      print('Error fetching following: $e');
      return [];
    }
  }

  /// Check if this user is followed by another user
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
  String toString() => 'UserProfile{id: $id, username: $username, profileImageUrl: $profileImageUrl, bio: $bio, createdAt: $createdAt, followersCount: $followersCount}';
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
    required this.publishedVideoIds,
  });

  /// Get published videos with full Video objects
  Future<List<Video>> getPublishedVideosDetailed() async {
    try {
      final videos = <Video>[];

      for (final videoId in publishedVideoIds) {
        final doc = await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .get();

        if (doc.exists) {
          videos.add(Video.fromFirestore(doc));
        }
      }

      return videos;
    } catch (e) {
      print('Error fetching published videos: $e');
      return [];
    }
  }
}