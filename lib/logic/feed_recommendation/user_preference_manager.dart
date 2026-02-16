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
  Map<String, double> _cachedTagPrefs = {};
  Map<String, double> _cachedAuthorPrefs = {};
  double _cachedAvgCompletion = 0.0;
  int _cachedTotalInteractions = 0;

  static final Map<String, UserPreferenceManager> _instances = {};

  factory UserPreferenceManager({required String userId}) {
    return _instances.putIfAbsent(userId, () => UserPreferenceManager._internal(userId));
  }

  UserPreferenceManager._internal(this.userId){
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
      final userRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('preferences');
      print("Loading user preferences from Firestore for user $userId...");
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final profile = data['recommendationProfile'] ?? {};

        _cachedTagPrefs = Map<String, double>.from(profile['tagVector'] ?? {});
        _cachedAuthorPrefs = Map<String, double>.from(profile['authorVector'] ?? {});
        _cachedAvgCompletion = (profile['avgCompletionRate'] ?? 0.0).toDouble();
        _cachedTotalInteractions = profile['totalInteractions'] ?? 0;

        print("📥 Loaded: ${_cachedTagPrefs.length} tags, ${_cachedAuthorPrefs.length} authors: avgCompletion=${_cachedAvgCompletion.toStringAsFixed(2)}, totalInteractions=$_cachedTotalInteractions, tags: ${(_cachedTagPrefs.entries.toList()..sort((a, b) => a.value.compareTo(b.value))).map<String>((e) => "${e.key}: ${e.value.toStringAsPrecision(2)}").toList().toString()}");
      }
    } catch (e) {
      print('Error loading cache: $e');
    }
  }

  Future<void> updatePreferences({
    required Video video,
    required double normalizedEngagementScore,
  }) async {
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
      final oldScore = _cachedTagPrefs[tag] ?? 0.5;
      final lr = adaptiveLR(oldScore);
      final newScore = oldScore + lr * (normalizedEngagementScore - oldScore);
      _cachedTagPrefs[tag] = newScore.clamp(0.0, 1.0);
      updated++;
    }

    if (updated == 0) {
      print("NO TAGS UPDATED! video.tags = ${video.tags}");
    }

    
    Map<String, double>? networkTagEffects;
    // Trim tags
    if (_cachedTagPrefs.length > _maxTagPreferences) {
      final sorted = _cachedTagPrefs.entries.toList()
        ..sort((a, b) => b.value.distanceTo(0.5).compareTo(a.value.distanceTo(0.5))); // Keep tags with scores farthest from neutral (0.5)
      networkTagEffects = Map.fromEntries(sorted.take(_maxTagPreferences));
      print("removed tags: ${sorted.skip(_maxTagPreferences).map((e) => "${e.key}: ${e.value.toStringAsPrecision(2)}").toList()}");
    }
    
    networkTagEffects ??= _cachedTagPrefs;

    // Update author
    final oldAuthor = _cachedAuthorPrefs[video.authorId] ?? 0.5;
    final lr = adaptiveLR(oldAuthor);
    _cachedAuthorPrefs[video.authorId] =
        (oldAuthor + lr * (normalizedEngagementScore - oldAuthor)).clamp(0.0, 1.0);
    print("👤 Author '${video.authorId}': $oldAuthor -> ${_cachedAuthorPrefs[video.authorId]}");

    Map<String, double>? networkAuthorEffects;
    
    if (_cachedAuthorPrefs.length > _maxAuthorPreferences) {
      final sorted = _cachedAuthorPrefs.entries.toList()
        ..sort((a, b) => b.value.distanceTo(0.5).compareTo(a.value.distanceTo(0.5))); // Keep tags with scores farthest from neutral (0.5)
      networkAuthorEffects = Map.fromEntries(sorted.take(_maxAuthorPreferences));
      print("removed tags: ${sorted.skip(_maxAuthorPreferences).map((e) => "${e.key}: ${e.value.toStringAsPrecision(2)}").toList()}");
    }

    networkAuthorEffects ??= _cachedAuthorPrefs;

    _cachedAvgCompletion = (_cachedAvgCompletion * _cachedTotalInteractions + normalizedEngagementScore) /
        (_cachedTotalInteractions + 1);
    _cachedTotalInteractions++;

    final userRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('preferences');

    userRef.batchSet({
      'recommendationProfile': {
        'tagVector': networkTagEffects,
        'authorVector': networkAuthorEffects,
        'avgCompletionRate': _cachedAvgCompletion,
        'totalInteractions': _cachedTotalInteractions,
        'lastUpdated': FieldValue.serverTimestamp(),
      }
    }, merge: true);

    print("Batched update (queue: ${FirestoreBatchQueue().queueSize})");

    if (_cachedTotalInteractions % 5 == 0) {
      await FirestoreBatchQueue().commit();
      print("Forced batch commit at interaction #$_cachedTotalInteractions");
    }
  }
}