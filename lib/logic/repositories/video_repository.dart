import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/logic/batches/batch_service.dart';
import 'package:wurp/logic/comments/comment.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

import '../../base_logic.dart';

VideoRepository videoRepo = VideoRepository();
final FirestoreBatchQueue batchQueue = FirestoreBatchQueue();

/// Repository for video-related operations
class VideoRepository {
  Future<Video> getVideoById(String id) async {
    DocumentSnapshot doc = await firestore.collection('videos').doc(id).get();
    Video model = Video.fromFirestore(doc);

    return model;
  }

  Future<Video?> getVideoByIdSupabase(String id) async {
    final supabaseVid = (await supabaseClient
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
        .eq('id', id)
        .eq('is_published', true)
        .maybeSingle());
    if (supabaseVid == null) return null;

    final profile = supabaseVid['profiles'] as Map<String, dynamic>;
    final authorName = profile['display_name'] ?? profile['username'] ?? '';
    final tags = (supabaseVid['video_tags'] as List).map((vt) => vt['tags']['name'] as String).toList();

    return Video.fromSupabase(supabaseVid, authorName, tags);
  }

  int videoQueueLength = 0;

  /// Publish a new video
  Future<void> publishVideo({
    required String title,
    required String description,
    required String videoUrl,
    String? thumbnailUrl,
    required String authorId,
    List<String> tags = const [],
  }) async {
    final videoRef = firestore.collection('videos').doc();

    batchQueue.set(videoRef, {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'authorId': authorId,
      'createdAt': FieldValue.serverTimestamp(),
      'tags': tags.map((tag) => tag.toLowerCase()).toList(),
      'likesCount': 0,
      'sharesCount': 0,
      'commentsCount': 0,
      'viewsCount': 0,
    });

    batchQueue.set(firestore.collection('users').doc(authorId).collection('videos').doc(videoRef.id), {'createdAt': FieldValue.serverTimestamp()});
    videoQueueLength++;
    if (videoQueueLength >= 10) {
      await flush();
      videoQueueLength = 0;
    }
  }

  Future<void> publishVideoSupabase({
    required String title,
    required String description,
    required String videoUrl,
    String? thumbnailUrl,
    required String authorId,
    List<String> tags = const [],
  }) async {
    String publishedVideoId =
        (await supabaseClient
                .from('videos')
                .insert({
                  'title': title,
                  'description': description,
                  'video_url': videoUrl,
                  'thumbnail_url': thumbnailUrl,
                  'author_id': authorId,
                  'is_published': true,
                  'created_at': DateTime.now().toIso8601String(),
                })
                .select('id'))
            .single['id'];

    if (tags.isNotEmpty) {
      final upsertedTags = await supabaseClient.from('tags').upsert(tags.map((tag) => {'name': tag}).toList(), onConflict: 'name').select('id');

      final videoTags = upsertedTags.map((tag) => {'video_id': publishedVideoId, 'tag_id': tag['id']}).toList();

      await supabaseClient.from('video_tags').upsert(videoTags, onConflict: 'video_id, tag_id');
    }

    await supabaseClient.rpc('increment_total_videos_count', params: {'user_id': currentUser.id});
  }

  /// Like a video
  void likeVideo(String userId, String videoId, String authorId) async {
    batchQueue.set(firestore.collection('users').doc(userId).collection('liked_videos').doc(videoId), {'likedAt': FieldValue.serverTimestamp()});

    batchQueue.set(firestore.collection('videos').doc(videoId).collection('likes').doc(userId), {'likedAt': FieldValue.serverTimestamp()});

    batchQueue.update(firestore.collection('videos').doc(videoId), {'likesCount': FieldValue.increment(1)});

    firestore.collection('users').doc(authorId).update({'totalLikes': FieldValue.increment(1)});
  }

  ///returns 'liked' or 'unliked' depending on the operation the server ran
  Future<String> toggleLikeSupabase(String userId, int videoId) async {
    final result = await supabaseClient.rpc('toggle_like', params: {'p_user_id': userId, 'p_video_id': videoId});
    return result as String;
  }

