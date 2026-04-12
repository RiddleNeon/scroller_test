/// User preferences aggregated from interactions
class UserPreferences {
  final Map<String, double> tagPreferences;
  final Map<String, double> authorPreferences;
  final double avgCompletionRate;
  final int totalInteractions;
  final DateTime? lastUpdated;

  UserPreferences({required this.tagPreferences, required this.authorPreferences, this.avgCompletionRate = 0.0, this.totalInteractions = 0, this.lastUpdated});

  factory UserPreferences.fromSupabase(Map<String, dynamic>? data) {
    if (data == null) {
      print("User preferences row does not exist. Initializing with empty preferences.");
      return UserPreferences(tagPreferences: {}, authorPreferences: {});
    }

    final profile = data['recommendationProfile'] ?? {};

    if (profile['totalInteractions'] != null) {
      print("User has ${profile['totalInteractions']} total interactions, avg completion rate: ${profile['avgCompletionRate']}");
    } else {
      print("User has no interactions yet.");
    }

    return UserPreferences(
      tagPreferences: Map<String, double>.from(profile['tagVector'] ?? {}),
      authorPreferences: Map<String, double>.from(profile['authorVector'] ?? {}),
      avgCompletionRate: (profile['avgCompletionRate'] ?? 0.0).toDouble(),
      totalInteractions: profile['totalInteractions'] ?? 0,
      lastUpdated: profile['lastUpdated'] != null ? DateTime.parse(profile['lastUpdated'] as String).toLocal() : null,
    );
  }

  bool get isNewUser => totalInteractions < 5;

  @override
  String toString() {
    return 'UserPreferences(tagPreferences: $tagPreferences, authorPreferences: $authorPreferences, avgCompletionRate: $avgCompletionRate, totalInteractions: $totalInteractions, lastUpdated: $lastUpdated)';
  }
}
