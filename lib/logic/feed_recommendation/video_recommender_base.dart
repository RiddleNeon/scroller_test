import 'dart:developer';
import 'dart:math' hide log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/logic/feed_recommendation/user_interaction.dart';
import 'package:wurp/logic/feed_recommendation/user_preference_manager.dart';
import 'package:wurp/logic/feed_recommendation/user_preferences.dart';

import '../../main.dart';
import '../batches/batch_service.dart';
import '../local_storage/local_seen_service.dart';
import '../video/video.dart';

abstract class VideoRecommenderBase {
  final String userId;
  late final UserPreferenceManager preferenceManager;

  VideoRecommenderBase({required this.userId}) {
    preferenceManager = UserPreferenceManager(userId: userId);
  }

  /// Get user preferences
  Future<UserPreferences> getUserPreferences() async {
    await preferenceManager.loadCache();
    return UserPreferences(
      tagPreferences: preferenceManager.cachedTagPrefs.map((k, v) => MapEntry(k, v.engagementScore)),
      authorPreferences: preferenceManager.cachedAuthorPrefs.map((k, v) => MapEntry(k, v.engagementScore)),
      avgCompletionRate: preferenceManager.cachedAvgCompletion,
      totalInteractions: preferenceManager.cachedTotalInteractions,
    );
  }

  /// Track user interaction and update preferences
  Future<void> trackInteraction({
    required Video video,
    required double watchTime,
    required double videoDuration,
    bool liked = false,
    bool disliked = false,
    bool shared = false,
    bool commented = false,
    bool saved = false,
  }) async {
    LocalSeenService.markAsSeen(video);

    final interactionRef = firestore.collection('users').doc(userId).collection('recent_interactions').doc();

    interactionRef.batchSet({
      'videoId': video.id,
      'watchTime': watchTime,
      'videoDuration': videoDuration,
      'liked': liked,
      'disliked': disliked,
      'shared': shared,
      'commented': commented,
      'saved': saved,
      'timestamp': FieldValue.serverTimestamp(),
      'authorId': video.authorId,
      'tags': video.tags,
    });
    // 2. Update user preferences (batched)
    await preferenceManager.updatePreferences(
        video: video,
        normalizedEngagementScore: calculateNormalizedEngagementScore(
            calculateEngagementScore(liked: liked, disliked: disliked, shared: shared, commented: commented, saved: saved, completionRate: watchTime / videoDuration)));
  }

  /// Calculate personalization score
  double calculatePersonalizationScore(Video video, UserPreferences userPreferences) {
    final preferredTags = userPreferences.tagPreferences;
    final preferredAuthors = userPreferences.authorPreferences;

    // New users or users without preferences get neutral score
    if (preferredTags.isEmpty && preferredAuthors.isEmpty) {
      return 0.5;
    }

    double score = 0.0;
    int factors = 0;

    // Tag matching (weighted by preference strength)
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
        // Average score of matched tags
        score += tagScore / matchedTags;
        factors++;
      }
    }

    // Author matching
    if (preferredAuthors.containsKey(video.authorId)) {
      score += preferredAuthors[video.authorId]!;
      factors++;
    }

    return factors > 0 ? (score / factors) : 0.5;
  }

  /// Fallback: Get trending videos
  Future<Set<Video>> getTrendingVideos(int limit) async {
    log("Fallback to trending!", level: 2000);
    final snapshot = await firestore.collection('videos').orderBy('createdAt', descending: true).limit(limit).get();
    print("got snapshot");
    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toSet();
  }

  ///Get videos for new users
  Future<List<Video>> getColdStartVideos({int limit = 20}) async {
    // Get popular videos from last 3 days
    final threeDaysAgo = DateTime.now().subtract(Duration(days: 3));

    final snapshot = await firestore
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

  Future<List<Video>> fetchNewVideos(DateTime? newestSeen, int limit) async {
    Query query = firestore.collection('videos').orderBy('createdAt', descending: true).limit(limit);

    if (newestSeen != null) {
      query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(newestSeen));
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
  }

  Future<List<Video>> fetchOldVideos(DateTime? oldestSeen, int limit) async {
    Query query = firestore.collection('videos').orderBy('createdAt', descending: true).limit(limit);

    if (oldestSeen != null) {
      query = query.where('createdAt', isLessThan: Timestamp.fromDate(oldestSeen));
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
  }

  Future<List<Video>> fetchTrendingVideos({
    DateTime? cursor,
    required int limit,
  }) async {
    final weekAgo = DateTime.now().subtract(Duration(days: 7));

    Query query =
        firestore.collection('videos').where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo)).orderBy('createdAt', descending: true).limit(limit * 3);

    cursor ??= LocalSeenService.getTrendingCursor();
    
    if (cursor != null) {
      query = query.where('createdAt', isLessThan: Timestamp.fromDate(cursor));
    }
    
    final snapshot = await query.get();

    final videos = snapshot.docs.map((doc) => Video.fromFirestore(doc)).where((v) => !LocalSeenService.hasSeen(v.id)).toList();

    videos.sort((a, b) => calculateGlobalEngagementScore(b).compareTo(calculateGlobalEngagementScore(a)));

    final filteredVideos = videos.take(limit);
    
    if(filteredVideos.isNotEmpty) {
      LocalSeenService.saveTrendingCursor(filteredVideos.last.createdAt);
    }
    
    return filteredVideos.toList();
  }

  static const _maxRetryAttempts = 5;

  Future<List<Video>> fetchVideosByTag(String tag, {required int limit}) async {
    print("fetching videos by tag $tag");
    final List<Video> unseen = [];
    DateTime? cursor = LocalSeenService.getTagCursor(tag);

    int attempts = 0;
    while (unseen.length < limit && attempts < _maxRetryAttempts) {
      Query query = firestore.collection('videos').where('tags', arrayContains: tag).orderBy('createdAt', descending: true);

      if (cursor != null) {
        query = query.where('createdAt', isLessThan: Timestamp.fromDate(cursor));
      }

      final snapshot = await query.limit(limit * 2).get(); //todo check costs of firebase
      print("got snapshot: ${snapshot.docs.map((e) => (e.data() as Map<String, dynamic>)["videoUrl"]).toList()}");
      if (snapshot.docs.isEmpty) break;

      final videos = snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();

      unseen.addAll(videos.where((v) => !LocalSeenService.hasSeen(v.id)));

      int lastCountingIndex = min(videos.length - 1, limit);
      cursor = videos.elementAtOrNull(lastCountingIndex)?.createdAt;

      print("unseen filtered: ${unseen.map((e) => e.videoUrl).toList().take(limit).toList()}");
    }

    if (cursor != null) {
      await LocalSeenService.saveTagCursor(tag, cursor);
    }

    return unseen.take(limit).toList();
  }

  /// Calculate global engagement score from video metrics
  double calculateGlobalEngagementScore(Video video) {
    int views = video.viewsCount ?? 1;
    final likes = video.likesCount ?? 0;
    final shares = video.sharesCount ?? 0;
    final comments = video.commentsCount ?? 0;
    if (views == 0) views = 1; // Avoid division by zero

    final engagementRate = (likes + shares * 2 + comments * 1.5 + 1) / views;
    return (engagementRate * 100).clamp(0.0, 1.0);
  }
}
