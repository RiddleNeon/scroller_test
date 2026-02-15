import 'package:cloud_firestore/cloud_firestore.dart';
import '../batches/batch_service.dart';
import '../video/video.dart';

class UserPreferenceManager {
  final FirebaseFirestore  _firestore = FirebaseFirestore.instance;
  final String userId;

  static const double _learningRate = 0.5;
  static const int _maxTagPreferences = 30;
  static const int _maxAuthorPreferences = 20;

  static const double defaultMaxEngagementScore = 10;

  // Cache
  Map<String, double> _cachedTagPrefs = {};
  Map<String, double> _cachedAuthorPrefs = {};
  double _cachedAvgCompletion = 0.0;
  int _cachedTotalInteractions = 0;

  static final Map<String, UserPreferenceManager> _instances = {};

  factory UserPreferenceManager({required String userId}) {
    return _instances.putIfAbsent(userId, () => UserPreferenceManager._internal(userId));
  }

  UserPreferenceManager._internal(this.userId);

  Future<void>? _loadFuture;
  Future<void> loadCache() async {
    _loadFuture ??= _loadCache();
    return _loadFuture!;
  }

  Future<void> _loadCache() async {
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
    await _loadCache();

    // Update tags
    int updated = 0;
    for (final tag in video.tags) {
      if (tag.isEmpty) continue;

      final oldScore = _cachedTagPrefs[tag] ?? 0.5;
      final newScore = oldScore + _learningRate * (normalizedEngagementScore - oldScore);
      _cachedTagPrefs[tag] = newScore;
      updated++;
      print("Tag '$tag': $oldScore -> $newScore");
    }

    if (updated == 0) {
      print("NO TAGS UPDATED! video.tags = ${video.tags}");
    }

    // Trim tags
    if (_cachedTagPrefs.length > _maxTagPreferences) {
      final sorted = _cachedTagPrefs.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _cachedTagPrefs = Map.fromEntries(sorted.take(_maxTagPreferences));
    }

    // Update author
    final oldAuthor = _cachedAuthorPrefs[video.authorId] ?? 0.5;
    _cachedAuthorPrefs[video.authorId] =
        oldAuthor + _learningRate * (normalizedEngagementScore - oldAuthor);
    print("👤 Author '${video.authorId}': $oldAuthor -> ${_cachedAuthorPrefs[video.authorId]}");

    // Trim authors
    if (_cachedAuthorPrefs.length > _maxAuthorPreferences) {
      final sorted = _cachedAuthorPrefs.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _cachedAuthorPrefs = Map.fromEntries(sorted.take(_maxAuthorPreferences));
    }

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
        'tagVector': _cachedTagPrefs,
        'authorVector': _cachedAuthorPrefs,
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