  ///returns 'disliked' or 'undisliked' depending on the operation the server ran
  Future<String> toggleDislikeSupabase(String userId, int videoId) async {
    final result = await supabaseClient.rpc('toggle_dislike', params: {'p_user_id': userId, 'p_video_id': videoId});
    return result as String;
  }

  /// Unlike a video
  void unlikeVideo(String userId, String videoId, String authorId) {
    batchQueue.delete(firestore.collection('users').doc(userId).collection('liked_videos').doc(videoId));

    batchQueue.delete(firestore.collection('videos').doc(videoId).collection('likes').doc(userId));

    batchQueue.update(firestore.collection('videos').doc(videoId), {'likesCount': FieldValue.increment(-1)});

    firestore.collection('users').doc(authorId).update({'totalLikes': FieldValue.increment(-1)});
  }

  void dislikeVideo(String userId, String videoId) {
    batchQueue.set(firestore.collection('users').doc(userId).collection('disliked_videos').doc(videoId), {'dislikedAt': FieldValue.serverTimestamp()});

    batchQueue.set(firestore.collection('videos').doc(videoId).collection('dislikes').doc(userId), {'dislikedAt': FieldValue.serverTimestamp()});

    batchQueue.update(firestore.collection('videos').doc(videoId), {'dislikesCount': FieldValue.increment(1)});
  }

  /// Unlike a video
  void undislikeVideo(String userId, String videoId) {
    batchQueue.delete(firestore.collection('users').doc(userId).collection('disliked_videos').doc(videoId));

    batchQueue.delete(firestore.collection('videos').doc(videoId).collection('dislikes').doc(userId));

    batchQueue.update(firestore.collection('videos').doc(videoId), {'dislikesCount': FieldValue.increment(-1)});
  }

  /// Increment view count
  void incrementViewCount(String videoId) {
    batchQueue.update(firestore.collection('videos').doc(videoId), {'viewsCount': FieldValue.increment(1)});
  }

  Future<void> recordViewSupabase(int videoId) async {
    await supabaseClient.rpc('increment_view_count', params: {'p_video_id': videoId});
  }

  /// Increment share count
  void incrementShareCount(String videoId) {
    batchQueue.update(firestore.collection('videos').doc(videoId), {'shares': FieldValue.increment(1)});
  }

  Future<void> incrementShareCountSupabase(int videoId) async {
    await supabaseClient.rpc('increment_share_count', params: {'p_video_id': videoId});
  }

  /// Add a comment
  Future<void> addComment(String videoId, Comment comment) async {
    print("adding ${comment.toFirestore()} to ${comment.id}");
    await firestore.collection('videos').doc(videoId).collection('comments').doc(comment.id).set(comment.toFirestore());
    await firestore.collection('videos').doc(videoId).set({"commentsCount": FieldValue.increment(1)}, SetOptions(merge: true));
  }

  Future<Comment> postCommentSupabase({required String userId, required int videoId, required String content, int? parentId}) async {
    final newId = await supabaseClient.rpc(
      'post_comment',
      params: {'p_author_id': userId, 'p_video_id': videoId, 'p_content': content, 'p_parent_id': parentId},
    );

    final profile = await supabaseClient.from('profiles').select('username, avatar_url').eq('id', userId).single();

    return Comment(
      id: newId.toString(),
      userId: userId,
      username: profile['username'] as String,
      userProfileImageUrl: profile['avatar_url'] as String? ?? '',
      message: content,
      date: DateTime.now(),
      parentId: parentId?.toString(),
      depth: parentId != null ? 1 : 0,
      replyCount: 0,
    );
  }

