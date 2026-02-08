import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/logic/video/video.dart';
import 'dart:math';

class UserInteraction {
  final String videoId;
  final double watchTime; // in seconds
  final double videoDuration; // in seconds
  final bool liked;
  final bool shared;
  final bool commented;
  final bool saved;
  final DateTime timestamp;

  UserInteraction({
    required this.videoId,
    required this.watchTime,
    required this.videoDuration,
    this.liked = false,
    this.shared = false,
    this.commented = false,
    this.saved = false,
    required this.timestamp,
  });

  // Calculate engagement score based on completion rate
  double get completionRate => (watchTime / videoDuration).clamp(0.0, 1.0);

  double get engagementScore {
    double score = completionRate * 1.0;
    if (liked) score += 2.0;
    if (shared) score += 3.0;
    if (commented) score += 2.5;
    if (saved) score += 2.0;
    return score;
  }
}

class VideoScore {
  final String videoId;
  final double score;
  final Video video;

  VideoScore({
    required this.videoId,
    required this.score,
    required this.video,
  });
}

class VideoRecommender {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  // Algorithm parameters
  static const double _recencyWeight = 0.15;
  static const double _engagementWeight = 0.35;
  static const double _diversityWeight = 0.20;
  static const double _personalizedWeight = 0.30;
  static const int _candidatePoolSize = 100;
  static const int _recommendationBatchSize = 20;

  VideoRecommender({required this.userId});

  /// Main recommendation function
  Future<List<Video>> getRecommendedVideos({
    int limit = 20,
    List<String> excludeVideoIds = const [],
  }) async {
    try {
      // 1. Get user's interaction history
      final userInteractions = await _getUserInteractions();

      // 2. Build user profile from interactions
      final userProfile = _buildUserProfile(userInteractions);

      // 3. Get candidate videos
      final candidateVideos = await _getCandidateVideos(
        excludeIds: excludeVideoIds,
        limit: _candidatePoolSize,
      );

      // 4. Score each video
      final scoredVideos = _scoreVideos(
        candidateVideos,
        userProfile,
        userInteractions,
      );

      // 5. Apply diversity filter
      final diversifiedVideos = _applyDiversityFilter(scoredVideos);

      // 6. Return top N videos
      return diversifiedVideos.take(limit).map((vs) => vs.video).toList();
    } catch (e) {
      print('Error getting recommendations: $e');
      // Fallback to trending videos
      return _getTrendingVideos(limit);
    }
  }

