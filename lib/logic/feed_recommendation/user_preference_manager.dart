import 'package:wurp/util/extensions/num_distance.dart';

import '../../base_logic.dart';
import '../video/video.dart';

class UserPreferenceManager {
  static const double _learningRate = 0.25;
  static const int _maxTagPreferences = 80;
  static const int _maxAuthorPreferences = 20;

  static const double defaultMaxEngagementScore = 6;

  // Cache
  Map<String, TagInteraction> cachedTagPrefs = {};
  Map<String, TagInteraction> cachedAuthorPrefs = {};
  double cachedAvgCompletion = 0.0;
  int cachedTotalInteractions = 0;
  
  static UserPreferenceManager? currentInstance;
  factory UserPreferenceManager() {
    return currentInstance ??= UserPreferenceManager._internal();
  }
  UserPreferenceManager._internal() {
    loadCache();
  }
  
  ///resets all values in case of the user logging out and switching accounts
  static void reset(){
    currentInstance = null;
  }

  bool get isCacheLoaded => _loadFuture != null;
  
  Future<void>? _loadFuture;
  Future<void> loadCache() async {
    _loadFuture ??= _loadCacheInternal().catchError((e) {
      _loadFuture = null;
      throw e;
    });
    return await _loadFuture!;
  }

  Future<void> _loadCacheInternal() async {
    cachedTagPrefs = {};
    cachedAuthorPrefs = {};
    cachedAvgCompletion = 0.0;
    cachedTotalInteractions = 0;
  }

  Future<void> updatePreferences({required Video video, required double normalizedEngagementScore}) async {
    await loadCache();

    double adaptiveLR(double currentScore) {
      final distance = (currentScore - 0.5).abs();
      return _learningRate * (1.0 + (1.0 - distance * 2));
    }

    // Update tags
    for (final tag in video.tags) {
      if (tag.isEmpty) continue;
      final oldScore = cachedTagPrefs[tag]?.engagementScore ?? 0.5;
      final lr = adaptiveLR(oldScore);
      final newScore = oldScore + lr * (normalizedEngagementScore - oldScore);
      cachedTagPrefs[tag] = TagInteraction(engagementScore: newScore.clamp(0.0, 1.0));
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

    print('Keeping recommendation preferences in memory/local state because the provided Supabase schema has no user_preferences table.');
  }

  List<MapEntry<String, TagInteraction>> sortByRelevancy(Map<String, TagInteraction> tagPrefs) {
    DateTime now = DateTime.now();
    return tagPrefs.entries.toList()
      ..sort((a, b) {
        final aRecent = now.difference(a.value.lastInteracted) < const Duration(minutes: 30);
        final bRecent = now.difference(b.value.lastInteracted) < const Duration(minutes: 30);
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
