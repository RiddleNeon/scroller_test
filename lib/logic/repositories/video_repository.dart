import 'package:wurp/logic/comments/comment.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

import '../../base_logic.dart';

VideoRepository videoRepo = VideoRepository();

class VideoRepository {
  Future<Video> getVideoById(String id) async {
    final video = await getVideoByIdSupabase(id);
    if (video == null) throw StateError('Video $id not found');
    return video;
  }

  Future<Video?> getVideoByIdSupabase(String id) async {
    final supabaseVid = await supabaseClient
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
        .maybeSingle();
    if (supabaseVid == null) return null;
    return _toVideo(supabaseVid);
  }

  Future<void> publishVideo({
    required String title,
    required String description,
    required String videoUrl,
    String? thumbnailUrl,
    required String authorId,
    List<String> tags = const [],
  }) async {
    await publishVideoSupabase(
      title: title,
      description: description,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      authorId: authorId,
      tags: tags,
    );
  }

  Future<void> publishVideoSupabase({
    required String title,
    required String description,
    required String videoUrl,
    String? thumbnailUrl,
    required String authorId,
    List<String> tags = const [],
  }) async {
    final publishedVideoId = (await supabaseClient
            .from('videos')
            .insert({
              'title': title,
              'description': description,
              'video_url': videoUrl,
              'thumbnail_url': thumbnailUrl,
              'author_id': authorId,
              'is_published': true,
            })
            .select('id')
            .single())['id'] as int;

    if (tags.isNotEmpty) {
      final upsertedTags = await supabaseClient.from('tags').upsert(
        tags.map((tag) => {'name': tag.toLowerCase()}).toList(),
        onConflict: 'name',
      ).select('id');

      final videoTags = upsertedTags.map((tag) => {'video_id': publishedVideoId, 'tag_id': tag['id']}).toList();
      await supabaseClient.from('video_tags').upsert(videoTags, onConflict: 'video_id, tag_id');
    }

    await _adjustProfileMetric(authorId, 'total_videos_count', 1);
  }

  Future<void> likeVideo(String userId, String videoId, String authorId) async {
    final parsedVideoId = _parseVideoId(videoId);
    final existing = await supabaseClient.from('likes').select().eq('user_id', userId).eq('video_id', parsedVideoId).maybeSingle();
    if (existing != null) return;

    final removedDislike = await supabaseClient.from('dislikes').delete().eq('user_id', userId).eq('video_id', parsedVideoId).select();
    if ((removedDislike as List).isNotEmpty) {
      await _adjustVideoMetric(parsedVideoId, 'dislike_count', -1);
    }

    await supabaseClient.from('likes').insert({'user_id': userId, 'video_id': parsedVideoId});
    await _adjustVideoMetric(parsedVideoId, 'like_count', 1);
    await _adjustProfileMetric(authorId, 'total_likes_count', 1);
  }

  Future<void> unlikeVideo(String userId, String videoId, String authorId) async {
    final parsedVideoId = _parseVideoId(videoId);
    final removed = await supabaseClient.from('likes').delete().eq('user_id', userId).eq('video_id', parsedVideoId).select();
    if ((removed as List).isEmpty) return;
    await _adjustVideoMetric(parsedVideoId, 'like_count', -1);
    await _adjustProfileMetric(authorId, 'total_likes_count', -1);
  }

  Future<void> dislikeVideo(String userId, String videoId) async {
    final parsedVideoId = _parseVideoId(videoId);
    final existing = await supabaseClient.from('dislikes').select().eq('user_id', userId).eq('video_id', parsedVideoId).maybeSingle();
    if (existing != null) return;

    final removedLikes = await supabaseClient.from('likes').delete().eq('user_id', userId).eq('video_id', parsedVideoId).select();
    if ((removedLikes as List).isNotEmpty) {
      final authorRow = await supabaseClient.from('videos').select('author_id').eq('id', parsedVideoId).single();
      await _adjustVideoMetric(parsedVideoId, 'like_count', -1);
      await _adjustProfileMetric(authorRow['author_id'] as String, 'total_likes_count', -1);
    }

    await supabaseClient.from('dislikes').insert({'user_id': userId, 'video_id': parsedVideoId});
    await _adjustVideoMetric(parsedVideoId, 'dislike_count', 1);
  }

