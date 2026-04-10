import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

import '../../base_logic.dart';
import '../local_storage/local_seen_service.dart';
import '../users/user_model.dart';
import '../video/video.dart';

class BanAuthException extends AuthException{
  const BanAuthException(super.message);
}

class UserRepository {
  static const Duration _userCacheTtl = Duration(minutes: 2);
  final Map<String, _CachedUserProfile> _userCache = {};
  final Map<String, Future<UserProfile?>> _inFlightUserFetches = {};
  final Map<String, _IncrementalVideoCache> _publishedVideosCache = {};
  final Map<String, _IncrementalUserListCache> _followersCache = {};
  final Map<String, _IncrementalUserListCache> _followingCache = {};

  Future<UserProfile> getUser(String userId) async => (await getUserSupabase(userId)) ?? (throw StateError('User $userId not found'));

  Future<UserProfile?> getUserSupabase(String userId) async {
    final cached = _userCache[userId];
    if (cached != null && !cached.isExpired) {
      return cached.profile;
    }

    final localCached = _safeLocalAuthor(userId);
    if (localCached != null) {
      _userCache[userId] = _CachedUserProfile(localCached);
      return localCached;
    }

    final inFlight = _inFlightUserFetches[userId];
    if (inFlight != null) {
      return inFlight;
    }

    final fetch = _getUserSupabaseUncached(userId).whenComplete(() {
      _inFlightUserFetches.remove(userId);
    });
    _inFlightUserFetches[userId] = fetch;
    return fetch;
  }

  Future<UserProfile?> _getUserSupabaseUncached(String userId) async {
    final supabaseResult = await supabaseClient.from('profiles').select().eq('id', userId).maybeSingle();
    if (supabaseResult == null) {
      _userCache.remove(userId);
      return null;
    }

    if (supabaseResult['is_banned'] && (!userLoggedIn || userId == currentUser.id)) {
      throw const BanAuthException("You are banned from this app");
    }

    final profile = UserProfile.fromSupabase(supabaseResult);
    _userCache[userId] = _CachedUserProfile(profile);
    _safeSaveLocalAuthor(profile);
    return profile;
  }

  Future<UserProfile> getOrCreateCurrentUser() async {
    final userId = currentAuthUserId();

    final supabaseResult = await supabaseClient.from('profiles').select().eq('id', userId).maybeSingle();

    if (supabaseResult != null) {
      return UserProfile.fromSupabase(supabaseResult);
    } else {
      return await createCurrentUser();
    }
  }

  Future<UserProfile> createCurrentUser({String? username, String? profileImageUrl, String bio = ''}) async {
    final userId = currentAuthUserId();
    final name = username ?? currentAuthUsername();
    final avatar = profileImageUrl ?? createUserProfileImageUrl(name);

    await supabaseClient.from("profiles").insert({"id": userId, "username": name, "display_name": name, "avatar_url": avatar, "bio": bio});

    final created = UserProfile(id: userId, username: name, profileImageUrl: avatar, bio: bio, createdAt: DateTime.now(), followersCount: 0);
    _userCache[userId] = _CachedUserProfile(created);
    return created;
  }

  Future<void> upsertCurrentUserProfile(UserProfile user) async {
    await supabaseClient.from("profiles").upsert({
      "id": user.id,
      "username": user.username,
      "display_name": user.username,
      "avatar_url": user.profileImageUrl,
      "bio": user.bio,
    });
    _userCache[user.id] = _CachedUserProfile(user);
  }

  Future<UserProfile> createUser({required String id, required String username, String? profileImageUrl, String bio = ''}) async {
    await supabaseClient.from("profiles").upsert({
      "id": id,
      "username": username,
      "display_name": username,
      "avatar_url": profileImageUrl ?? createUserProfileImageUrl(username),
      "bio": bio,
    });

    final created = UserProfile(
      id: id,
      username: username,
      profileImageUrl: profileImageUrl ?? createUserProfileImageUrl(username),
      bio: bio,
      createdAt: DateTime.now(),
      followersCount: 0,
    );
    _userCache[id] = _CachedUserProfile(created);
    return created;
  }

