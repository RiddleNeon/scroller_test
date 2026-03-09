import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

import '../../base_logic.dart';
import '../local_storage/local_seen_service.dart';
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

  Future<UserProfile?> getUserSupabase(String userId) async {
    final supabaseResult = await supabaseClient.from('profiles').select().eq('id', userId).maybeSingle();
    if(supabaseResult == null) return null;
    
    return UserProfile.fromSupabase(supabaseResult);
  }

  Future<UserProfile> getOrCreateUser(String userId) async {
    print("getting user $userId");
    DocumentSnapshot doc = await firestore.collection('users').doc(userId).get();
    print("got doc: ${doc.data()}");

    if (doc.exists) {
      UserProfile model = UserProfile.fromFirestore(doc);
      return model;
    } else {
      UserProfile model = await createUser(
        id: userId,
        username: auth!.currentUser!.displayName ?? auth!.currentUser!.email?.split("@").first ?? auth!.currentUser!.uid,
      );
      return model;
    }
  }

  Future<UserProfile> getOrCreateCurrentUser() async {
    final supabaseResult = await supabaseClient.from('profiles').select().eq('id', auth!.currentUser!.uid).maybeSingle();

    if (supabaseResult != null) {
      UserProfile model = UserProfile.fromSupabase(supabaseResult);
      return model;
    } else {
      UserProfile model = await createCurrentUser();
      return model;
    }
  }

  Future<UserProfile> createCurrentUser({String? username, String? profileImageUrl, String bio = ''}) async {
    username ??= auth!.currentUser!.displayName ?? auth!.currentUser!.email?.split("@").first ?? auth!.currentUser!.uid;
    await supabaseClient.from("profiles").insert({
      "id": auth!.currentUser!.uid,
      "username": username,
      "display_name": username,
      "avatar_url": profileImageUrl ?? createUserProfileImageUrl(username),
      "bio": bio,
    });

    return UserProfile(
      id: auth!.currentUser!.uid,
      username: username,
      profileImageUrl: profileImageUrl ?? createUserProfileImageUrl(username),
      bio: bio,
      createdAt: DateTime.now(),
      followersCount: 0,
    );
  }

  Future<void> upsertCurrentUserProfile(UserProfile user) async {
    await supabaseClient.from("profiles").upsert({
      "id": user.id,
      "username": user.username,
      "display_name": user.username,
      "avatar_url": user.profileImageUrl,
      "bio": user.bio,
    });
  }

  @Deprecated("firebase is deprecated! use createCurrentUser() instead!")
  Future<UserProfile> createUser({required String id, required String username, String? profileImageUrl, String bio = ''}) async {
    await firestore.collection('users').doc(id).set({
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'followersCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await supabaseClient.from("profiles").insert({
      "id": currentUser.id,
      "username": currentUser.username,
      "display_name": currentUser.username,
      "avatar_url": currentUser.profileImageUrl,
      "bio": currentUser.bio,
    });

    return UserProfile(
      id: id,
      username: username,
      profileImageUrl: profileImageUrl ?? createUserProfileImageUrl(username),
      bio: bio,
      createdAt: DateTime.now(),
      followersCount: 0,
    );
  }


  ///returns if the user is followed after the operation
  Future<bool> toggleFollowUser(String currentId, String followingId) async {
    if (currentId == followingId) throw Exception('Cannot toggle follow yourself');

    bool following = await isFollowing(currentId, followingId);

    if (following) {
      _unfollowUser(currentId, followingId);
      return false;
    } else {
      _followUser(currentId, followingId);
      return true;
    }
  }

  ///returns if the user is followed after the operation
  Future<bool> toggleFollowUserSupabase(String currentId, String followingId) async {
    if (currentId == followingId) throw Exception('Cannot toggle follow yourself');

    bool following = await isFollowingSupabase(currentId, followingId);

    if (following) {
      _unfollowUserSupabase(currentId, followingId);
      return false;
    } else {
      _followUserSupabase(currentId, followingId);
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
  Future<void> followUserSupabase(String currentId, String followingId) async {
    if (currentId == followingId) throw Exception('Cannot follow yourself');

    bool alreadyFollowing = await isFollowingSupabase(currentId, followingId);
    if (alreadyFollowing) {
      print("already following! returning");
      return;
    }

    await _followUserSupabase(currentId, followingId);
  }

  /// Follow a user
  Future<void> _followUser(String currentId, String followingId) async {
    firestore.runTransaction((transaction) async {
      transaction.set(firestore.collection('users').doc(currentId).collection('following').doc(followingId), {'followedAt': FieldValue.serverTimestamp()});

      transaction.set(firestore.collection('users').doc(followingId).collection('followers').doc(currentId), {'followedAt': FieldValue.serverTimestamp()});

      transaction.update(firestore.collection('users').doc(currentId), {'followingCount': FieldValue.increment(1)});

      transaction.update(firestore.collection('users').doc(followingId), {'followersCount': FieldValue.increment(1)});
    });

    if (currentId == currentUser.id) localSeenService.followUser(followingId);
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
      transaction.delete(firestore.collection('users').doc(currentId).collection('following').doc(followingId));

      transaction.delete(firestore.collection('users').doc(followingId).collection('followers').doc(currentId));

      transaction.update(firestore.collection('users').doc(currentId), {'followingCount': FieldValue.increment(-1)});

      transaction.update(firestore.collection('users').doc(followingId), {'followersCount': FieldValue.increment(-1)});
    });
    if (currentId == currentUser.id) localSeenService.unfollowUser(followingId);
  }

  void _unfollowUserSupabase(String currentId, String followingId) async {
    await supabaseClient.from('follows').delete().eq('follower_id', currentId).eq('following_id', followingId);
    await supabaseClient.rpc('decrement_following_count', params: {'user_id': currentId});
    await supabaseClient.rpc('decrement_followers_count', params: {'user_id': followingId});
  }

  Future<void> _followUserSupabase(String currentId, String followingId) async {
    await supabaseClient.from('follows').insert({
      "follower_id": currentId,
      "following_id": followingId,
      "created_at": DateTime.now().toIso8601String()
    });
    await supabaseClient.rpc('increment_following_count', params: {'user_id': currentId});
    await supabaseClient.rpc('increment_followers_count', params: {'user_id': followingId});
  }

  Future<({List<UserProfile> users, DocumentSnapshot? lastDoc})> searchUsers(String query, {int limit = 20, DocumentSnapshot? startAfter}) async {
    var queryRef = firestore.collection('users').orderBy('username').startAt([query]).endAt([query + '\uf8ff']).limit(limit);

    if (startAfter != null) {
      queryRef = queryRef.startAfterDocument(startAfter);
    }

    final snapshot = await queryRef.get();
    final users = snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();

    return (users: users, lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null);
  }

  Future<Iterable<UserProfile>> searchUsersSupabase(String query, {int limit = 20, int offset = 0}) async {
    final supabaseResult = await supabaseClient.from('profiles').select().textSearch('display_name', query, type: TextSearchType.websearch).range(offset, offset + limit-1);
    return supabaseResult.map((e) => UserProfile.fromSupabase(e));
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

  Future<List<String>> getFollowingIdsSupabase(String userId) async {
    final response = await supabaseClient
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    return response.map<String>((e) => e['following_id'] as String).toList();
  }

  Future<List<Video>> getPublishedVideos(String userId, {int limit = 20}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching published videos: $e');
      return [];
    }
  }

  Future<List<Video>> getPublishedVideosSupabase(String userId, {int limit = 20, int offset = 0}) async {
    try {
      final response = await supabaseClient
          .from('videos')
          .select('''
          *,
          profiles (
            display_name,
            username
          ),
          video_tags (
            tags (
              name
            )
          )
        ''')
          .eq('author_id', userId)
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<Video>((e) {
        final profile = e['profiles'] as Map<String, dynamic>;
        final authorName = profile['display_name'] ?? profile['username'] ?? '';
        final tags = (e['video_tags'] as List)
            .map((vt) => vt['tags']['name'] as String)
            .toList();

        return Video.fromSupabase(e, authorName, tags);
      }).toList();
    } catch (e) {
      print('Error fetching published videos: $e');
      return [];
    }
  }

  @Deprecated("firebase is deprecated, use the supabase variant instead")
  Future<List<Video>> getLikedVideos(String userId, {int limit = 20}) async {
    try {
      final likedSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('liked_videos')
          .orderBy('likedAt', descending: true)
          .limit(limit)
          .get();

      final videoIds = likedSnapshot.docs.map((doc) => doc.id).toList();
      return videoRepo.fetchVideosByIds(videoIds);
    } catch (e) {
      print('Error fetching liked videos: $e');
      return [];
    }
  }

  Future<List<Video>> getLikedVideosSupabase(String userId, {int limit = 20, int offset = 0}) async {
    try {
      final response = await supabaseClient
          .from('likes')
          .select('''
          *,
          videos (
            *,
            profiles (
              display_name,
              username
            ),
            video_tags (
              tags (
                name
              )
            )
          )
        ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<Video>((e) {
        final video = e['videos'] as Map<String, dynamic>;
        final profile = video['profiles'] as Map<String, dynamic>;
        final authorName = profile['display_name'] ?? profile['username'] ?? '';
        final tags = (video['video_tags'] as List)
            .map((vt) => vt['tags']['name'] as String)
            .toList();

        return Video.fromSupabase(video, authorName, tags);
      }).toList();
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

  Future<List<Video>> getDislikedVideosSupabase(String userId, {int limit = 20, int offset = 0}) async {
    try {
      final response = await supabaseClient
          .from('dislikes')
          .select('''
          *,
          videos (
            *,
            profiles (
              display_name,
              username
            ),
            video_tags (
              tags (
                name
              )
            )
          )
        ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<Video>((e) {
        final video = e['videos'] as Map<String, dynamic>;
        final profile = video['profiles'] as Map<String, dynamic>;
        final authorName = profile['display_name'] ?? profile['username'] ?? '';
        final tags = (video['video_tags'] as List)
            .map((vt) => vt['tags']['name'] as String)
            .toList();

        return Video.fromSupabase(video, authorName, tags);
      }).toList();
    } catch (e) {
      print('Error fetching disliked videos: $e');
      return [];
    }
  }

  @Deprecated("firebase is deprecated, use the supabase variant instead")
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
  Future<List<UserProfile>> getFollowersSupabase(String userId, {int limit = 50, int offset = 0}) async {
    try {
      final response = await supabaseClient
          .from('follows')
          .select('profiles!follower_id(*)')
          .eq('following_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<UserProfile>((e) => UserProfile.fromJson(e['profiles'])).toList();
    } catch (e) {
      print('Error fetching following: $e');
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

  Future<List<UserProfile>> getFollowingSupabase(String userId, {int limit = 50, int offset = 0}) async {
    try {
      final response = await supabaseClient
          .from('follows')
          .select('profiles!following_id(*)')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map<UserProfile>((e) => UserProfile.fromJson(e['profiles'])).toList();
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

  Future<bool> isFollowedBySupabase(String user1, String user2) async {
    try {
      return (await supabaseClient.from('follows').select().eq('follower_id', user2).eq('following_id', user1).maybeSingle()) != null;
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

  Future<bool> isFollowingSupabase(String user1, String user2) async {
    return isFollowedBySupabase(user2, user1);
  }

  Future<UserProfile> updateProfileImageUrl(UserProfile user, String? newUrl) async {
    await firestore.collection('users').doc(user.id).update({'profileImageUrl': newUrl, 'usesCustomProfileImage': newUrl != null});

    return user.copyWith(profileImageUrl: newUrl);
  }

  Future<UserProfile> updateProfileImageUrlSupabase(UserProfile user, String? newUrl) async {
    await supabaseClient.from('profiles').update({"avatar_url": newUrl}).eq('id', user.id);
    return user.copyWith(profileImageUrl: newUrl);
  }

  Future<void> updateFcmTokenSupabase(String userId, String? token) async {
    try {
      await supabaseClient.from('profiles').update({'fcm_token': token}).eq('id', userId);
    } catch (e) {
      print('Error updating FCM token in Supabase: $e');
    }
  }

  Future<String?> getFcmTokenSupabase(String userId) async {
    try {
      final response = await supabaseClient.from('profiles').select('fcm_token').eq('id', userId).maybeSingle();
      return response?['fcm_token'] as String?;
    } catch (e) {
      print('Error fetching FCM token from Supabase: $e');
      return null;
    }
  }
  
  
}

String createUserProfileImageUrl(String? seed) => "https://api.dicebear.com/7.x/miniavs/png?seed=${seed ?? "_"}";