  Future<void> undislikeVideo(String userId, String videoId) async {
    final parsedVideoId = _parseVideoId(videoId);
    final removed = await supabaseClient.from('dislikes').delete().eq('user_id', userId).eq('video_id', parsedVideoId).select();
    if ((removed as List).isEmpty) return;
    await _adjustVideoMetric(parsedVideoId, 'dislike_count', -1);
  }

  Future<void> incrementViewCount(String videoId) async {
    await recordViewSupabase(_parseVideoId(videoId));
  }

  Future<void> recordViewSupabase(int videoId) async {
    await _adjustVideoMetric(videoId, 'view_count', 1);
  }

  Future<void> incrementShareCount(String videoId) async {
    await incrementShareCountSupabase(_parseVideoId(videoId));
  }

  Future<void> incrementShareCountSupabase(int videoId) async {
    await _adjustVideoMetric(videoId, 'share_count', 1);
  }

  Future<void> addComment(String videoId, Comment comment) async {
    await postCommentSupabase(
      userId: comment.userId,
      videoId: _parseVideoId(videoId),
      content: comment.message,
      parentId: comment.parentId == null ? null : int.tryParse(comment.parentId!),
    );
  }

  Future<Comment> postCommentSupabase({
    required String userId,
    required int videoId,
    required String content,
    int? parentId,
  }) async {
    final inserted = await supabaseClient.from('comments').insert({
      'author_id': userId,
      'video_id': videoId,
      'content': content,
      'parent_id': parentId,
    }).select('id, created_at').single();

    if (parentId != null) {
      await _adjustCommentMetric(parentId, 'reply_count', 1);
    }
    await _adjustVideoMetric(videoId, 'comment_count', 1);

    final profile = await supabaseClient.from('profiles').select('username, avatar_url').eq('id', userId).single();
    return Comment(
      id: inserted['id'].toString(),
      userId: userId,
      username: profile['username'] as String? ?? currentAuthUsername(),
      userProfileImageUrl: profile['avatar_url'] as String? ?? '',
      message: content,
      date: DateTime.parse(inserted['created_at'] as String).toLocal(),
      parentId: parentId?.toString(),
      depth: parentId == null ? 0 : 1,
      replyCount: 0,
    );
  }

  Future<({List<Comment> comments, int? nextOffset})> getComments(
    String videoId, {
    String? commentId,
    int offset = 0,
    int limit = 20,
  }) async {
    final comments = await getCommentsSupabase(
      videoId,
      parentCommentId: commentId == null ? null : int.tryParse(commentId),
      limit: limit,
      offset: offset,
    );
    return (comments: comments, nextOffset: comments.length < limit ? null : offset + comments.length);
  }

  Future<List<Comment>> getCommentsSupabase(String videoId, {int? parentCommentId, int limit = 20, int offset = 0}) async {
    dynamic baseQuery = supabaseClient
        .from('comments')
        .select('''
          *,
          profiles (
            username,
            avatar_url
          )
        ''')
        .eq('video_id', _parseVideoId(videoId));

    if (parentCommentId == null) {
      baseQuery = baseQuery.isFilter('parent_id', null);
    } else {
      baseQuery = baseQuery.eq('parent_id', parentCommentId);
    }

    final result = await baseQuery.order('created_at', ascending: false).range(offset, offset + limit - 1);
    return result.map<Comment>((entry) => Comment.fromSupabase(entry)).toList();
  }

  Future<void> saveVideo(String userId, String videoId) async => saveVideoSupabase(userId, _parseVideoId(videoId));

