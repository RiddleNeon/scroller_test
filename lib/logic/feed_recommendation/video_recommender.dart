import 'dart:math';

import 'package:wurp/logic/feed_recommendation/user_interaction.dart';
import 'package:wurp/logic/feed_recommendation/user_preferences.dart';
import 'package:wurp/logic/feed_recommendation/video_recommender_base.dart';
import 'package:wurp/logic/video/video.dart';

import '../../util/misc/lists.dart';
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
  static const double _diversityWeight = 0.1;
  static const double _personalizedWeight = 0.50;
  static const int _candidatePoolSize = 50;

  VideoRecommender({required super.userId});

  /// Main recommendation function
  Future<Set<Video>> getRecommendedVideos({int limit = 20}) async {
    try {
      // Get user preferences
      final userPreferences = await getUserPreferences();

      // Get recent interactions for diversity (limited to last N)
      final recentInteractions = await LocalSeenService.getRecentInteractionsLocal();

      final candidateVideos = await _getCandidateVideos(userPreferences: userPreferences, limit: _candidatePoolSize);
      
      print("got ${candidateVideos.length} videos!");

      final scoredVideos = _scoreVideos(candidateVideos, userPreferences, recentInteractions);

      final diversifiedVideos = _applyDiversityFilter(scoredVideos, limit: limit);

      if (diversifiedVideos.isEmpty) {
        print("no more videos!");
        return getTrendingVideos(limit);
      }

      return (diversifiedVideos.take(limit).map((vs) => vs.video).toList()..shuffle()).toSet();
    } catch (e) {
      print('Error getting recommendations: $e. stacktrace: ${StackTrace.current}');
      // Fallback to trending videos
      return getTrendingVideos(limit);
    }
  }

  /// Get candidate videos with smart filtering based on user preferences
  Future<Set<Video>> _getCandidateVideos({
    required UserPreferences userPreferences,
    required int limit,
  }) async {
    if (userPreferences.isNewUser) return getTrendingVideos(limit);

    final Set<Video> candidates = {};

    final topTags = _getTopTags(userPreferences, 3);
    print("top tags for user: ${topTags}");
    for (final tag in topTags) {
      final tagVideos = await fetchVideosByTag(tag, limit: limit ~/ 3);
      candidates.addAll(tagVideos);
    }

    final newestTimestamp = LocalSeenService.getNewestSeenTimestamp();
    final newVideos = await fetchNewVideos(newestTimestamp, limit ~/ 2);
    print("${newVideos.length} new videos available");
    print("${newVideos.where((v) => !LocalSeenService.hasSeen(v.id)).length} new videos added");
    final filteredNewVideos = newVideos.where((v) => !LocalSeenService.hasSeen(v.id));
    if (filteredNewVideos.isNotEmpty) {
      candidates.addAll(filteredNewVideos);
      LocalSeenService.saveNewestSeenTimestamp(filteredNewVideos.last.createdAt);
    }

    if (candidates.length < limit) {
      final trending = await fetchTrendingVideos(limit: limit ~/ 4);
      candidates.addAll(trending.where((v) => !LocalSeenService.hasSeen(v.id)));
    }

    return removeDuplicates<Video>(candidates.toList(), getCheckedParameter: (vid) => vid.videoUrl).toSet();
  }

  List<String> _getTopTags(UserPreferences prefs, int count) {
    final sorted = prefs.tagPreferences.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(count).map((e) => e.key).toList();
  }

  /// Score videos based on multiple factors
  List<VideoScore> _scoreVideos(Set<Video> videos, UserPreferences userPreferences, List<UserInteraction> recentInteractions) {
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

      // 4. Diversity Score (penalize similar content to recently seen)
      final diversityScore = _calculateDiversityScore(video, recentInteractions);
      score += diversityScore * _diversityWeight;

      // 5. Apply penalties
      if (LocalSeenService.hasSeen(video.id)) {
        score *= 0.1; // Heavy penalty for already seen videos
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

  /// Calculate diversity score to avoid echo chamber
  double _calculateDiversityScore(Video video, List<UserInteraction> recentInteractions) {
    if (recentInteractions.isEmpty) return 1.0;

    final recentTags = <String>{};
    final recentAuthors = <String>{};

    for (final interaction in recentInteractions.take(10)) {
      recentTags.addAll(interaction.tags);
      recentAuthors.add(interaction.authorId);
    }

    int similarityCount = 0;

    if (recentAuthors.contains(video.authorId)) {
      similarityCount += 2;
    }

    for (final tag in video.tags) {
      if (recentTags.contains(tag)) {
        similarityCount++;
      }
    }

    final maxSimilarity = 5;
    return 1.0 - (similarityCount / maxSimilarity).clamp(0.0, 1.0);
  }

  /// Apply diversity filter to prevent monotony
  List<VideoScore> _applyDiversityFilter(List<VideoScore> scoredVideos, {int limit = 20}) {
    final result = <VideoScore>[];
    final authorCount = <String, int>{};
    final tagCombinations = <String, int>{};

    for (final videoScore in scoredVideos) {
      final video = videoScore.video;

      // Allow max 2 videos from same author in a batch
      final currentAuthorCount = authorCount[video.authorId] ?? 0;
      const int maxPerAuthor = 2; //todo dynamic better
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
