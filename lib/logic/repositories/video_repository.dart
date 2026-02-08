import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/logic/video/video.dart';


class VideoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<Video> getVideoById(String id) async {
    DocumentSnapshot doc = await _firestore.collection('videos').doc(id).get();
    Video model = Video.fromFirestore(doc);
    
    return model;
  }

  Future<List<String>> getVideoIdsByUser(String userId) async {
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('videos').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }


  Future<void> likeVideo(String userId, String videoId) async {
    final batch = _firestore.batch();

    try {
      batch.set(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('liked_videos')
            .doc(videoId),
        {
          'likedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.set(
        _firestore
            .collection('videos')
            .doc(videoId)
            .collection('likes')
            .doc(userId),
        {
          'likedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        _firestore.collection('videos').doc(videoId),
        {
          'likesCount': FieldValue.increment(1),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Error liking video: $e');
      throw e;
    }
  }

  Future<void> unlikeVideo(String userId, String videoId) async {
    final batch = _firestore.batch();

    try {
      batch.delete(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('liked_videos')
            .doc(videoId),
      );

      batch.delete(
        _firestore
            .collection('videos')
            .doc(videoId)
            .collection('likes')
            .doc(userId),
      );

      batch.update(
        _firestore.collection('videos').doc(videoId),
        {
          'likesCount': FieldValue.increment(-1),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Error unliking video: $e');
      rethrow;
    }
  }

  Future<void> incrementViewCount(String videoId) async {
    try {
      await _firestore.collection('videos').doc(videoId).update({
        'viewsCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  Future<void> incrementShareCount(String videoId) async {
    try {
      await _firestore.collection('videos').doc(videoId).update({
        'sharesCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing share count: $e');
    }
  }

  Future<void> addComment(
      String userId,
      String videoId,
      String commentText,
      ) async {
    final batch = _firestore.batch();

    try {
      final commentRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc();

      batch.set(commentRef, {
        'userId': userId,
        'text': commentText,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
      });

      batch.update(
        _firestore.collection('videos').doc(videoId),
        {
          'commentsCount': FieldValue.increment(1),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  Future<List<Video>> getFollowingFeed(String userId, {int limit = 20}) async {
    try {
      // Get following list
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

      if (followingIds.isEmpty) return [];

      // Get videos from followed users
      final videosSnapshot = await _firestore
          .collection('videos')
          .where('authorId', whereIn: followingIds.take(100).toList())
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return videosSnapshot.docs
          .map((doc) => Video.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting following feed: $e');
      return [];
    }
  }

  Future<List<Video>> getTrendingVideos({int limit = 20}) async {
    try {
      final oneDayAgo = DateTime.now().subtract(Duration(days: 1));

      final snapshot = await _firestore
          .collection('videos')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .orderBy('createdAt', descending: true)
          .limit(limit * 3) // Get more to sort by engagement
          .get();

      final videos = snapshot.docs
          .map((doc) => Video.fromFirestore(doc))
          .toList();

      // Sort by engagement rate
      videos.sort((a, b) => b.engagementRate.compareTo(a.engagementRate));

      return videos.take(limit).toList();
    } catch (e) {
      print('Error getting trending videos: $e');
      return [];
    }
  }

  Future<List<Video>> searchVideos(String query, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('tags', arrayContains: query.toLowerCase())
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Video.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error searching videos: $e');
      return [];
    }
  }

  Future<List<Video>> getVideosByTags(
      List<String> tags, {
        int limit = 20,
      }) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('tags', arrayContainsAny: tags)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Video.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting videos by tags: $e');
      return [];
    }
  }

  Future<List<Video>> getRelatedVideos(
      Video video, {
        int limit = 10,
      }) async {
    try {
      if (video.tags.isEmpty) return [];

      final snapshot = await _firestore
          .collection('videos')
          .where('tags', arrayContainsAny: video.tags.take(3).toList())
          .orderBy('createdAt', descending: true)
          .limit(limit + 1) // +1 to exclude the current video
          .get();

      return snapshot.docs
          .map((doc) => Video.fromFirestore(doc))
          .where((v) => v.id != video.id) // Exclude current video
          .take(limit)
          .toList();
    } catch (e) {
      print('Error getting related videos: $e');
      return [];
    }
  }

  Future<void> reportVideo(
      String userId,
      String videoId,
      String reason,
      ) async {
    try {
      await _firestore.collection('video_reports').add({
        'userId': userId,
        'videoId': videoId,
        'reason': reason,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      print('Error reporting video: $e');
      rethrow;
    }
  }

  Future<void> saveVideo(String userId, String videoId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_videos')
          .doc(videoId)
          .set({
        'savedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving video: $e');
      rethrow;
    }
  }

  Future<void> unsaveVideo(String userId, String videoId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_videos')
          .doc(videoId)
          .delete();
    } catch (e) {
      print('Error unsaving video: $e');
      rethrow;
    }
  }

  Future<List<Video>> getSavedVideos(String userId, {int limit = 20}) async {
    try {
      final savedSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_videos')
          .orderBy('savedAt', descending: true)
          .limit(limit)
          .get();

      final videoIds = savedSnapshot.docs.map((doc) => doc.id).toList();

      if (videoIds.isEmpty) return [];

      final videos = <Video>[];
      for (final videoId in videoIds) {
        final videoDoc = await _firestore
            .collection('videos')
            .doc(videoId)
            .get();

        if (videoDoc.exists) {
          videos.add(Video.fromFirestore(videoDoc));
        }
      }

      return videos;
    } catch (e) {
      print('Error getting saved videos: $e');
      return [];
    }
  }

}