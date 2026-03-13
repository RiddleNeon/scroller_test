import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

import '../../base_logic.dart';
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
    username ??= currentAuthUsername();
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
    print("Upserting user profile for ${user.id} with username ${user.username}, current id: ${auth?.currentUser?.uid}");
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
  Future<bool> toggleFollowUser(String followingId) async {
    if (currentUser.id == followingId) throw Exception('Cannot toggle follow yourself');
    String result = await supabaseClient.rpc('toggle_follow', params: {'p_user_id': currentUser.id, 'p_other_id': followingId});
    print("toggleFollowUserSupabase result: $result, user: ${currentUser.id}, other: $followingId");
    bool followed = result == 'followed';
    currentUser = currentUser.copyWith(followingCount: followed ? (currentUser.followingCount ?? 0) + 1 : (currentUser.followingCount ?? 1) - 1);
    return followed;
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
    final result = await supabaseClient
        .rpc('search_profiles', params: {
      'search_query': query,
      'p_limit': limit,
      'p_offset': offset,
    });

    return (result as List).map((e) => UserProfile.fromSupabase(e));
  }

  /// returns the total length of the search result of the search query, without pagination. Useful for showing total result count in the UI.
  Future<int> countSearchUsers(String query) async {
    final result = await supabaseClient
        .rpc('count_search_profiles', params: {
      'search_query': query,
    });
    return result as int;
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
          profiles!videos_author_id_fkey (
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
            profiles!videos_author_id_fkey (
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
            profiles!videos_author_id_fkey (
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
    print('Skipping FCM token update for $userId because the provided profiles schema has no fcm_token column.');
  }

  Future<String?> getFcmTokenSupabase(String userId) async {
    return null;
  }

  Future<void> _adjustProfileMetric(String userId, String column, int delta) async {
    await supabaseClient.rpc('increment_profile_metric', params: {'p_user_id': userId, 'p_column': column, 'p_delta': delta});
  }
}

String createUserProfileImageUrl(String? seed) => "https://api.dicebear.com/7.x/miniavs/png?seed=${seed ?? "_"}";
