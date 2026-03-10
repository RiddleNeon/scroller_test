import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

import '../../base_logic.dart';
import '../local_storage/local_seen_service.dart';
import '../models/user_model.dart';
import '../video/video.dart';

class UserRepository {
  Future<UserProfile> getUser(String userId) async => (await getUserSupabase(userId)) ?? (throw StateError('User $userId not found'));

  Future<UserProfile?> getUserSupabase(String userId) async {
    final supabaseResult = await supabaseClient.from('profiles').select().eq('id', userId).maybeSingle();
    if(supabaseResult == null) return null;
    
    return UserProfile.fromSupabase(supabaseResult);
  }

  Future<UserProfile> getOrCreateUser(String userId) async {
    return (await getUserSupabase(userId)) ??
        await createUser(
          id: userId,
          username: currentAuthUsername(),
        );
  }

  Future<UserProfile> getOrCreateCurrentUser() async {
    final supabaseResult = await supabaseClient.from('profiles').select().eq('id', auth!.currentUser!.id).maybeSingle();

    if (supabaseResult != null) {
      UserProfile model = UserProfile.fromSupabase(supabaseResult);
      return model;
    } else {
      UserProfile model = await createCurrentUser();
      return model;
    }
  }

  Future<UserProfile> createCurrentUser({String? username, String? profileImageUrl, String bio = ''}) async {
    username ??= currentAuthUsername();
    await supabaseClient.from("profiles").insert({
      "id": auth!.currentUser!.id,
      "username": username,
      "display_name": username,
      "avatar_url": profileImageUrl ?? createUserProfileImageUrl(username),
      "bio": bio,
    });

    return UserProfile(
      id: auth!.currentUser!.id,
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

  Future<UserProfile> createUser({required String id, required String username, String? profileImageUrl, String bio = ''}) async {
    await supabaseClient.from("profiles").upsert({
      "id": id,
      "username": username,
      "display_name": username,
      "avatar_url": profileImageUrl ?? createUserProfileImageUrl(username),
      "bio": bio,
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
    return toggleFollowUserSupabase(currentId, followingId);
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
    await followUserSupabase(currentId, followingId);
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
  /// Unfollow a user
  void unfollowUser(String currentId, String followingId) async {
    _unfollowUserSupabase(currentId, followingId);
  }

  void _unfollowUserSupabase(String currentId, String followingId) async {
    await supabaseClient.from('follows').delete().eq('follower_id', currentId).eq('following_id', followingId);
    await _adjustProfileMetric(currentId, 'following_count', -1);
    await _adjustProfileMetric(followingId, 'followers_count', -1);
  }

  Future<void> _followUserSupabase(String currentId, String followingId) async {
    await supabaseClient.from('follows').insert({
      "follower_id": currentId,
      "following_id": followingId,
      "created_at": DateTime.now().toIso8601String()
    });
    await _adjustProfileMetric(currentId, 'following_count', 1);
    await _adjustProfileMetric(followingId, 'followers_count', 1);
  }

  Future<({List<UserProfile> users, int? nextOffset})> searchUsers(String query, {int limit = 20, int offset = 0}) async {
    final users = (await searchUsersSupabase(query, limit: limit, offset: offset)).toList();
    return (users: users, nextOffset: users.length < limit ? null : offset + users.length);
  }

  Future<Iterable<UserProfile>> searchUsersSupabase(String query, {int limit = 20, int offset = 0}) async {
    final supabaseResult = await supabaseClient
        .from('profiles')
        .select()
        .or('display_name.ilike.%$query%,username.ilike.%$query%')
        .range(offset, offset + limit-1);
    return supabaseResult.map((e) => UserProfile.fromSupabase(e));
  }
  
  

  static Future<List<UserProfile>> _fetchProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final response = await supabaseClient.from('profiles').select().inFilter('id', ids);
    return response.map<UserProfile>((profile) => UserProfile.fromSupabase(profile)).toList();
  }

  Future<List<String>> getFollowingIds(String userId) async => getFollowingIdsSupabase(userId);

  Future<List<String>> getFollowingIdsSupabase(String userId) async {
    final response = await supabaseClient
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    return response.map<String>((e) => e['following_id'] as String).toList();
  }

  Future<List<Video>> getPublishedVideos(String userId, {int limit = 20}) async {
    return getPublishedVideosSupabase(userId, limit: limit);
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

  Future<List<Video>> getLikedVideos(String userId, {int limit = 20}) async {
    return getLikedVideosSupabase(userId, limit: limit);
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
    return getDislikedVideosSupabase(userId, limit: limit);
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

  Future<List<UserProfile>> getFollowers(String userId, {int limit = 50}) async {
    return getFollowersSupabase(userId, limit: limit);
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
    return getFollowingSupabase(userId, limit: limit);
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
    return isFollowedBySupabase(user1, user2);
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
    return isFollowingSupabase(user1, user2);
  }

  Future<bool> isFollowingSupabase(String user1, String user2) async {
    return isFollowedBySupabase(user2, user1);
  }

  Future<UserProfile> updateProfileImageUrl(UserProfile user, String? newUrl) async {
    return updateProfileImageUrlSupabase(user, newUrl);
  }

  Future<UserProfile> updateProfileImageUrlSupabase(UserProfile user, String? newUrl) async {
    await supabaseClient.from('profiles').update({"avatar_url": newUrl}).eq('id', user.id);
    return user.copyWith(profileImageUrl: newUrl);
  }

  Future<void> updateFcmTokenSupabase(String userId, String? token) async {
    try {
      await supabaseClient.from('profiles').update({'fcm_token': token}).eq('id', userId);
    } catch (e) {
      print('Error updating FCM token in Supabase for user $userId: $e');
    }
  }

  Future<String?> getFcmTokenSupabase(String userId) async {
    try {
      final response = await supabaseClient.from('profiles').select('fcm_token').eq('id', userId).maybeSingle();
      return response?['fcm_token'] as String?;
    } catch (e) {
      print('Error fetching FCM token from Supabase for user $userId: $e');
      return null;
    }
  }

  Future<void> _adjustProfileMetric(String userId, String column, int delta) async {
    final response = await supabaseClient.from('profiles').select(column).eq('id', userId).maybeSingle();
    final currentValue = (response?[column] as int?) ?? 0;
    await supabaseClient.from('profiles').update({column: (currentValue + delta).clamp(0, 1 << 30)}).eq('id', userId);
  }
}

String createUserProfileImageUrl(String? seed) => "https://api.dicebear.com/7.x/miniavs/png?seed=${seed ?? "_"}";