  ///returns if the user is followed after the operation
  Future<bool> toggleFollowUser(String followingId) async {
    if (currentUser.id == followingId) throw Exception('Cannot toggle follow yourself');
    String result = await supabaseClient.rpc('toggle_follow', params: {'p_other_id': followingId});
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
    await supabaseClient.from('follows').insert({"follower_id": currentId, "following_id": followingId, "created_at": DateTime.now().toIso8601String()});
    await _adjustProfileMetric(currentId, 'following_count', 1);
    await _adjustProfileMetric(followingId, 'followers_count', 1);
  }

  Future<({List<UserProfile> users, int? nextOffset})> searchUsers(String query, {int limit = 20, int offset = 0}) async {
    final users = (await searchUsersSupabase(query, limit: limit, offset: offset)).toList();
    return (users: users, nextOffset: users.length < limit ? null : offset + users.length);
  }

  Future<Iterable<UserProfile>> searchUsersSupabase(String query, {int limit = 20, int offset = 0}) async {
    final result = await supabaseClient.rpc('search_profiles', params: {'search_query': query, 'p_limit': limit, 'p_offset': offset});

    return (result as List).map((e) => UserProfile.fromSupabase(e));
  }

  /// returns the total length of the search result of the search query, without pagination. Useful for showing total result count in the UI.
  Future<int> countSearchUsers(String query) async {
    final result = await supabaseClient.rpc('count_search_profiles', params: {'search_query': query});
    return result as int;
  }

  Future<List<String>> getFollowingIds(String userId) async => getFollowingIdsSupabase(userId);

  Future<List<String>> getFollowingIdsSupabase(String userId) async {
    final response = await supabaseClient.from('follows').select('following_id').eq('follower_id', userId);
    return response.map<String>((e) => e['following_id'] as String).toList();
  }

  Future<List<Video>> getPublishedVideos(String userId, {int limit = 20, int offset = 0}) async {
    return _getPublishedVideosIncremental(userId, limit: limit, offset: offset);
  }

