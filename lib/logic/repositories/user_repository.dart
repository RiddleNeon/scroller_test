import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/logic/repositories/video_repository.dart';

import '../../main.dart';
import '../models/user_model.dart';
import '../video/video.dart';

class UserRepository {
  Future<UserProfile> getUser(String userId) async {
    print("getting user $userId");
    DocumentSnapshot doc = await firestore.collection('users').doc(userId).get();
    print("got doc: ${doc.data()}");
    UserProfile model = UserProfile.fromFirestore(doc);

    return model;
  }

  Future<UserProfile> getOrCreateUser(String userId) async {
    print("getting user $userId");
    DocumentSnapshot doc = await firestore.collection('users').doc(userId).get();
    print("got doc: ${doc.data()}");

    if (doc.exists) {
      UserProfile model = UserProfile.fromFirestore(doc);
      return model;
    } else {
      UserProfile model =
          await createUser(id: userId, username: auth!.currentUser!.displayName ?? auth!.currentUser!.email?.split("@").first ?? auth!.currentUser!.uid);
      return model;
    }
  }

  Future<UserProfile> createUser({
    required String id,
    required String username,
    String? profileImageUrl,
    String bio = '',
  }) async {
    await firestore.collection('users').doc(id).set({
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'followersCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return UserProfile(
      id: id,
      username: username,
      profileImageUrl: profileImageUrl ?? createUserProfileImageUrl(username),
      bio: bio,
      createdAt: DateTime.now(),
      followersCount: 0,
      usesCustomProfileImage: false,
    );
  }

  /*Future<void> followUser(String userId, String targetUserId) async {
    DocumentReference userRef = firestore.collection('users').doc(userId);
    DocumentReference targetUserRef = firestore.collection('users').doc(targetUserId);
    DocumentReference followingRef = userRef.collection('following').doc(targetUserId);

    await firestore.runTransaction((transaction) async {
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
    DocumentReference userRef = firestore.collection('users').doc(userId);
    DocumentReference targetUserRef = firestore.collection('users').doc(targetUserId);
    DocumentReference followingRef = userRef.collection('following').doc(targetUserId);
    DocumentReference followerRef = targetUserRef.collection('followers').doc(userId);

    await firestore.runTransaction((transaction) async {
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
  }*/
  
  ///returns if the user is followed after the operation
  Future<bool> toggleFollowUser(String currentId, String followingId) async {
    if (currentId == followingId) throw Exception('Cannot toggle follow yourself');

    bool following = await isFollowing(currentId, followingId);
    
    if(following){
      _unfollowUser(currentId, followingId);
      return false;
    } else {
      _followUser(currentId, followingId);
      return true;
    }
  }
  

  /// Follow a user
  Future<void> followUser(String currentId, String followingId) async {
    if (currentId == followingId) throw Exception('Cannot follow yourself');

    bool alreadyFollowing = await isFollowing(currentId, followingId);
    if (alreadyFollowing) {
      print("already following! returning");
      return;
    }

    await _followUser(currentId, followingId);
  }

  /// Follow a user
  Future<void> _followUser(String currentId, String followingId) async {
    firestore.runTransaction((transaction) async {
      transaction.set(
        firestore.collection('users').doc(currentId).collection('following').doc(followingId),
        {
          'followedAt': FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        firestore.collection('users').doc(followingId).collection('followers').doc(currentId),
        {
          'followedAt': FieldValue.serverTimestamp(),
        },
      );

      transaction.update(
        firestore.collection('users').doc(currentId),
        {
          'followingCount': FieldValue.increment(1),
        },
      );

      transaction.update(
        firestore.collection('users').doc(followingId),
        {
          'followersCount': FieldValue.increment(1),
        },
      );
    },);
    
    

    if(currentId == currentUser.id) localSeenService.followUser(followingId);
  }

  /// Unfollow a user
  void unfollowUser(String currentId, String followingId) async {
    if (currentId == followingId) throw Exception('Cannot unfollow yourself');


    bool following = await isFollowing(currentId, followingId);
    if (!following) {
      print("not following, cannot unfollow! returning");
      return;
    }
    
    _unfollowUser(currentId, followingId);
  }

  void _unfollowUser(String currentId, String followingId) async {
    firestore.runTransaction((transaction) async {
      transaction.delete(
        firestore.collection('users').doc(currentId).collection('following').doc(followingId),
      );

      transaction.delete(
        firestore.collection('users').doc(followingId).collection('followers').doc(currentId),
      );

      transaction.update(
        firestore.collection('users').doc(currentId),
        {
          'followingCount': FieldValue.increment(-1),
        },
      );

      transaction.update(
        firestore.collection('users').doc(followingId),
        {
          'followersCount': FieldValue.increment(-1),
        },
      );
    });
    if(currentId == currentUser.id) localSeenService.unfollowUser(followingId);
  }

  Future<({List<UserProfile> users, DocumentSnapshot? lastDoc})> searchUsers(
    String query, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    var queryRef = firestore.collection('users').orderBy('username').startAt([query]).endAt([query + '\uf8ff']).limit(limit);

    if (startAfter != null) {
      queryRef = queryRef.startAfterDocument(startAfter);
    }

    final snapshot = await queryRef.get();
    final users = snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();

    return (
      users: users,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    );
  }

  static Future<List<UserProfile>> _fetchProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final profiles = <UserProfile>[];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      final snapshot = await FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      profiles.addAll(snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)));
    }
    return profiles;
  }

  Future<List<String>> getFollowingIds(String userId) async {
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('following').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<List<Video>> getPublishedVideos(String userId, {int limit = 20}) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('videos').where('authorId', isEqualTo: userId).orderBy('createdAt', descending: true).limit(limit).get();
      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching published videos: $e');
      return [];
    }
  }

  Future<List<Video>> getLikedVideos(String userId, {int limit = 20}) async {
    try {
      final likedSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(userId).collection('liked_videos').orderBy('likedAt', descending: true).limit(limit).get();

      final videoIds = likedSnapshot.docs.map((doc) => doc.id).toList();
      return videoRepo.fetchVideosByIds(videoIds);
    } catch (e) {
      print('Error fetching liked videos: $e');
      return [];
    }
  }

  Future<List<Video>> getDislikedVideos(String userId, {int limit = 20}) async {
    try {
      final dislikedSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('disliked_videos')
          .orderBy('dislikedAt', descending: true)
          .limit(limit)
          .get();

      final videoIds = dislikedSnapshot.docs.map((doc) => doc.id).toList();
      return videoRepo.fetchVideosByIds(videoIds);
    } catch (e) {
      print('Error fetching disliked videos: $e');
      return [];
    }
  }

  Future<List<UserProfile>> getFollowers(String userId, {int limit = 50}) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('followers').limit(limit).get();

      final followerIds = snapshot.docs.map((doc) => doc.id).toList();
      return _fetchProfilesByIds(followerIds);
    } catch (e) {
      print('Error fetching followers: $e');
      return [];
    }
  }

  Future<List<UserProfile>> getFollowing(String userId, {int limit = 50}) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('following').limit(limit).get();

      final followingIds = snapshot.docs.map((doc) => doc.id).toList();
      return _fetchProfilesByIds(followingIds);
    } catch (e) {
      print('Error fetching following: $e');
      return [];
    }
  }

  Future<bool> isFollowedBy(String user1, String user2) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user2).collection('following').doc(user1).get();
      return doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  Future<bool> isFollowing(String user1, String user2) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user2).collection('followers').doc(user1).get();
      return doc.exists;
    } catch (e) {
      print('Error checking follow status: $e');
      return false;
    }
  }

  Future<UserProfile> updateProfileImageUrl(
    UserProfile user,
    String? newUrl,
  ) async {
    await firestore.collection('users').doc(user.id).update({
      'profileImageUrl': newUrl,
      'usesCustomProfileImage': newUrl != null,
    });

    return user.copyWith(
      profileImageUrl: newUrl,
      usesCustomProfileImage: newUrl != null,
    );
  }
}

String createUserProfileImageUrl(String? seed) => "https://api.dicebear.com/7.x/miniavs/png?seed=${seed ?? "_"}";
