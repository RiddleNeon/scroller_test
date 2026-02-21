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
  final DateTime? timestamp;

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

  double get engagementScore => calculateEngagementScore(liked: liked, shared: shared, commented: commented, saved: saved, completionRate: completionRate);

  double get normalizedEngagementScore => calculateNormalizedEngagementScore(engagementScore);

  @override
  String toString() {
    return 'UserInteraction(videoId: $videoId, authorId: $authorId, tags: $tags, watchTime: $watchTime, videoDuration: $videoDuration, liked: $liked, shared: $shared, commented: $commented, saved: $saved, timestamp: $timestamp)';
  }
}

double calculateEngagementScore({required bool liked, required bool shared, required bool commented, required bool saved, required double completionRate}) {
  double score = completionRate * 10.0;

  if (liked) score += 5.0;
  if (shared) score += 6.0;
  if (commented) score += 5.0;
  if (saved) score += 4.0;

  return score;
}
const _maxScore = 30.0; // 10 + 5 + 6 + 5 + 4
double calculateNormalizedEngagementScore(double engagementScore) => (engagementScore / _maxScore).clamp(0.0, 1.0);