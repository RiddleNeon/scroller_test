import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String username;
  final String profileImageUrl;
  final String bio;
  final int followersCount;
  final List<String> followingIds;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.profileImageUrl,
    required this.bio,
    required this.followersCount,
    required this.followingIds,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      username: data['username'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      bio: data['bio'] ?? '',
      followersCount: data['followersCount'] ?? 0,
      followingIds: data['followingIds'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'followersCount': followersCount,
      'followingIds': followingIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}