  Future<void> saveVideoSupabase(String userId, int videoId) async {
    await supabaseClient.from('saved_videos').upsert(
      {'user_id': userId, 'video_id': videoId},
      onConflict: 'user_id, video_id',
    );
  }

  Future<void> unsaveVideo(String userId, String videoId) async => unsaveVideoSupabase(userId, _parseVideoId(videoId));

  Future<void> unsaveVideoSupabase(String userId, int videoId) async {
    await supabaseClient.from('saved_videos').delete().eq('user_id', userId).eq('video_id', videoId);
  }

  Future<void> reportVideo(String userId, String videoId, String reason) async => reportVideoSupabase(userId, _parseVideoId(videoId), reason);

  Future<void> reportVideoSupabase(String userId, int videoId, String reason) async {
    await supabaseClient.from('video_reports').insert({
      'user_id': userId,
      'video_id': videoId,
      'reason': reason,
      'status': 'pending',
    });
  }

  Future<void> flush() async {}

  int get pendingOperations => 0;

  Future<List<Video>> getFollowingFeed(String userId, {int limit = 20}) async {
    return getFollowingFeedSupabase(userId, limit: limit);
  }

  Future<List<Video>> getFollowingFeedSupabase(String userId, {int limit = 20, int offset = 0}) async {
    final followingIds = (await supabaseClient.from('follows').select('following_id').eq('follower_id', userId))
        .map((e) => e['following_id'] as String)
        .toList();
    if (followingIds.isEmpty) return [];

    final result = await supabaseClient
        .from('videos')
        .select(_videoSelect)
        .inFilter('author_id', followingIds)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return result.map<Video>(_toVideo).toList();
  }

  Future<List<Video>> getTrendingVideos({int limit = 20}) async => getTrendingVideosSupabase(limit: limit);

