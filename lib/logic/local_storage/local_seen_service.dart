import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wurp/main.dart';

class LocalSeenService {
  static const String _seenBoxName = 'seen_videos';
  static const String _settingsBoxName = 'seen_settings';
  static late Box<DateTime> _seenBox;
  static late Box<DateTime> _settingsBox;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static late final String userId;

  static Future<void> init() async {
    print("starting initialization of LocalSeenService...");
    await Hive.initFlutter();
    _seenBox = await Hive.openBox<DateTime>(_seenBoxName);
    _settingsBox = await Hive.openBox<DateTime>(_settingsBoxName);
    userId = auth!.currentUser!.uid;
    await syncWithFirestore();
    await cleanUpOldEntries();
    print("initialized LocalSeenService with ${_seenBox.length} seen videos for user $userId");
  }

  static void markAsSeen(String videoId) {
    _seenBox.put(videoId, DateTime.now());
  }

  static bool hasSeen(String videoId) {
    return _seenBox.containsKey(videoId);
  }

  static Set<String> get allSeenIds => _seenBox.keys.cast<String>().toSet();

  static Future<void> cleanUpOldEntries() async {
    if (_seenBox.length <= 5000) return;

    final entries = _seenBox.toMap().entries.toList();
    entries.sort((a, b) => a.value.compareTo(b.value));

    final amountToDelete = _seenBox.length - 5000;
    final keysToDelete = entries.take(amountToDelete).map((e) => e.key as String).toList();

    await _seenBox.deleteAll(keysToDelete);
  }


  static Future<void> syncWithFirestore() async {
    final lastSync = _settingsBox.get('lastSyncTimestamp') ??
        DateTime.now().subtract(Duration(days: 7));

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('recent_interactions')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(lastSync))
        .orderBy('timestamp', descending: true)
        .get();

    if (snapshot.docs.isEmpty) return;

    final Map<String, DateTime> newEntries = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String videoId = data['videoId'];
      final DateTime seenAt = (data['timestamp'] as Timestamp).toDate();

      newEntries[videoId] = seenAt;
    }

    print("Syncing ${newEntries.length} seen video entries from Firestore for user $userId...");
    await _seenBox.putAll(newEntries);
    print("all seen videos: ${_seenBox.keys.toList()}");

    final latestInteractionTime = (snapshot.docs.first.data()['timestamp'] as Timestamp).toDate();
    await _settingsBox.put('lastSyncTimestamp', latestInteractionTime);
  }
}