  Future<int> getPublishedVideosCount(String userId) async {
    final cache = _publishedVideosCache[userId];
    if (cache != null && cache.initialized) return cache.items.length;
    try {
      final response = await supabaseClient.from('profiles').select('total_videos_count').eq('id', userId).maybeSingle();

      return (response ?? 0) as int;
    } catch (e) {
      print('Error fetching published videos count: $e');
      return 0;
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
        final tags = (video['video_tags'] as List).map((vt) => vt['tags']['name'] as String).toList();

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
        final tags = (video['video_tags'] as List).map((vt) => vt['tags']['name'] as String).toList();

        return Video.fromSupabase(video, authorName, tags);
      }).toList();
    } catch (e) {
      print('Error fetching disliked videos: $e');
      return [];
    }
  }

  Future<List<UserProfile>> getFollowers(String userId, {int limit = 50, int offset = 0}) async {
    return _getFollowersIncremental(userId, limit: limit, offset: offset);
  }

  Future<int> getFollowersCount(String userId) async {
    final cache = _followersCache[userId];
    if (cache != null && cache.initialized) return cache.items.length;
    try {
      final response = await supabaseClient.rpc('get_followers_count', params: {'user_id': userId});

      return response as int;
    } catch (e) {
      print('Error fetching followers count: $e');
      return 0;
    }
  }

  Future<List<UserProfile>> getFollowing(String userId, {int limit = 50, int offset = 0}) async {
    return _getFollowingIncremental(userId, limit: limit, offset: offset);
  }

  Future<int> getFollowingCount(String userId) async {
    final cache = _followingCache[userId];
    if (cache != null && cache.initialized) return cache.items.length;
    try {
      final response = await supabaseClient.rpc('get_following_count', params: {'user_id': userId});

      return response as int;
    } catch (e) {
      print('Error fetching following count: $e');
      return 0;
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
    final updated = user.copyWith(profileImageUrl: newUrl);
    _userCache[user.id] = _CachedUserProfile(updated);
    return updated;
  }

  Future<void> updateFcmTokenSupabase(String userId, String? token) async {
    print('Skipping FCM token update for $userId because the provided profiles schema has no fcm_token column.'); //todo
  }

  Future<String?> getFcmTokenSupabase(String userId) async {
    return null;
  }

  Future<List<Video>> _getPublishedVideosIncremental(String userId, {required int limit, required int offset}) async {
    final cache = _publishedVideosCache.putIfAbsent(userId, _IncrementalVideoCache.new);

    if (!cache.initialized) {
      final firstPage = await _fetchPublishedVideosPage(userId, offset: 0, limit: limit);
      cache.items
        ..clear()
        ..addAll(firstPage);
      cache.initialized = true;
      cache.exhausted = firstPage.length < limit;
      cache.newestCreatedAt = cache.items.isEmpty ? null : cache.items.first.createdAt;
    } else if (offset == 0 && cache.newestCreatedAt != null) {
      final newRows = await _fetchNewPublishedVideos(userId, after: cache.newestCreatedAt!);
      if (newRows.isNotEmpty) {
        _prependUniqueVideos(cache.items, newRows);
        cache.newestCreatedAt = cache.items.first.createdAt;
      }
    }

    if (!cache.exhausted && offset + limit > cache.items.length) {
      final fetchOffset = cache.items.length;
      final nextPage = await _fetchPublishedVideosPage(userId, offset: fetchOffset, limit: limit);
      if (nextPage.isNotEmpty) {
        _appendUniqueVideos(cache.items, nextPage);
      }
      if (nextPage.length < limit) {
        cache.exhausted = true;
      }
      cache.newestCreatedAt ??= cache.items.isEmpty ? null : cache.items.first.createdAt;
    }

    if (offset >= cache.items.length) return [];
    final end = (offset + limit).clamp(offset, cache.items.length);
    return cache.items.sublist(offset, end);
  }

  Future<List<UserProfile>> _getFollowersIncremental(String userId, {required int limit, required int offset}) async {
    final cache = _followersCache.putIfAbsent(userId, _IncrementalUserListCache.new);
    return _getRelationUsersIncremental(
      cache: cache,
      limit: limit,
      offset: offset,
      loadPage: (pageOffset, pageLimit) => _fetchFollowersPage(userId, offset: pageOffset, limit: pageLimit),
      loadNew: (after) => _fetchNewFollowers(userId, after: after),
    );
  }

  Future<List<UserProfile>> _getFollowingIncremental(String userId, {required int limit, required int offset}) async {
    final cache = _followingCache.putIfAbsent(userId, _IncrementalUserListCache.new);
    return _getRelationUsersIncremental(
      cache: cache,
      limit: limit,
      offset: offset,
      loadPage: (pageOffset, pageLimit) => _fetchFollowingPage(userId, offset: pageOffset, limit: pageLimit),
      loadNew: (after) => _fetchNewFollowing(userId, after: after),
    );
  }

  Future<List<UserProfile>> _getRelationUsersIncremental({
    required _IncrementalUserListCache cache,
    required int limit,
    required int offset,
    required Future<List<_TimedUserProfile>> Function(int offset, int limit) loadPage,
    required Future<List<_TimedUserProfile>> Function(DateTime after) loadNew,
  }) async {
    if (!cache.initialized) {
      final firstPage = await loadPage(0, limit);
      cache.items
        ..clear()
        ..addAll(firstPage.map((e) => e.profile));
      cache.initialized = true;
      cache.exhausted = firstPage.length < limit;
      cache.newestCreatedAt = firstPage.isEmpty ? null : firstPage.first.createdAt;
      for (final item in firstPage) {
        _safeSaveLocalAuthor(item.profile);
      }
    } else if (offset == 0 && cache.newestCreatedAt != null) {
      final newRows = await loadNew(cache.newestCreatedAt!);
      if (newRows.isNotEmpty) {
        _prependUniqueUsers(cache.items, newRows.map((e) => e.profile).toList());
        cache.newestCreatedAt = newRows.first.createdAt;
        for (final item in newRows) {
          _safeSaveLocalAuthor(item.profile);
        }
      }
    }

    if (!cache.exhausted && offset + limit > cache.items.length) {
      final page = await loadPage(cache.items.length, limit);
      if (page.isNotEmpty) {
        _appendUniqueUsers(cache.items, page.map((e) => e.profile).toList());
        for (final item in page) {
          _safeSaveLocalAuthor(item.profile);
        }
      }
      if (page.length < limit) {
        cache.exhausted = true;
      }
      if (cache.newestCreatedAt == null && page.isNotEmpty) {
        cache.newestCreatedAt = page.first.createdAt;
      }
    }

    if (offset >= cache.items.length) return [];
    final end = (offset + limit).clamp(offset, cache.items.length);
    return cache.items.sublist(offset, end);
  }

  Future<List<Video>> _fetchPublishedVideosPage(String userId, {required int offset, required int limit}) async {
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
        final tags = (e['video_tags'] as List).map((vt) => vt['tags']['name'] as String).toList();
        return Video.fromSupabase(e, authorName, tags);
      }).toList();
    } catch (e) {
      print('Error fetching published videos page: $e');
      return [];
    }
  }

  Future<List<Video>> _fetchNewPublishedVideos(String userId, {required DateTime after}) async {
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
          .gt('created_at', after.toUtc().toIso8601String())
          .order('created_at', ascending: false);
      return response.map<Video>((e) {
        final profile = e['profiles'] as Map<String, dynamic>;
        final authorName = profile['display_name'] ?? profile['username'] ?? '';
        final tags = (e['video_tags'] as List).map((vt) => vt['tags']['name'] as String).toList();
        return Video.fromSupabase(e, authorName, tags);
      }).toList();
    } catch (e) {
      print('Error fetching new published videos: $e');
      return [];
    }
  }

  Future<List<_TimedUserProfile>> _fetchFollowersPage(String userId, {required int offset, required int limit}) async {
    try {
      final response = await supabaseClient
          .from('follows')
          .select('created_at, profiles!follower_id(*)')
          .eq('following_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return response.map<_TimedUserProfile>((e) {
        final profile = UserProfile.fromJson(Map<String, dynamic>.from(e['profiles']));
        final createdAt = DateTime.parse(e['created_at'] as String).toLocal();
        return _TimedUserProfile(profile: profile, createdAt: createdAt);
      }).toList();
    } catch (e) {
      print('Error fetching followers page: $e');
      return [];
    }
  }

  Future<List<_TimedUserProfile>> _fetchNewFollowers(String userId, {required DateTime after}) async {
    try {
      final response = await supabaseClient
          .from('follows')
          .select('created_at, profiles!follower_id(*)')
          .eq('following_id', userId)
          .gt('created_at', after.toUtc().toIso8601String())
          .order('created_at', ascending: false);
      return response.map<_TimedUserProfile>((e) {
        final profile = UserProfile.fromJson(Map<String, dynamic>.from(e['profiles']));
        final createdAt = DateTime.parse(e['created_at'] as String).toLocal();
        return _TimedUserProfile(profile: profile, createdAt: createdAt);
      }).toList();
    } catch (e) {
      print('Error fetching new followers: $e');
      return [];
    }
  }

  Future<List<_TimedUserProfile>> _fetchFollowingPage(String userId, {required int offset, required int limit}) async {
    try {
      final response = await supabaseClient
          .from('follows')
          .select('created_at, profiles!following_id(*)')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return response.map<_TimedUserProfile>((e) {
        final profile = UserProfile.fromJson(Map<String, dynamic>.from(e['profiles']));
        final createdAt = DateTime.parse(e['created_at'] as String).toLocal();
        return _TimedUserProfile(profile: profile, createdAt: createdAt);
      }).toList();
    } catch (e) {
      print('Error fetching following page: $e');
      return [];
    }
  }

  Future<List<_TimedUserProfile>> _fetchNewFollowing(String userId, {required DateTime after}) async {
    try {
      final response = await supabaseClient
          .from('follows')
          .select('created_at, profiles!following_id(*)')
          .eq('follower_id', userId)
          .gt('created_at', after.toUtc().toIso8601String())
          .order('created_at', ascending: false);
      return response.map<_TimedUserProfile>((e) {
        final profile = UserProfile.fromJson(Map<String, dynamic>.from(e['profiles']));
        final createdAt = DateTime.parse(e['created_at'] as String).toLocal();
        return _TimedUserProfile(profile: profile, createdAt: createdAt);
      }).toList();
    } catch (e) {
      print('Error fetching new following: $e');
      return [];
    }
  }

  void _prependUniqueVideos(List<Video> target, List<Video> incoming) {
    final existing = target.map((e) => e.id).toSet();
    final toInsert = incoming.where((e) => !existing.contains(e.id)).toList();
    target.insertAll(0, toInsert);
  }

  void _appendUniqueVideos(List<Video> target, List<Video> incoming) {
    final existing = target.map((e) => e.id).toSet();
    for (final video in incoming) {
      if (!existing.contains(video.id)) {
        target.add(video);
      }
    }
  }

  void _prependUniqueUsers(List<UserProfile> target, List<UserProfile> incoming) {
    final existing = target.map((e) => e.id).toSet();
    final toInsert = incoming.where((e) => !existing.contains(e.id)).toList();
    target.insertAll(0, toInsert);
  }

  void _appendUniqueUsers(List<UserProfile> target, List<UserProfile> incoming) {
    final existing = target.map((e) => e.id).toSet();
    for (final user in incoming) {
      if (!existing.contains(user.id)) {
        target.add(user);
      }
    }
  }

  UserProfile? _safeLocalAuthor(String userId) {
    try {
      return localSeenService.getAuthorFromCache(userId);
    } catch (_) {
      return null;
    }
  }

  void _safeSaveLocalAuthor(UserProfile profile) {
    try {
      localSeenService.saveAuthor(profile);
    } catch (_) {}
  }

  Future<void> _adjustProfileMetric(String userId, String column, int delta) async {
    await supabaseClient.rpc('increment_profile_metric', params: {'p_user_id': userId, 'p_column': column, 'p_delta': delta});
  }
  
  bool _currentlySelfBanning = false;
  Future<void> selfBanUserSupabase() async {
    if(_currentlySelfBanning) return;
    _currentlySelfBanning = true;
    await supabaseClient.from('profiles').update({"is_banned": true}).eq('id', currentUser.id);
    _userCache.remove(currentUser.id);
    await onUserLogout();
    await auth.signOut();
    _currentlySelfBanning = false;
  }

  Future<void> unbanSelfSupabase(String currentUserId) async {
    // Only for testing purposes, in a real app this should be handled by admins
    await supabaseClient.from('profiles').update({"is_banned": false}).eq('id', currentUserId);
  }

  Future<void> appealBanSupabase(String id, String reason) async {
    await supabaseClient.from('ban_appeals').insert({"user_id": id, "appeal_message": reason, "created_at": DateTime.now().toIso8601String()});
    await Future.delayed(const Duration(seconds: 5), () async {
      await unbanSelfSupabase(id);
      print("Simulating ban appeal review for user $id. In a real app, this would be handled by admins. Unbanning user.");
    });
  }
}

String createUserProfileImageUrl(String? seed) => "https://api.dicebear.com/7.x/miniavs/png?seed=${seed ?? "_"}";

class _CachedUserProfile {
  final UserProfile profile;
  final DateTime cachedAt;

  _CachedUserProfile(this.profile) : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt) > UserRepository._userCacheTtl;
}

class _IncrementalVideoCache {
  final List<Video> items = [];
  DateTime? newestCreatedAt;
  bool initialized = false;
  bool exhausted = false;
}

class _IncrementalUserListCache {
  final List<UserProfile> items = [];
  DateTime? newestCreatedAt;
  bool initialized = false;
  bool exhausted = false;
}

class _TimedUserProfile {
  final UserProfile profile;
  final DateTime createdAt;

  _TimedUserProfile({required this.profile, required this.createdAt});
}
