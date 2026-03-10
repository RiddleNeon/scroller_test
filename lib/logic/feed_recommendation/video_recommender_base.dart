import 'dart:math' hide log;

import 'package:wurp/logic/feed_recommendation/user_interaction.dart';
import 'package:wurp/logic/feed_recommendation/user_preference_manager.dart';
import 'package:wurp/logic/feed_recommendation/user_preferences.dart';

import '../../tools/supabase_tests/supabase_login_test.dart';
import '../local_storage/local_seen_service.dart';
import '../repositories/video_repository.dart';
import '../video/video.dart';

abstract class VideoRecommenderBase {
  late final UserPreferenceManager preferenceManager;

  VideoRecommenderBase() {
    preferenceManager = UserPreferenceManager();
  }

  Future<UserPreferences> getUserPreferences() async {
    await preferenceManager.loadCache();
    return UserPreferences(
      tagPreferences: preferenceManager.cachedTagPrefs.map((k, v) => MapEntry(k, v.engagementScore)),
      authorPreferences: preferenceManager.cachedAuthorPrefs.map((k, v) => MapEntry(k, v.engagementScore)),
      avgCompletionRate: preferenceManager.cachedAvgCompletion,
      totalInteractions: preferenceManager.cachedTotalInteractions,
    );
  }

  double calculatePersonalizationScore(Video video, UserPreferences userPreferences) {
    final preferredTags = userPreferences.tagPreferences;
    final preferredAuthors = userPreferences.authorPreferences;
    if (preferredTags.isEmpty && preferredAuthors.isEmpty) return 0.5;

    double score = 0.0;
    int factors = 0;

    if (video.tags.isNotEmpty && preferredTags.isNotEmpty) {
      double tagScore = 0.0;
      int matchedTags = 0;
      for (final tag in video.tags) {
        if (preferredTags.containsKey(tag)) {
          tagScore += preferredTags[tag]!;
          matchedTags++;
        }
      }
      if (matchedTags > 0) {
        score += tagScore / matchedTags;
        factors++;
      }
    }

    if (preferredAuthors.containsKey(video.authorId)) {
      score += preferredAuthors[video.authorId]!;
      factors++;
    }

    return factors > 0 ? (score / factors) : 0.5;
  }

  Future<List<Video>> getColdStartVideos({int limit = 20}) async {
    final videos = await videoRepo.getTrendingVideos(limit: limit * 2);
    videos.shuffle();
    return videos.take(limit).toList();
  }

  Future<List<Video>> fetchNewVideos(DateTime? newestSeen, int limit) async {
    dynamic query = supabaseClient
        .from('videos')
        .select(_recommenderVideoSelect)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(limit);
    if (newestSeen != null) {
      query = query.lt('created_at', newestSeen.toIso8601String());
    }
    final snapshot = await query;
    return snapshot.map<Video>(_mapVideo).toList();
  }

  Future<List<Video>> fetchOldVideos(DateTime? oldestSeen, int limit) async {
    return fetchNewVideos(oldestSeen, limit);
  }

  Future<Set<Video>> fetchTrendingVideos({
    DateTime? cursor,
    required int limit,
  }) async {
    cursor ??= localSeenService.getTrendingCursor();
    dynamic query = supabaseClient
        .from('videos')
        .select(_recommenderVideoSelect)
        .eq('is_published', true)
        .gte('created_at', DateTime.now().subtract(const Duration(days: 40)).toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit * 3);

    if (cursor != null) {
      query = query.lt('created_at', cursor.toIso8601String());
    }

    final snapshot = await query;
    final videos = snapshot.map<Video>(_mapVideo).where((v) => !localSeenService.hasSeen(v.id)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (videos.isNotEmpty) {
      await localSeenService.saveTrendingCursor(videos.first.createdAt);
    }

    videos.sort((a, b) => calculateGlobalEngagementScore(b).compareTo(calculateGlobalEngagementScore(a)));
    return videos.take(limit).toSet();
  }

  static const _maxRetryAttempts = 5;

  Future<List<Video>> fetchVideosByTag(String tag, {required int limit, required void Function() onTagVideosEmpty}) async {
    final List<Video> unseen = [];
    DateTime? cursor = localSeenService.getTagCursor(tag);

    int attempts = 0;
    while (unseen.length < limit && attempts < _maxRetryAttempts) {
      final videos = await videoRepo.searchVideosByTagSupabase(tag, limit: limit * 2, offset: attempts * limit * 2);
      if (videos.isEmpty) break;

      unseen.addAll(videos.where((v) => !localSeenService.hasSeen(v.id)));

      final lastCountingIndex = min(videos.length - 1, limit);
      cursor = videos.elementAtOrNull(lastCountingIndex)?.createdAt;
      attempts++;
    }

    if (cursor != null) {
      await localSeenService.saveTagCursor(tag, cursor);
    }

    if (unseen.isEmpty) {
      onTagVideosEmpty();
    }

    return unseen.take(limit).toList();
  }

  double calculateGlobalEngagementScore(Video video) {
    int views = video.viewsCount ?? 1;
    final likes = video.likesCount ?? 0;
    final comments = video.commentsCount ?? 0;
    if (views == 0) views = 1;

    final engagementRate = (likes + comments * 1.5 + 1) / views;
    return (engagementRate * 100).clamp(0.0, 1.0);
  }
}

Future<void> trackInteraction({
  required String userId,
  required Video video,
  required double watchTime,
  required double videoDuration,
  bool liked = false,
  bool disliked = false,
  bool shared = false,
  bool commented = false,
  bool saved = false,
}) async {
  await UserPreferenceManager().updatePreferences(
    video: video,
    normalizedEngagementScore: calculateNormalizedEngagementScore(
      calculateEngagementScore(
        liked: liked,
        disliked: disliked,
        shared: shared,
        commented: commented,
        saved: saved,
        completionRate: watchTime / videoDuration,
      ),
    ),
  );
}

Video _mapVideo(Map<String, dynamic> data) {
  final profile = (data['profiles'] as Map<String, dynamic>? ?? const {});
  final authorName = profile['display_name'] ?? profile['username'] ?? '';
  final tags = (data['video_tags'] as List? ?? const [])
      .map((vt) => vt['tags']?['name'] as String?)
      .whereType<String>()
      .toList();
  return Video.fromSupabase(data, authorName, tags);
}

const String _recommenderVideoSelectInner = '''
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
''';

const String _recommenderVideoSelect = _recommenderVideoSelectInner;