  Future<({List<Comment> comments, DocumentSnapshot? lastDoc})> getComments(
    String videoId, {
    String? commentId,
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    Query baseQuery = firestore.collection('videos').doc(videoId).collection('comments');

    if (startAfter != null) {
      baseQuery = baseQuery.startAfterDocument(startAfter);
    }
    if (commentId == null) {
      baseQuery = baseQuery.where('parentId', isNull: true);
    } else {
      baseQuery = baseQuery.where('parentId', isEqualTo: commentId);
    }

    final result = await baseQuery.limit(limit).get();
    DocumentSnapshot? lastDoc = result.docs.lastOrNull;

    List<Comment> comments = result.docs
        .map((e) {
          Object? data = e.data();
          if (data is! Map<String, dynamic>) return null;
          try {
            return Comment.fromFirestore(e.id, data);
          } on TypeError catch (_) {
            return null;
          }
        })
        .whereType<Comment>()
        .toList();

    return (comments: comments, lastDoc: lastDoc);
  }

  Future<List<Comment>> getCommentsSupabase(String videoId, {int? parentCommentId, int limit = 20, int offset = 0}) async {
    var baseQuery = supabaseClient
        .from('comments')
        .select('''
                *,
                profiles (
                  username,
                  avatar_url
                )
              ''')
        .eq('video_id', videoId);

    if (parentCommentId == null) {
      baseQuery = baseQuery.isFilter('parent_id', null);
    } else {
      baseQuery = baseQuery.eq('parent_id', parentCommentId);
    }

    final result = await baseQuery.order('created_at', ascending: false).range(offset, offset + limit - 1);

    return result.map<Comment>(Comment.fromSupabase).toList();
  }

  /// Save video
  void saveVideo(String userId, String videoId) { //todo
    batchQueue.set(firestore.collection('users').doc(userId).collection('saved_videos').doc(videoId), {'savedAt': FieldValue.serverTimestamp()});
  }

  Future<void> saveVideoSupabase(String userId, int videoId) async {
    await supabaseClient.from('saved_videos').upsert(
      {'user_id': userId, 'video_id': videoId},
      onConflict: 'user_id, video_id',
    );
  }

  /// Unsave video
  void unsaveVideo(String userId, String videoId) {
    batchQueue.delete(firestore.collection('users').doc(userId).collection('saved_videos').doc(videoId));
  }

  Future<void> unsaveVideoSupabase(String userId, int videoId) async {
    await supabaseClient
        .from('saved_videos')
        .delete()
        .eq('user_id', userId)
        .eq('video_id', videoId);
  }

  /// Report a video
  void reportVideo(String userId, String videoId, String reason) { //todo
    batchQueue.set(firestore.collection('video_reports').doc(), {
      'userId': userId,
      'videoId': videoId,
      'reason': reason,
      'reportedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  Future<void> reportVideoSupabase(String userId, int videoId, String reason) async {
    await supabaseClient.from('video_reports').insert({
      'user_id': userId,
      'video_id': videoId,
      'reason': reason,
      'status': 'pending',
    });
  }

  /// Force commit all pending operations
  Future<void> flush() async {
    await batchQueue.commit();
  }

  /// Get current queue size
  int get pendingOperations => batchQueue.queueSize;

  /// Get video feed for a user (following feed)
  Future<List<Video>> getFollowingFeed(String userId, {int limit = 20}) async {
    try {
      final followingSnapshot = await firestore.collection('users').doc(userId).collection('following').get();

      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

      if (followingIds.isEmpty) return [];

      final videosSnapshot = await firestore
          .collection('videos')
          .where('authorId', whereIn: followingIds.take(10).toList())
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return videosSnapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting following feed: $e');
      return [];
    }
  }

  Future<List<Video>> getFollowingFeedSupabase(String userId, {int limit = 20, int offset = 0}) async {
    final result = await supabaseClient
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
        .inFilter('author_id', (await supabaseClient
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId))
        .map((e) => e['following_id'] as String)
        .toList())
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return result.map<Video>((e) {
      final profile = e['profiles'] as Map<String, dynamic>;
      final authorName = profile['display_name'] ?? profile['username'] ?? '';
      final tags = (e['video_tags'] as List)
          .map((vt) => vt['tags']['name'] as String)
          .toList();
      return Video.fromSupabase(e, authorName, tags);
    }).toList();
  }

  /// Get trending videos
  Future<List<Video>> getTrendingVideos({int limit = 20}) async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));

      final snapshot = await firestore
          .collection('videos')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .orderBy('createdAt', descending: true)
          .limit(limit * 3)
          .get();

      final videos = snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();