  Future<List<Video>> getTrendingVideosSupabase({int limit = 20}) async {
    final result = await supabaseClient
        .from('videos')
        .select(_videoSelect)
        .eq('is_published', true)
        .gte('created_at', DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
        .order('view_count', ascending: false)
        .limit(limit);
    return result.map<Video>(_toVideo).toList();
  }

  Future<({List<Video> videos, int? nextOffset})> searchVideos(String query, {int limit = 20, int offset = 0}) async {
    final videos = await searchVideosSupabase(query, limit: limit, offset: offset);
    return (videos: videos, nextOffset: videos.length < limit ? null : offset + videos.length);
  }

  Future<List<Video>> searchVideosSupabase(String query, {int limit = 20, int offset = 0}) async {
    final result = await supabaseClient
        .from('videos')
        .select(_videoSelect)
        .eq('is_published', true)
        .or('title.ilike.%$query%,description.ilike.%$query%')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return result.map<Video>(_toVideo).toList();
  }

  Future<({List<Video> videos, int? nextOffset})> searchVideosByTag(String tag, {int limit = 20, int offset = 0}) async {
    final videos = await searchVideosByTagSupabase(tag, limit: limit, offset: offset);
    return (videos: videos, nextOffset: videos.length < limit ? null : offset + videos.length);
  }

  Future<List<Video>> searchVideosByTagSupabase(String tag, {int limit = 20, int offset = 0}) async {
    final result = await supabaseClient
        .from('video_tags')
        .select('''
          videos (
            $_videoSelectInner
          ),
          tags!inner(name)
        ''')
        .eq('tags.name', tag)
        .range(offset, offset + limit - 1);

    return result.where((e) => e['videos'] != null).map((e) => _toVideo(e['videos'] as Map<String, dynamic>)).toList();
  }

  Future<List<Video>> getVideosByTags(List<String> tags, {int limit = 20}) async {
    return getVideosByTagsSupabase(tags, limit: limit);
  }

  Future<List<Video>> getVideosByTagsSupabase(List<String> tags, {int limit = 20, int offset = 0}) async {
    final taggedVideoIds = await supabaseClient.from('video_tags').select('video_id, tags!inner(name)').inFilter('tags.name', tags);
    final videoIds = taggedVideoIds.map((e) => e['video_id']).toSet().toList();
    if (videoIds.isEmpty) return [];

    final result = await supabaseClient
        .from('videos')
        .select(_videoSelect)
        .inFilter('id', videoIds)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return result.map<Video>(_toVideo).toList();
  }

  Future<List<Video>> getRelatedVideos(Video video, {int limit = 10}) async => getRelatedVideosSupabase(video, limit: limit);

  Future<List<Video>> getRelatedVideosSupabase(Video video, {int limit = 10}) async {
    if (video.tags.isEmpty) return [];
    final taggedVideoIds = await supabaseClient
        .from('video_tags')
        .select('video_id, tags!inner(name)')
        .inFilter('tags.name', video.tags.take(5).toList());
    final videoIds = taggedVideoIds.map((e) => e['video_id']).where((id) => id.toString() != video.id).toSet().toList();
    if (videoIds.isEmpty) return [];

    final result = await supabaseClient
        .from('videos')
        .select(_videoSelect)
        .inFilter('id', videoIds)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return result.map<Video>(_toVideo).toList();
  }

  Future<List<Video>> getSavedVideos(String userId, {int limit = 20}) async => getSavedVideosSupabase(userId, limit: limit);

  Future<List<Video>> getSavedVideosSupabase(String userId, {int limit = 20, int offset = 0}) async {
    final result = await supabaseClient
        .from('saved_videos')
        .select('''
          video_id,
          videos (
            $_videoSelectInner
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return result.where((e) => e['videos'] != null).map((e) => _toVideo(e['videos'] as Map<String, dynamic>)).toList();
  }

  Future<List<Video>> fetchVideosByIds(List<String> ids) async {
    final parsedIds = ids.map(int.tryParse).whereType<int>().toList();
    return fetchVideosByIdsSupabase(parsedIds);
  }

  Future<List<Video>> fetchVideosByIdsSupabase(List<int> ids) async {
    if (ids.isEmpty) return [];
    final result = await supabaseClient.from('videos').select(_videoSelect).inFilter('id', ids);
    return result.map<Video>(_toVideo).toList();
  }

  Future<void> _adjustVideoMetric(int videoId, String column, int delta) async {
    await supabaseClient.rpc('increment_video_metric', params: {'p_video_id': videoId, 'p_column': column, 'p_delta': delta});
  }

  Future<void> _adjustProfileMetric(String userId, String column, int delta) async {
    await supabaseClient.rpc('increment_profile_metric', params: {'p_user_id': userId, 'p_column': column, 'p_delta': delta});
  }

  Future<void> _adjustCommentMetric(int commentId, String column, int delta) async {
    await supabaseClient.rpc('increment_comment_metric', params: {'p_comment_id': commentId, 'p_column': column, 'p_delta': delta});
  }

  Video _toVideo(Map<String, dynamic> data) {
    final profile = (data['profiles'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final authorName = profile['display_name'] ?? profile['username'] ?? '';
    final tags = (data['video_tags'] as List? ?? const [])
        .map((vt) => vt['tags']?['name'] as String?)
        .whereType<String>()
        .toList();
    return Video.fromSupabase(data, authorName, tags);
  }

  int _parseVideoId(String videoId) {
    final parsedVideoId = int.tryParse(videoId);
    if (parsedVideoId == null) {
      throw FormatException('Expected numeric Supabase video id, got: $videoId');
    }
    return parsedVideoId;
  }
}

const String _videoSelectInner = '''
  *,
  profiles (
    display_name,
    username,
    avatar_url,
    followers_count,
    following_count,
    total_videos_count,
    total_likes_count,
    created_at,
    bio,
    id
  ),
  video_tags (
    tags (
      name
    )
  )
''';

const String _videoSelect = _videoSelectInner;
