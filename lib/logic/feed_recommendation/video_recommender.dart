import 'dart:math';

import 'package:wurp/logic/feed_recommendation/user_preferences.dart';
import 'package:wurp/logic/feed_recommendation/video_recommender_base.dart';
import 'package:wurp/logic/video/video.dart';

import '../local_storage/local_seen_service.dart';

class VideoScore {
  final double score;
  final Video video;

  VideoScore({required this.score, required this.video});
}

/// Optimized video recommender with preference-based system
class VideoRecommender extends VideoRecommenderBase {
  // Algorithm parameters
  static const double _recencyWeight = 0.1;
  static const double _engagementWeight = 0.30;
  static const double _personalizedWeight = 0.50;
  static const int _candidatePoolSize = 50;

  VideoRecommender();

  /// Main recommendation function
  Future<Set<Video>> getRecommendedVideos({int limit = 20, bool useYoutubeVideos = false}) async {
    try {
      // Get user preferences
      //final userPreferences = await getUserPreferences();
      
      final candidateVideos = await _getCandidateVideos(limit: _candidatePoolSize, useYoutubeVids: useYoutubeVideos);

      //final scoredVideos = _scoreVideos(candidateVideos, userPreferences);

      //final diversifiedVideos = _applyDiversityFilter(scoredVideos, limit: limit);

      return (candidateVideos.take(limit).map((vs) => vs).toList()..shuffle()).toSet();
    } catch (e) {
      print('Error getting recommendations: $e. stacktrace: ${StackTrace.current}');
      // Fallback to trending videos
      return fetchTrendingVideos(limit: limit);
    }
  }

  /// Get candidate videos with smart filtering based on user preferences
  Future<Set<Video>> _getCandidateVideos({required int limit, bool useYoutubeVids = false}) async {
    return fetchTrendingVideos(limit: limit, onlyUnseen: true, useYoutubeVids: useYoutubeVids);

    /*final Set<Video> candidates = {}; // old code, can be optimized by fetching directly into a set and avoiding duplicates early on

    final topTags = _getTopTags(userPreferences, 3);
    print("top tags for user: $topTags");
    for (final tag in topTags) {
      final tagVideos = await fetchVideosByTag(
        tag,
        limit: limit ~/ 3,
        onlyUnseen: true,
        onTagVideosEmpty: () {
          localSeenService.saveBlacklistedTag(tag, DateTime.now());
          blacklistedTags?.add(tag);
          print("tag videos empty! removing $tag");
        },
      );
      print("fetched ${tagVideos.length} videos for tag $tag");
      candidates.addAll(tagVideos);
    }

    final newestTimestamp = localSeenService.getNewestSeenTimestamp();
    final newVideos = await fetchNewVideos(newestTimestamp, (limit - candidates.length) + 10, onlyUnseen: true);
    print("fetched ${newVideos.length} new videos since $newestTimestamp");
    
    final filteredNewVideos = newVideos.where((v) => !localSeenService.hasSeen(v.id)).toList();
    if (filteredNewVideos.isNotEmpty) {
      print("adding ${filteredNewVideos.length} new videos to candidates");
      candidates.addAll(filteredNewVideos);
      localSeenService.saveNewestSeenTimestamp((filteredNewVideos..sort((a, b) => a.createdAt.compareTo(b.createdAt))).last.createdAt);
    }

    if (candidates.length < limit) {
      final trending = await fetchTrendingVideos(limit: limit ~/ 4, onlyUnseen: true);
      print("fetched ${trending.length} trending videos for diversity");
      candidates.addAll(trending);
    }

    return removeDuplicates<Video>(candidates.toList(), getCheckedParameter: (vid) => vid.videoUrl).toSet();*/
  }

  List<String>? blacklistedTags;

  List<String> getTopTags(UserPreferences prefs, int count) {
    blacklistedTags ??= localSeenService.getBlacklistedTags();
    final sorted = prefs.tagPreferences.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return (sorted.where((element) => !blacklistedTags!.contains(element.key)).take(count).map((e) => e.key).toList());
  }

  /// Score videos based on multiple factors
  List<VideoScore> scoreVideos(Set<Video> videos, UserPreferences userPreferences) {
    final now = DateTime.now();
    final scoredVideos = <VideoScore>[];

    for (final video in videos) {
      double score = 0.0;

      // 1. Recency Score (newer is better)
      final ageInHours = now.difference(video.createdAt).inHours;
      final recencyScore = _calculateRecencyScore(ageInHours);
      score += recencyScore * _recencyWeight;

      // 2. Engagement Score (based on video metrics)
      final engagementScore = calculateGlobalEngagementScore(video);
      score += engagementScore * _engagementWeight;

      // 3. Personalization Score (optimized with preferences)
      final personalizationScore = calculatePersonalizationScore(video, userPreferences);
      score += personalizationScore * _personalizedWeight;
      
      // 5. Apply penalties
      if (localSeenService.hasSeen(video.id)) {
        score = 0; // Heavy penalty for already seen videos
      }

      scoredVideos.add(VideoScore(score: score, video: video));
    }

    // Sort by score descending
    scoredVideos.sort((a, b) => b.score.compareTo(a.score));
    return scoredVideos;
  }

  /// Calculate recency score (exponential decay)
  double _calculateRecencyScore(int ageInHours) {
    // Videos lose 50% score every 24 hours
    return exp(-0.029 * ageInHours);
  }

  /// Apply diversity filter to prevent monotony
  List<VideoScore> applyDiversityFilter(List<VideoScore> scoredVideos, {int limit = 20}) {
    final result = <VideoScore>[];
    final authorCount = <String, int>{};
    final tagCombinations = <String, int>{};

    for (final videoScore in scoredVideos) {
      final video = videoScore.video;

      // Allow max 2 videos from same author in a batch
      final currentAuthorCount = authorCount[video.authorId] ?? 0;
      const int maxPerAuthor = 10; //todo dynamic better
      if (currentAuthorCount >= maxPerAuthor) continue;

      // Check tag diversity (don't repeat same tag combinations too often)
      final tagKey = video.tags.toSet().toString();
      final currentTagCount = tagCombinations[tagKey] ?? 0;
      if (currentTagCount >= 1 && result.length > 5) {
        continue; // Skip if we already have this tag combination
      }

      result.add(videoScore);
      authorCount[video.authorId] = currentAuthorCount + 1;
      tagCombinations[tagKey] = currentTagCount + 1;

      if (result.length >= limit) break;
    }

    return result;
  }
}
