import 'package:cloud_firestore/cloud_firestore.dart';

import '../../logic/batches/batch_service.dart';
import '../../logic/video/video.dart';

class VideoInteractionTracker {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreBatchQueue _batchQueue = FirestoreBatchQueue.instance;

  final String userId;
  final Video video;

  VideoInteractionTracker({
    required this.userId,
    required this.video,
  });

  Future<void> trackInteraction({
    required String type,
    double watchTime = 0,
    double videoDuration = 1,
  }) async {

    final completionRate = (watchTime / 5).clamp(0.0, 2.0);

    final engagementScore =
    _calculateEngagementScore(type, completionRate);

    // Store interaction under user
    final interactionRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('interactions')
        .doc();

    _batchQueue.set(interactionRef, {
      'videoId': video.id,
      'authorId': video.authorId,
      'tags': video.tags,
      'type': type,
      'watchTime': watchTime,
      'completionRate': completionRate,
      'engagementScore': engagementScore,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 🔥 Update video metrics
    final videoRef =
    _firestore.collection('videos').doc(video.id);

    _batchQueue.update(videoRef, {
      'metrics.$type': FieldValue.increment(1),
    });
  }

  double _calculateEngagementScore(
      String type,
      double completionRate,
      ) {
    double score = completionRate;

    switch (type) {
      case 'like':
        score += 2;
        break;
      case 'share':
        score += 3;
        break;
      case 'comment':
        score += 2.5;
        break;
      case 'save':
        score += 2;
        break;
      case 'report':
        score -= 3;
        break;
    }

    return score.clamp(0.0, 10.5);
  }

  Future<void> commit() async {
    await _batchQueue.commit();
  }
}
