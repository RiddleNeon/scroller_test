import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String username;
  final String profileImageUrl;
  final String bio;
  final DateTime createdAt;
  final int followersCount;

  const UserProfile({
    required this.id,
    required this.username,
    required this.profileImageUrl,
    required this.bio,
    required this.createdAt,
    required this.followersCount,
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
    );
  }

  Future<List<String>> getFollowingIds() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(id).collection('following').get();
    return snapshot.docs.map((doc) => doc.id).toList();
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
    required this.publishedVideoIds,
  });
}