  /// Get user's past interactions
  Future<List<UserInteraction>> _getUserInteractions() async {
    final snapshot = await _firestore
        .collection('user_interactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(200) // Last 200 interactions
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return UserInteraction(
        videoId: data['videoId'] ?? '',
        watchTime: (data['watchTime'] ?? 0).toDouble(),
        videoDuration: (data['videoDuration'] ?? 1).toDouble(),
        liked: data['liked'] ?? false,
        shared: data['shared'] ?? false,
        commented: data['commented'] ?? false,
        saved: data['saved'] ?? false,
        timestamp: (data['timestamp'] as Timestamp).toDate(),
      );
    }).toList();
  }

  /// Build user profile from interaction history
  Map<String, dynamic> _buildUserProfile(List<UserInteraction> interactions) {
    if (interactions.isEmpty) {
      return {
        'preferredTags': <String, double>{},
        'preferredAuthors': <String, double>{},
        'avgEngagementScore': 0.0,
      };
    }

    final tagScores = <String, double>{};
    final authorScores = <String, double>{};
    double totalEngagement = 0.0;

    for (final interaction in interactions) {
      final score = interaction.engagementScore;
      totalEngagement += score;

      // Note: In real implementation, you'd fetch video details here
      // For now, we'll handle this in the scoring phase
    }

    return {
      'preferredTags': tagScores,
      'preferredAuthors': authorScores,
      'avgEngagementScore': totalEngagement / interactions.length,
    };
  }

  /// Get candidate videos for recommendation
  Future<List<Video>> _getCandidateVideos({
    required List<String> excludeIds,
    required int limit,
  }) async {
    // Get recent videos (last 7 days)
    final weekAgo = DateTime.now().subtract(Duration(days: 7));

    final snapshot = await _firestore
        .collection('videos')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => Video.fromFirestore(doc))
        .where((video) => !excludeIds.contains(video.videoUrl))
        .toList();
  }

  /// Score videos based on multiple factors
  List<VideoScore> _scoreVideos(
      List<Video> videos,
      Map<String, dynamic> userProfile,
      List<UserInteraction> userInteractions,
      ) {
    final now = DateTime.now();
    final scoredVideos = <VideoScore>[];

    // Get videos user has already seen
    final seenVideoIds = userInteractions.map((i) => i.videoId).toSet();

    for (final video in videos) {
      double score = 0.0;

      // 1. Recency Score (newer is better)
      final ageInHours = now.difference(video.createdAt).inHours;
      final recencyScore = _calculateRecencyScore(ageInHours);
      score += recencyScore * _recencyWeight;

      // 2. Engagement Score (based on global metrics - would need to fetch from DB)
      final engagementScore = _calculateGlobalEngagementScore(video);
      score += engagementScore * _engagementWeight;

      // 3. Personalization Score (tags and author match)
      final personalizationScore = _calculatePersonalizationScore(
        video,
        userProfile,
      );
      score += personalizationScore * _personalizedWeight;

      // 4. Diversity Score (penalize similar content to recently seen)
      final diversityScore = _calculateDiversityScore(
        video,
        userInteractions,
        seenVideoIds,
      );
      score += diversityScore * _diversityWeight;

      // 5. Apply penalties
      if (seenVideoIds.contains(video.videoUrl)) {
        score *= 0.1; // Heavy penalty for already seen videos
      }

      scoredVideos.add(VideoScore(
        videoId: video.videoUrl,
        score: score,
        video: video,
      ));
    }

    // Sort by score descending
    scoredVideos.sort((a, b) => b.score.compareTo(a.score));
    return scoredVideos;
  }

  /// Calculate recency score (exponential decay)
  double _calculateRecencyScore(int ageInHours) {
    // Videos lose 50% score every 24 hours
    return exp(-0.029 * ageInHours); // ln(0.5)/24 ≈ -0.029
  }

  /// Calculate global engagement score
  double _calculateGlobalEngagementScore(Video video) {
    // In real implementation, fetch likes, shares, comments, views from DB
    // For now, return neutral score
    return 0.5;
  }

  /// Calculate personalization score based on user preferences
  double _calculatePersonalizationScore(
      Video video,
      Map<String, dynamic> userProfile,
      ) {
    final preferredTags = userProfile['preferredTags'] as Map<String, double>;
    final preferredAuthors = userProfile['preferredAuthors'] as Map<String, double>;

    if (preferredTags.isEmpty && preferredAuthors.isEmpty) {
      return 0.5; // Neutral score for new users
    }

    double score = 0.0;
    int factors = 0;

    // Tag matching
    if (video.tags.isNotEmpty && preferredTags.isNotEmpty) {
      double tagScore = 0.0;
      for (final tag in video.tags) {
        if (preferredTags.containsKey(tag)) {
          tagScore += preferredTags[tag]!;
        }
      }
      score += tagScore / video.tags.length;
      factors++;
    }

    // Author matching
    if (preferredAuthors.containsKey(video.authorId)) {
      score += preferredAuthors[video.authorId]!;
      factors++;
    }

    return factors > 0 ? score / factors : 0.5;
  }

  /// Calculate diversity score
  double _calculateDiversityScore(
      Video video,
      List<UserInteraction> recentInteractions,
      Set<String> seenVideoIds,
      ) {
    if (recentInteractions.isEmpty) return 1.0;

    // Get last 10 interactions for diversity check
    final recentTags = <String>{};
    final recentAuthors = <String>{};

    // Note: In real implementation, fetch video details for recent interactions
    // For now, we'll use a simplified approach

    // Penalize if tags or author are too similar to recent videos
    int similarityCount = 0;

    if (recentAuthors.contains(video.authorId)) {
      similarityCount++;
    }

    for (final tag in video.tags) {
      if (recentTags.contains(tag)) {
        similarityCount++;
      }
    }

    // Higher similarity = lower diversity score
    final maxSimilarity = 5;
    return 1.0 - (similarityCount / maxSimilarity).clamp(0.0, 1.0);
  }

  /// Apply diversity filter to prevent monotony
  List<VideoScore> _applyDiversityFilter(List<VideoScore> scoredVideos) {
    final result = <VideoScore>[];
    final usedAuthors = <String>{};
    final usedTagCombinations = <String>{};

    for (final videoScore in scoredVideos) {
      final video = videoScore.video;

      // Allow max 2 videos from same author in a batch
      final authorCount = result.where((v) => v.video.authorId == video.authorId).length;
      if (authorCount >= 2) continue;

      // Check tag diversity
      final tagKey = video.tags.toSet().toString();
      if (usedTagCombinations.contains(tagKey) && result.length > 5) {
        continue; // Skip if we have too many similar tag combinations
      }

      result.add(videoScore);
      usedAuthors.add(video.authorId);
      usedTagCombinations.add(tagKey);

      if (result.length >= _recommendationBatchSize) break;
    }

    return result;
  }

  /// Fallback: Get trending videos
  Future<List<Video>> _getTrendingVideos(int limit) async {
    final snapshot = await _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
  }

  /// Track user interaction
  Future<void> trackInteraction({
    required String videoId,
    required double watchTime,
    required double videoDuration,
    bool liked = false,
    bool shared = false,
    bool commented = false,
    bool saved = false,
  }) async {
    await _firestore.collection('user_interactions').add({
      'userId': userId,
      'videoId': videoId,
      'watchTime': watchTime,
      'videoDuration': videoDuration,
      'liked': liked,
      'shared': shared,
      'commented': commented,
      'saved': saved,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Cold start: Get videos for new users
  Future<List<Video>> getColdStartVideos({int limit = 20}) async {
    // Get popular videos from last 3 days
    final threeDaysAgo = DateTime.now().subtract(Duration(days: 3));

    final snapshot = await _firestore
        .collection('videos')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(threeDaysAgo))
        .orderBy('createdAt', descending: true)
        .limit(limit * 2) // Get more to have options
        .get();

    final videos = snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();

    // Shuffle for variety
    videos.shuffle();

    return videos.take(limit).toList();
  }
}