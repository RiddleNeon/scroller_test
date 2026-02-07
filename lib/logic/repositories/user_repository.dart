import 'package:cloud_firestore/cloud_firestore.dart';

import '../entities/user.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User> getUser(String userId, {bool loadFollowers = false}) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
    UserModel model = UserModel.fromFirestore(doc);

    List<User> following = [];
    if (loadFollowers) {
      for (String followerId in model.followingIds) {
        following.add(await getUser(followerId, loadFollowers: false));
      }
    }
    
    return User(
      id: model.id,
      username: model.username,
      profileImageUrl: model.profileImageUrl,
      followingIds: model.followingIds,
      following: following,
      followersCount: model.followersCount,
      createdAt: model.createdAt,
      bio: model.bio,
    );
  }
  
  
  static const String noProfileImageUrl = "https://img.freepik.com/premium-psd/contact-icon-illustration-isolated_23-2151903357.jpg?semt=ais_hybrid&w=740&q=80";
  
  Future<User> createUser({
    required String id,
    required String username,
    String profileImageUrl = noProfileImageUrl,
    String bio = '',
  }) async {
    UserModel model = UserModel(
      id: id,
      username: username,
      profileImageUrl: profileImageUrl,
      bio: bio,
      followersCount: 0,
      followingIds: [],
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(id).set(model.toFirestore());

    return User(
      id: model.id,
      username: model.username,
      profileImageUrl: model.profileImageUrl,
      followingIds: model.followingIds,
      followersCount: model.followersCount,
      createdAt: model.createdAt,
      bio: model.bio,
    );
  }
  
  
  

  Stream<User> getFollowedUsers(User user) async* {
    List<String> followingIds = user.followingIds;
    const batchSize = 50;

    for (int i = 0; i < followingIds.length; i += batchSize) {
      int end = (i + batchSize < followingIds.length)
          ? i + batchSize
          : followingIds.length;

      List<String> batch = followingIds.sublist(i, end);

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (var doc in snapshot.docs) {
        UserModel model = UserModel.fromFirestore(doc);
        yield User(
          id: model.id,
          username: model.username,
          profileImageUrl: model.profileImageUrl,
          followingIds: model.followingIds,
          followersCount: model.followersCount,
          createdAt: model.createdAt,
          bio: model.bio,
        );
      }
    }
  }

  Future<void> followUser(String userId, String targetUserId) async {}
}
