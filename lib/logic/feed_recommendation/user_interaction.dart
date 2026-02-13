import 'package:wurp/logic/feed_recommendation/user_preference_manager.dart';

/// Represents a single user interaction with a video
class UserInteraction {
  final String videoId;
  final String authorId;
  final List<String> tags;
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
    required this.authorId,
    required this.tags,
  });

  /// Calculate engagement score based on completion rate
  double get completionRate => (watchTime / videoDuration).clamp(0.0, 2.0);

  double get engagementScore {
    double score = completionRate * 2.5;
    if (liked) score += 3.5;
    if (shared) score += 4.0;
    if (commented) score += 3.5;
    if (saved) score += 3.0;
    return score;
  }

  /// Normalize engagement score to 0-1 range for preference updates
  double get normalizedEngagementScore {
    // Max possible score: 1.0 (completion) + 2.0 + 3.0 + 2.5 + 2.0 = 10.5
    return (engagementScore / UserPreferenceManager.defaultMaxEngagementScore).clamp(0.0, 1.0);
  }

  @override
  String toString() {
    return 'UserInteraction(videoId: $videoId, authorId: $authorId, tags: $tags, watchTime: $watchTime, videoDuration: $videoDuration, liked: $liked, shared: $shared, commented: $commented, saved: $saved, timestamp: $timestamp)';
  }
}