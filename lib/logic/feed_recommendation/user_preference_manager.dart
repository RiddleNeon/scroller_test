import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/util/extensions/num_distance.dart';

import '../batches/batch_service.dart';
import '../video/video.dart';

class UserPreferenceManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  static const double _learningRate = 0.25;
  static const int _maxTagPreferences = 80;
  static const int _maxAuthorPreferences = 20;

  static const double defaultMaxEngagementScore = 6;

  // Cache
  Map<String, TagInteraction> cachedTagPrefs = {};
  Map<String, TagInteraction> cachedAuthorPrefs = {};
  double cachedAvgCompletion = 0.0;
  int cachedTotalInteractions = 0;

  static final Map<String, UserPreferenceManager> _instances = {};

  factory UserPreferenceManager({required String userId}) {
    return _instances.putIfAbsent(userId, () => UserPreferenceManager._internal(userId));
  }

  UserPreferenceManager._internal(this.userId) {
    loadCache();
  }

  Future<void>? _loadFuture;

  Future<void> loadCache() async {
    _loadFuture ??= _loadCacheInternal();
    return await _loadFuture!;
  }

  Future<void> _loadCacheInternal() async {
    print("getting cache for user $userId...");
    try {
      final userRef = _firestore.collection('users').doc(userId).collection('profile').doc('preferences');
      print("Loading user preferences from Firestore for user $userId...");
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final profile = data['recommendationProfile'] ?? {};

        cachedTagPrefs = Map<String, double>.from(
          profile['tagVector'] ?? {},
        ).map<String, TagInteraction>((key, value) => MapEntry(key, TagInteraction(engagementScore: value)));
        cachedAuthorPrefs = Map<String, double>.from(
          profile['authorVector'] ?? {},
        ).map<String, TagInteraction>((key, value) => MapEntry(key, TagInteraction(engagementScore: value)));
        cachedAvgCompletion = (profile['avgCompletionRate'] ?? 0.0).toDouble();
        cachedTotalInteractions = profile['totalInteractions'] ?? 0;
      }
    } catch (e) {
      print('Error loading cache');
      rethrow;
    }
  }

  Future<void> updatePreferences({required Video video, required double normalizedEngagementScore}) async {
    await loadCache();

    double adaptiveLR(double currentScore) {
      final distance = (currentScore - 0.5).abs();
      return _learningRate * (1.0 + (1.0 - distance * 2));
    }

    // Update tags
    int updated = 0;
    for (final tag in video.tags) {
      if (tag.isEmpty) continue;
      final oldScore = cachedTagPrefs[tag]?.engagementScore ?? 0.5;
      final lr = adaptiveLR(oldScore);
      final newScore = oldScore + lr * (normalizedEngagementScore - oldScore);
      cachedTagPrefs[tag] = TagInteraction(engagementScore: newScore.clamp(0.0, 1.0));
      updated++;
    }

    Map<String, double>? networkTagEffects;
    // Trim tags
    if (cachedTagPrefs.length > _maxTagPreferences) {
      final sorted = sortByRelevancy(cachedTagPrefs);
      networkTagEffects = Map.fromEntries(sorted.take(_maxTagPreferences).map((e) => MapEntry(e.key, e.value.engagementScore)));
    }

    networkTagEffects ??= cachedTagPrefs.map((key, value) => MapEntry(key, value.engagementScore));

    // Update author
    final oldAuthor = cachedAuthorPrefs[video.authorId]?.engagementScore ?? 0.5;
    final lr = adaptiveLR(oldAuthor);
    cachedAuthorPrefs[video.authorId] = TagInteraction(engagementScore: (oldAuthor + lr * (normalizedEngagementScore - oldAuthor)).clamp(0.0, 1.0));

    Map<String, double>? networkAuthorEffects;

    if (cachedAuthorPrefs.length > _maxAuthorPreferences) {
      final sorted = sortByRelevancy(cachedAuthorPrefs);
      networkAuthorEffects = Map.fromEntries(sorted.take(_maxAuthorPreferences).map((e) => MapEntry(e.key, e.value.engagementScore)));
    }

    networkAuthorEffects ??= cachedAuthorPrefs.map((key, value) => MapEntry(key, value.engagementScore));

    cachedAvgCompletion = (cachedAvgCompletion * cachedTotalInteractions + normalizedEngagementScore) / (cachedTotalInteractions + 1);
    cachedTotalInteractions++;

    final userRef = _firestore.collection('users').doc(userId).collection('profile').doc('preferences');

    userRef.batchSet({
      'recommendationProfile': {
        'tagVector': networkTagEffects,
        'authorVector': networkAuthorEffects,
        'avgCompletionRate': cachedAvgCompletion,
        'totalInteractions': cachedTotalInteractions,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
    }, merge: true);

    if (cachedTotalInteractions % 5 == 0) {
      await FirestoreBatchQueue().commit();
    }
  }

  List<MapEntry<String, TagInteraction>> sortByRelevancy(Map<String, TagInteraction> tagPrefs) {
    DateTime now = DateTime.now();
    return tagPrefs.entries.toList()
      ..sort((a, b) {
        final aRecent = now.difference(a.value.lastInteracted) < Duration(minutes: 30);
        final bRecent = now.difference(b.value.lastInteracted) < Duration(minutes: 30);
        if (bRecent && !aRecent) return 1;
        if (aRecent && !bRecent) return -1;
        return b.value.engagementScore.distanceTo(0.5).compareTo(a.value.engagementScore.distanceTo(0.5));
      });
  }
}

class TagInteraction {
  final double engagementScore;
  final DateTime lastInteracted;

  TagInteraction({required this.engagementScore, DateTime? lastInteracted}) : lastInteracted = lastInteracted ?? DateTime.now();

  TagInteraction copyToNow() => TagInteraction(engagementScore: engagementScore);
}