      videos.sort((a, b) => b.engagementRate.compareTo(a.engagementRate));

      return videos.take(limit).toList();
    } catch (e) {
      print('Error getting trending videos: $e');
      return [];
    }
  }

  Future<List<Video>> getTrendingVideosSupabase({int limit = 20}) async {
    final result = await supabaseClient
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
        .eq('is_published', true)
        .gte('created_at', DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
        .order('views_count', ascending: false)
        .limit(limit);

    return result.map<Video>((e) {
      final profile = e['profiles'] as Map<String, dynamic>;
      final authorName = profile['display_name'] ?? profile['username'] ?? '';
      final tags = (e['video_tags'] as List)
          .map((vt) => vt['tags']['name'] as String)
          .toList();
      return Video.fromSupabase(e, authorName, tags);
    }).toList();
  }

  /// Search videos by title or tags
  Future<({List<Video> videos, DocumentSnapshot? lastDoc})> searchVideos(String query, {int limit = 20, DocumentSnapshot? startAfter}) async {
    var queryRef = firestore.collection('videos').orderBy('title').startAt([query]).endAt([query + '\uf8ff']).limit(limit);

    if (startAfter != null) {
      queryRef = queryRef.startAfterDocument(startAfter);
    }

    final snapshot = await queryRef.get();
    final videos = snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();

    return (videos: videos, lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null);
  }

  Future<List<Video>> searchVideosSupabase(String query, {int limit = 20, int offset = 0}) async {
    final result = await supabaseClient
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
        .textSearch('fts', query)
        .range(offset, offset + limit - 1);

    return result.map<Video>((e) {
      final profile = e['profiles'] as Map<String, dynamic>;
      final authorName = profile['display_name'] ?? profile['username'] ?? '';
      final tags = (e['video_tags'] as List)
          .map((vt) => vt['tags']['name'] as String)
          .toList();
      return Video.fromSupabase(e, authorName, tags);
    }).toList();
  }

  Future<({List<Video> videos, DocumentSnapshot? lastDoc})> searchVideosByTag(String tag, {int limit = 20, DocumentSnapshot? startAfter}) async {
    var queryRef = firestore
        .collection('videos')
        .where('tags', arrayContains: tag)
        .orderBy('likesCount') //todo switch when using new naming for new videos
        .limit(limit);

    if (startAfter != null) {
      queryRef = queryRef.startAfterDocument(startAfter);
    }

    final snapshot = await queryRef.get();
    final videos = snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();

    return (videos: videos, lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null);
  }

  Future<List<Video>> searchVideosByTagSupabase(String tag, {int limit = 20, int offset = 0}) async {
    final result = await supabaseClient
        .from('video_tags')
        .select('''
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
        .eq('tags.name', tag)
        .range(offset, offset + limit - 1);

    return result
        .map((e) => e['videos'] as Map<String, dynamic>)
        .map((video) {
      final profile = video['profiles'] as Map<String, dynamic>;
      final authorName = profile['display_name'] ?? profile['username'] ?? '';
      final tags = (video['video_tags'] as List)
          .map((vt) => vt['tags']['name'] as String)
          .toList();
      return Video.fromSupabase(video, authorName, tags);
    }).toList();
  }

  /// Get videos by specific tags
  Future<List<Video>> getVideosByTags(List<String> tags, {int limit = 20}) async {
    try {
      final snapshot = await firestore.collection('videos').where('tags', arrayContainsAny: tags).orderBy('createdAt', descending: true).limit(limit).get();

      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting videos by tags: $e');
      return [];
    }
  }

  Future<List<Video>> getVideosByTagsSupabase(List<String> tags, {int limit = 20, int offset = 0}) async {
    final taggedVideoIds = await supabaseClient
        .from('video_tags')
        .select('video_id, tags!inner(name)')
        .inFilter('tags.name', tags);

    final videoIds = taggedVideoIds
        .map((e) => e['video_id'])
        .toSet()
        .toList();

    if (videoIds.isEmpty) return [];

    final result = await supabaseClient
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
        .inFilter('id', videoIds)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return result.map<Video>((e) {
      final profile = e['profiles'] as Map<String, dynamic>;
      final authorName = profile['display_name'] ?? profile['username'] ?? '';
      final tagNames = (e['video_tags'] as List)
          .map((vt) => vt['tags']['name'] as String)
          .toList();
      return Video.fromSupabase(e, authorName, tagNames);
    }).toList();
  }

  /// Get related videos based on tags
  Future<List<Video>> getRelatedVideos(Video video, {int limit = 10}) async {
    try {
      if (video.tags.isEmpty) return [];

      final snapshot = await firestore
          .collection('videos')
          .where('tags', arrayContainsAny: video.tags.take(5).toList())
          .orderBy('createdAt', descending: true)
          .limit(limit + 1)
          .get();

      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).where((v) => v.id != video.id).take(limit).toList();
    } catch (e) {
      print('Error getting related videos: $e');
      return [];
    }
  }

  Future<List<Video>> getRelatedVideosSupabase(Video video, {int limit = 10}) async {
    if (video.tags.isEmpty) return [];

    final taggedVideoIds = await supabaseClient
        .from('video_tags')
        .select('video_id, tags!inner(name)')
        .inFilter('tags.name', video.tags.take(5).toList());

    final videoIds = taggedVideoIds
        .map((e) => e['video_id'])
        .where((id) => id.toString() != video.id)
        .toSet()
        .toList();

    if (videoIds.isEmpty) return [];

    final result = await supabaseClient
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
        .inFilter('id', videoIds)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return result.map<Video>((e) {
      final profile = e['profiles'] as Map<String, dynamic>;
      final authorName = profile['display_name'] ?? profile['username'] ?? '';
      final tags = (e['video_tags'] as List)
          .map((vt) => vt['tags']['name'] as String)
          .toList();
      return Video.fromSupabase(e, authorName, tags);
    }).toList();
  }

  Future<List<Video>> getSavedVideos(String userId, {int limit = 20}) async {
    try {
      final savedSnapshot = await firestore.collection('users').doc(userId).collection('saved_videos').orderBy('savedAt', descending: true).limit(limit).get();

      final videoIds = savedSnapshot.docs.map((doc) => doc.id).toList();

      if (videoIds.isEmpty) return [];

      final videos = <Video>[];
      for (final videoId in videoIds) {
        final videoDoc = await firestore.collection('videos').doc(videoId).get();

        if (videoDoc.exists) {
          videos.add(Video.fromFirestore(videoDoc));
        }
      }

      return videos;
    } catch (e) {
      print('Error getting saved videos: $e');
      return [];
    }
  }

  Future<List<Video>> getSavedVideosSupabase(String userId, {int limit = 20, int offset = 0}) async {
    final result = await supabaseClient
        .from('saved_videos')
        .select('''
        video_id,
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

    return result
        .where((e) => e['videos'] != null)
        .map((e) {
      final video = e['videos'] as Map<String, dynamic>;
      final profile = video['profiles'] as Map<String, dynamic>;
      final authorName = profile['display_name'] ?? profile['username'] ?? '';
      final tags = (video['video_tags'] as List)
          .map((vt) => vt['tags']['name'] as String)
          .toList();
      return Video.fromSupabase(video, authorName, tags);
    }).toList();
  }

  Future<List<Video>> fetchVideosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final videos = <Video>[];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      final snapshot = await FirebaseFirestore.instance.collection('videos').where(FieldPath.documentId, whereIn: chunk).get();
      videos.addAll(snapshot.docs.map((doc) => Video.fromFirestore(doc)));
    }
    return videos;
  }


  Future<List<Video>> fetchVideosByIdsSupabase(List<int> ids) async {
    if (ids.isEmpty) return [];

    final result = await supabaseClient
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
        .inFilter('id', ids);

    return result.map<Video>((e) {
      final profile = e['profiles'] as Map<String, dynamic>;
      final authorName = profile['display_name'] ?? profile['username'] ?? '';
      final tags = (e['video_tags'] as List)
          .map((vt) => vt['tags']['name'] as String)
          .toList();
      return Video.fromSupabase(e, authorName, tags);
    }).toList();
  }
}
