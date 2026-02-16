import 'dart:math';

import 'package:wurp/logic/feed_recommendation/user_interaction.dart';
import 'package:wurp/logic/feed_recommendation/user_preferences.dart';
import 'package:wurp/logic/feed_recommendation/video_recommender_base.dart';
import 'package:wurp/logic/video/video.dart';

class VideoScore {
  final double score;
  final Video video;

  VideoScore({required this.score, required this.video});
}


/// Optimized video recommender with preference-based system
class VideoRecommender extends VideoRecommenderBase {

  // Algorithm parameters
  static const double _recencyWeight = 0.15;
  static const double _engagementWeight = 0.40;
  static const double _diversityWeight = 0.15;
  static const double _personalizedWeight = 0.30;
  static const int _candidatePoolSize = 80;
  static const int _recommendationBatchSize = 10;
  
  VideoRecommender({required super.userId});



  /// Main recommendation function
  Future<List<Video>> getRecommendedVideos({int limit = 20, Set<String> excludeVideoIds = const {}}) async {
    
    print("getting recommendations for user $userId with limit $limit, excluding ${excludeVideoIds.length} videos...");
    
    try {
      // 1. Get user preferences
      final userPreferences = await getUserPreferences();
      
      // 2. Get recent interactions for diversity (limited to last N)
      final recentInteractions = await getRecentInteractions();
      
      // 3. Get candidate videos
      final candidateVideos = await _getCandidateVideos(excludeIds: excludeVideoIds, userPreferences: userPreferences, limit: _candidatePoolSize);
      
      print("Candidate videos for user $userId: ${candidateVideos.length} videos, sample: ${candidateVideos.take(5).map((v) => v.videoUrl).toList()}");

      // 4. Score each video
      final scoredVideos = _scoreVideos(candidateVideos, userPreferences, recentInteractions);
      
      // 5. Apply diversity filter
      final diversifiedVideos = _applyDiversityFilter(scoredVideos);
      
      print("Diversified videos for user $userId: ${diversifiedVideos.length} videos, sample: ${diversifiedVideos.take(5).map((vs) => {'videoUrl': vs.video.videoUrl, 'score': vs.score}).toList()}");

      // 6. Return top N videos
      return diversifiedVideos.take(limit).map((vs) => vs.video).toList();
    } catch (e) {
      print('Error getting recommendations: $e. stacktrace: ${StackTrace.current}');
      // Fallback to trending videos
      return getTrendingVideos(limit);
    }
  }
  
  
  /// Get candidate videos with smart filtering based on user preferences
  Future<List<Video>> _getCandidateVideos({
    required Set<String> excludeIds,
    required UserPreferences userPreferences,
    required int limit
  }) async {
    if (userPreferences.isNewUser) {
      print("New User! getting trending videos for user $userId...");
      return getTrendingVideos(limit);
    }

    if (userPreferences.tagPreferences.isNotEmpty) {
      final topTags = userPreferences.tagPreferences.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final preferredTags = topTags.take(10).map((e) => e.key).toList();

      print("Searching for videos with preferred tags: $preferredTags");

      final snapshot = await firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(limit * 3)
          .get();

      final videos = snapshot.docs
          .map((doc) => Video.fromFirestore(doc))
          .where((video) => !excludeIds.contains(video.id))
          .toList()
          ..sort((a, b) => _calculateGlobalEngagementScore(b).compareTo(_calculateGlobalEngagementScore(a)));

      if (videos.length >= limit * 0.1) {
        return videos.take(limit).toList();
      } else {
        print("Not enough videos from preferred tags, got ${videos.length}, need at least ${limit * 0.1}. Falling back to recency-based candidates.");
      }
    }

    print("Fallback: Getting recent videos...");
    final snapshot = await firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(limit * 2)
        .get();

    return snapshot.docs
        .map((doc) => Video.fromFirestore(doc))
        .where((video) => !excludeIds.contains(video.id))
        .take(limit)
        .toList();
  }

  /// Score videos based on multiple factors
  List<VideoScore> _scoreVideos(List<Video> videos, UserPreferences userPreferences, List<UserInteraction> recentInteractions) {
    final now = DateTime.now();
    final scoredVideos = <VideoScore>[];

    // Get videos user has recently seen
    final seenVideoIds = recentInteractions.map((i) => i.videoId).toSet();

    for (final video in videos) {
      double score = 0.0;

      // 1. Recency Score (newer is better)
      final ageInHours = now.difference(video.createdAt).inHours;
      final recencyScore = _calculateRecencyScore(ageInHours);
      score += recencyScore * _recencyWeight;

      // 2. Engagement Score (based on video metrics)
      final engagementScore = _calculateGlobalEngagementScore(video);
      score += engagementScore * _engagementWeight;

      // 3. Personalization Score (optimized with preferences)
      final personalizationScore = calculatePersonalizationScore(video, userPreferences);
      score += personalizationScore * _personalizedWeight;

      // 4. Diversity Score (penalize similar content to recently seen)
      final diversityScore = _calculateDiversityScore(video, recentInteractions, seenVideoIds);
      score += diversityScore * _diversityWeight;

      // 5. Apply penalties
      if (seenVideoIds.contains(video.id)) {
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

  /// Calculate global engagement score from video metrics
  double _calculateGlobalEngagementScore(Video video) {
    int views = video.viewsCount ?? 1;
    final likes = video.likesCount ?? 0;
    final shares = video.sharesCount ?? 0;
    final comments = video.commentsCount ?? 0;
    if(views == 0) views = 1; // Avoid division by zero

    final engagementRate = (likes + shares * 2 + comments * 1.5 + 1) / views;
    return (engagementRate * 100).clamp(0.0, 1.0);
  }

  /// Calculate diversity score to avoid echo chamber
  double _calculateDiversityScore(Video video, List<UserInteraction> recentInteractions, Set<String> seenVideoIds) {
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
  List<VideoScore> _applyDiversityFilter(List<VideoScore> scoredVideos) {
    final result = <VideoScore>[];
    final authorCount = <String, int>{};
    final tagCombinations = <String, int>{};

    for (final videoScore in scoredVideos) {
      final video = videoScore.video;

      // Allow max 2 videos from same author in a batch
      final currentAuthorCount = authorCount[video.authorId] ?? 0;
      final maxPerAuthor = (scoredVideos.length / 5).ceil();
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

      if (result.length >= _recommendationBatchSize) break;
    }

    return result;
  }
}
