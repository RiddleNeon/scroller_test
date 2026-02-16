import 'package:cloud_firestore/cloud_firestore.dart';

/// User preferences aggregated from interactions
class UserPreferences {
  final Map<String, double> tagPreferences;
  final Map<String, double> authorPreferences;
  final double avgCompletionRate;
  final int totalInteractions;
  final DateTime? lastUpdated;

  UserPreferences({required this.tagPreferences, required this.authorPreferences, this.avgCompletionRate = 0.0, this.totalInteractions = 0, this.lastUpdated});

  factory UserPreferences.fromFirestore(DocumentSnapshot doc) {
    print("Loading user preferences from Firestore for document: ${doc.id}");
    
    if (!doc.exists) {
      print("User preferences document does not exist. Initializing with empty preferences.");
      return UserPreferences(tagPreferences: {}, authorPreferences: {});
    }

    final data = doc.data() as Map<String, dynamic>;
    final profile = data['recommendationProfile'] ?? {};

    if(profile['totalInteractions'] != null) {
      print("User has ${profile['totalInteractions']} total interactions, avg completion rate: ${profile['avgCompletionRate']}");
    } else {
      print("User has no interactions yet.");
    }
    
    return UserPreferences(
      tagPreferences: Map<String, double>.from(profile['tagVector'] ?? {}),
      authorPreferences: Map<String, double>.from(profile['authorVector'] ?? {}),
      avgCompletionRate: (profile['avgCompletionRate'] ?? 0.0).toDouble(),
      totalInteractions: profile['totalInteractions'] ?? 0,
      lastUpdated: profile['lastUpdated'] != null ? (profile['lastUpdated'] as Timestamp).toDate() : null,
    );
  }

  bool get isNewUser => totalInteractions < 5;

  @override
  String toString() {
    return 'UserPreferences(tagPreferences: $tagPreferences, authorPreferences: $authorPreferences, avgCompletionRate: $avgCompletionRate, totalInteractions: $totalInteractions, lastUpdated: $lastUpdated)';
  }
}
