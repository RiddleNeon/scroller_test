import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/logic/feed_recommendation/user_interaction.dart';
import 'package:wurp/logic/feed_recommendation/user_preference_manager.dart';
import 'package:wurp/logic/feed_recommendation/user_preferences.dart';

import '../local_storage/local_seen_service.dart';
import '../video/video.dart';

abstract class VideoRecommenderBase {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String userId;
  late final UserPreferenceManager preferenceManager;
  static const int _recentInteractionsLimit = 50;

  VideoRecommenderBase({required this.userId}) {
    preferenceManager = UserPreferenceManager(userId: userId);
  }
  /// Get user preferences
  Future<UserPreferences> getUserPreferences() async {
    final prefsDoc = await firestore.collection('users').doc(userId).collection('profile').doc('preferences').get();

    return UserPreferences.fromFirestore(prefsDoc);
  }

  /// Clean up old interactions
  Future<void> cleanupOldInteractions() async {
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('recent_interactions')
        .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }


  /// Track user interaction and update preferences
  Future<void> trackInteraction({
    required Video video,
    required double watchTime,
    required double videoDuration,
    bool liked = false,
    bool shared = false,
    bool commented = false,
    bool saved = false,
  }) async {
    final interaction = UserInteraction(
      videoId: video.id,
      watchTime: watchTime,
      videoDuration: videoDuration,
      liked: liked,
      shared: shared,
      commented: commented,
      saved: saved,
      timestamp: DateTime.now(), authorId: video.authorId, tags: video.tags,
    );

    print("trackInteraction - Video ID: ${video.id}");

    // 1. Store recent interaction (with automatic cleanup via TTL in Firestore rules)
    await firestore.collection('users').doc(userId).collection('recent_interactions').add({
      'videoId': video.id,
      'watchTime': watchTime,
      'videoDuration': videoDuration,
      'liked': liked,
      'shared': shared,
      'commented': commented,
      'saved': saved,
      'timestamp': FieldValue.serverTimestamp(),
      'authorId': video.authorId,
      'tags': video.tags,
    });

    print("Recent interaction saved");

    // 2. Update user preferences (batched)
    await preferenceManager.updatePreferences(video: video, normalizedEngagementScore: interaction.normalizedEngagementScore);
  }


  /// Get only recent interactions (limited query)
  Future<List<UserInteraction>> getRecentInteractions() async { //todo use cached preferences to limit this query
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('recent_interactions')
        .orderBy('timestamp', descending: true)
        .limit(_recentInteractionsLimit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      //print("videoId: ${data['videoId']}, watchTime: ${data['watchTime']}, videoDuration: ${data['videoDuration']}, liked: ${data['liked']}, shared: ${data['shared']}, commented: ${data['commented']}, saved: ${data['saved']}, timestamp: ${data['timestamp']}, authorId: ${data['authorId']}, tags: ${data['tags']}");
      return UserInteraction(
        videoId: data['videoId'] ?? '',
        watchTime: (data['watchTime'] ?? 0).toDouble(),
        videoDuration: (data['videoDuration'] ?? 1).toDouble(),
        liked: data['liked'] ?? false,
        shared: data['shared'] ?? false,
        commented: data['commented'] ?? false,
        saved: data['saved'] ?? false,
        timestamp: (data['timestamp'] as Timestamp).toDate(), authorId: data['authorId'] ?? "38215211", //todo
        tags: data['tags'] != null ? List<String>.from(data['tags']) : ["untagged"],
      );
    }).toList();
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
          tagScore += preferredTags[tag]! - 0.5; // Center around 0 (neutral) instead of 0.5
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
      score += preferredAuthors[video.authorId]! - 0.5;
      factors++;
    }

    return factors > 0 ? (score / factors).clamp(0.0, 1.0) : 0.5;
  }


  /// Fallback: Get trending videos
  Future<Set<Video>> getTrendingVideos(int limit) async {
    final snapshot = await firestore.collection('videos').orderBy('createdAt', descending: true).limit(limit).get();
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
    Query query = firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (newestSeen != null) {
      query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(newestSeen));
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
  }

  Future<List<Video>> fetchOldVideos(DateTime? oldestSeen, int limit) async {
    Query query = firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(limit);

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

    Query query = firestore
        .collection('videos')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
        .orderBy('createdAt', descending: true)
        .limit(limit * 3);
    
    if (cursor != null) {
      query = query.where('createdAt', isLessThan: Timestamp.fromDate(cursor));
    }

    final snapshot = await query.get();

    final videos = snapshot.docs
        .map((doc) => Video.fromFirestore(doc))
        .where((v) => !LocalSeenService.hasSeen(v.id))
        .toList();

    videos.sort((a, b) =>
        calculateGlobalEngagementScore(b).compareTo(calculateGlobalEngagementScore(a))
    );

    return videos.take(limit).toList();
  }

  /// Calculate global engagement score from video metrics
  double calculateGlobalEngagementScore(Video video) {
    int views = video.viewsCount ?? 1;
    final likes = video.likesCount ?? 0;
    final shares = video.sharesCount ?? 0;
    final comments = video.commentsCount ?? 0;
    if(views == 0) views = 1; // Avoid division by zero

    final engagementRate = (likes + shares * 2 + comments * 1.5 + 1) / views;
    return (engagementRate * 100).clamp(0.0, 1.0);
  }
  
}