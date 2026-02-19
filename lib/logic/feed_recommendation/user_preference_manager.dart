import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/util/extensions/num_distance.dart';

import '../batches/batch_service.dart';
import '../video/video.dart';

class UserPreferenceManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  static const double _learningRate = 0.25;
  static const int _maxTagPreferences = 380;
  static const int _maxAuthorPreferences = 20;

  static const double defaultMaxEngagementScore = 6;

  // Cache
  Map<String, TagInteraction> _cachedTagPrefs = {};
  Map<String, TagInteraction> _cachedAuthorPrefs = {};
  double _cachedAvgCompletion = 0.0;
  int _cachedTotalInteractions = 0;

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

        _cachedTagPrefs = Map<String, double>.from(
          profile['tagVector'] ?? {},
        ).map<String, TagInteraction>((key, value) => MapEntry(key, TagInteraction(engagementScore: value)));
        _cachedAuthorPrefs = Map<String, double>.from(
          profile['authorVector'] ?? {},
        ).map<String, TagInteraction>((key, value) => MapEntry(key, TagInteraction(engagementScore: value)));
        _cachedAvgCompletion = (profile['avgCompletionRate'] ?? 0.0).toDouble();
        _cachedTotalInteractions = profile['totalInteractions'] ?? 0;

        print(
          "📥 Loaded: ${_cachedTagPrefs.length} tags, ${_cachedAuthorPrefs.length} authors: avgCompletion=${_cachedAvgCompletion.toStringAsFixed(2)}, totalInteractions=$_cachedTotalInteractions, tags: ${(_cachedTagPrefs.entries.toList()..sort((a, b) => a.value.engagementScore.distanceTo(0.5).compareTo(b.value.engagementScore.distanceTo(0.5)))).map<String>((e) => "${e.key}: ${e.value.engagementScore.toStringAsPrecision(2)}").toList().toString()}",
        );
      }
    } catch (e) {
      print('Error loading cache');
      rethrow;
    }
  }

  Future<void> updatePreferences({required Video video, required double normalizedEngagementScore}) async {
    print("🎯 Update for video ${video.id}, tags: ${video.tags}, engagement: $normalizedEngagementScore");
    await loadCache();

    double adaptiveLR(double currentScore) {
      final distance = (currentScore - 0.5).abs();
      return _learningRate * (1.0 + (1.0 - distance * 2));
    }

    // Update tags
    int updated = 0;
    for (final tag in video.tags) {
      if (tag.isEmpty) continue;
      final oldScore = _cachedTagPrefs[tag]?.engagementScore ?? 0.5;
      final lr = adaptiveLR(oldScore);
      final newScore = oldScore + lr * (normalizedEngagementScore - oldScore);
      _cachedTagPrefs[tag] = TagInteraction(engagementScore: newScore.clamp(0.0, 1.0));
      updated++;
      print("🏷️ Tag '$tag': $oldScore -> ${_cachedTagPrefs[tag]} (LR: ${lr.toStringAsPrecision(3)})");
    }

    if (updated == 0) {
      print("NO TAGS UPDATED! video.tags = ${video.tags}");
    }

    Map<String, double>? networkTagEffects;
    // Trim tags
    if (_cachedTagPrefs.length > _maxTagPreferences) {
      final sorted = sortByRelevancy(_cachedTagPrefs);
      networkTagEffects = Map.fromEntries(sorted.take(_maxTagPreferences).map((e) => MapEntry(e.key, e.value.engagementScore)));
      print("removed tags: ${sorted.skip(_maxTagPreferences).map((e) => "${e.key}: ${e.value.engagementScore.toStringAsPrecision(2)}").toList()}");
      print("kept tags: ${networkTagEffects.entries.map((e) => "${e.key}: ${e.value.toStringAsPrecision(2)}").toList()}");
    }

    networkTagEffects ??= _cachedTagPrefs.map((key, value) => MapEntry(key, value.engagementScore));

    // Update author
    final oldAuthor = _cachedAuthorPrefs[video.authorId]?.engagementScore ?? 0.5;
    final lr = adaptiveLR(oldAuthor);
    _cachedAuthorPrefs[video.authorId] = TagInteraction(engagementScore: (oldAuthor + lr * (normalizedEngagementScore - oldAuthor)).clamp(0.0, 1.0));
    print("👤 Author '${video.authorId}': $oldAuthor -> ${_cachedAuthorPrefs[video.authorId]}");

    Map<String, double>? networkAuthorEffects;

    if (_cachedAuthorPrefs.length > _maxAuthorPreferences) {
      final sorted = sortByRelevancy(_cachedAuthorPrefs);
      networkAuthorEffects = Map.fromEntries(sorted.take(_maxAuthorPreferences).map((e) => MapEntry(e.key, e.value.engagementScore)));
      print("removed authors: ${sorted.skip(_maxAuthorPreferences).map((e) => "${e.key}: ${e.value.engagementScore.toStringAsPrecision(2)}").toList()}");
    }

    networkAuthorEffects ??= _cachedAuthorPrefs.map((key, value) => MapEntry(key, value.engagementScore));

    _cachedAvgCompletion = (_cachedAvgCompletion * _cachedTotalInteractions + normalizedEngagementScore) / (_cachedTotalInteractions + 1);
    _cachedTotalInteractions++;

    final userRef = _firestore.collection('users').doc(userId).collection('profile').doc('preferences');

    userRef.batchSet({
      'recommendationProfile': {
        'tagVector': networkTagEffects,
        'authorVector': networkAuthorEffects,
        'avgCompletionRate': _cachedAvgCompletion,
        'totalInteractions': _cachedTotalInteractions,
        'lastUpdated': FieldValue.serverTimestamp(),
      },
    }, merge: true);

    if (_cachedTotalInteractions % 5 == 0) {
      await FirestoreBatchQueue().commit();
    }
  }

  List<MapEntry<String, TagInteraction>> sortByRelevancy(Map<String, TagInteraction> tagPrefs) {
    DateTime now = DateTime.now();
    return tagPrefs.entries.toList()..sort(
      (a, b) => b.value.lastInteracted.difference(now) < Duration(minutes: 30)
          ? -1
          : b.value.engagementScore.distanceTo(0.5).compareTo(a.value.engagementScore.distanceTo(0.5)),
    );
  }
}

class TagInteraction {
  final double engagementScore;
  final DateTime lastInteracted;

  TagInteraction({required this.engagementScore, DateTime? lastInteracted}) : lastInteracted = lastInteracted ?? DateTime.now();

  TagInteraction copyToNow() => TagInteraction(engagementScore: engagementScore);
}
