import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserProfile> getUser(String userId, {bool loadFollowers = false}) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
    UserProfile model = UserProfile.fromFirestore(doc);
    
    return model;
  }
  
  
  static const String noProfileImageUrl = "https://img.freepik.com/premium-psd/contact-icon-illustration-isolated_23-2151903357.jpg?semt=ais_hybrid&w=740&q=80";
  
  Future<UserProfile> createUser({
    required String id,
    required String username,
    String profileImageUrl = noProfileImageUrl,
    String bio = '',
  }) async {
    
    await _firestore.collection('users').doc(id).set({
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'followersCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return UserProfile(
      id: id,
      username: username,
      profileImageUrl: profileImageUrl,
      bio: bio,
      createdAt: DateTime.now(),
      followersCount: 0,
    );
  }

  Future<void> followUser(String userId, String targetUserId) async {
    DocumentReference userRef = _firestore.collection('users').doc(userId);
    DocumentReference targetUserRef = _firestore.collection('users').doc(targetUserId);
    DocumentReference followingRef = userRef.collection('following').doc(targetUserId);
    
    await _firestore.runTransaction((transaction) async {
      
      DocumentSnapshot userSnapshot = await transaction.get(userRef);
      DocumentSnapshot targetUserSnapshot = await transaction.get(targetUserRef);
      DocumentSnapshot followingSnapshot = await transaction.get(followingRef);
      
      if (!userSnapshot.exists || !targetUserSnapshot.exists) {
        print("one of the users does not exist");
        throw Exception("One of the users does not exist");
      }
      
      if (followingSnapshot.exists) {
        throw Exception("Already following this user");
      }
      
      int followersCount = targetUserSnapshot['followersCount'] ?? 0;
      
      transaction.update(targetUserRef, {
        'followersCount': followersCount + 1,
      });
    });
  }

  Future<void> unfollowUser(String userId, String targetUserId) async {
    DocumentReference userRef = _firestore.collection('users').doc(userId);
    DocumentReference targetUserRef = _firestore.collection('users').doc(targetUserId);
    DocumentReference followingRef = userRef.collection('following').doc(targetUserId);
    DocumentReference followerRef = targetUserRef.collection('followers').doc(userId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot userSnapshot = await transaction.get(userRef);
      DocumentSnapshot targetUserSnapshot = await transaction.get(targetUserRef);
      DocumentSnapshot followingSnapshot = await transaction.get(followingRef);

      if (!userSnapshot.exists || !targetUserSnapshot.exists) {
        print("one of the users does not exist");
        throw Exception("One of the users does not exist");
      }

      if (!followingSnapshot.exists) {
        print("not following this user");
        throw Exception("Not following this user");
      }

      int targetFollowersCount = targetUserSnapshot['followersCount'] ?? 0;

      print("targetFollowersCount: $targetFollowersCount");
      transaction.delete(followingRef);
      transaction.delete(followerRef);

      transaction.update(targetUserRef, {
        'followersCount': targetFollowersCount > 0 ? targetFollowersCount - 1 : 0,
      });
    });
  }
}
