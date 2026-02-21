import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/logic/batches/batch_service.dart';
import 'package:wurp/logic/video/video.dart';

import '../../main.dart';


class VideoRepository {
  
  Future<Video> getVideoById(String id) async {
    DocumentSnapshot doc = await firestore.collection('videos').doc(id).get();
    Video model = Video.fromFirestore(doc);
    
    return model;
  }

  Future<List<String>> getVideoIdsByUser(String userId) async {
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('videos').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }
  
  int videoQueueLength = 0;
  Future<void> publishVideo({
    required String title,
    required String description,
    required String videoUrl,
    String? thumbnailUrl,
    required String authorId,
    List<String> tags = const [],
  }) async {
    final videoRef = firestore.collection('videos').doc();

    _batchQueue.set(videoRef, {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'authorId': authorId,
      'createdAt': FieldValue.serverTimestamp(),
      'tags': tags.map((tag) => tag.toLowerCase()).toList(),
      'likes': 0,
      'shares': 0,
      'comments': 0,
      'views': 0,
    });

    _batchQueue.set(
      firestore
          .collection('users')
          .doc(authorId)
          .collection('videos')
          .doc(videoRef.id),
      {
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    videoQueueLength++;
    if(videoQueueLength >= 10) {
      await flush();
      videoQueueLength = 0;
    }
  }
  

  final FirestoreBatchQueue _batchQueue = FirestoreBatchQueue();

  /// Like a video
  void likeVideo(String userId, String videoId) {
    _batchQueue.set(
      firestore
          .collection('users')
          .doc(userId)
          .collection('liked_videos')
          .doc(videoId),
      {
        'likedAt': FieldValue.serverTimestamp(),
      },
    );

    _batchQueue.set(
      firestore
          .collection('videos')
          .doc(videoId)
          .collection('likes')
          .doc(userId),
      {
        'likedAt': FieldValue.serverTimestamp(),
      },
    );

    _batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'likesCount': FieldValue.increment(1),
      },
    );
  }

  /// Unlike a video
  void unlikeVideo(String userId, String videoId) {
    _batchQueue.delete(
      firestore
          .collection('users')
          .doc(userId)
          .collection('liked_videos')
          .doc(videoId),
    );

    _batchQueue.delete(
      firestore
          .collection('videos')
          .doc(videoId)
          .collection('likes')
          .doc(userId),
    );

    _batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'likesCount': FieldValue.increment(-1),
      },
    );
  }

  void dislikeVideo(String userId, String videoId) {
    _batchQueue.set(
      firestore
          .collection('users')
          .doc(userId)
          .collection('disliked_videos')
          .doc(videoId),
      {
        'dislikedAt': FieldValue.serverTimestamp(),
      },
    );

    _batchQueue.set(
      firestore
          .collection('videos')
          .doc(videoId)
          .collection('dislikes')
          .doc(userId),
      {
        'dislikedAt': FieldValue.serverTimestamp(),
      },
    );

    _batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'dislikesCount': FieldValue.increment(1),
      },
    );
  }

  /// Unlike a video
  void undislikeVideo(String userId, String videoId) {
    _batchQueue.delete(
      firestore
          .collection('users')
          .doc(userId)
          .collection('disliked_videos')
          .doc(videoId),
    );

    _batchQueue.delete(
      firestore
          .collection('videos')
          .doc(videoId)
          .collection('dislikes')
          .doc(userId),
    );

    _batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'dislikesCount': FieldValue.increment(-1),
      },
    );
  }

  /// Follow a user
  void followUser(String followerId, String followeeId) {
    if (followerId == followeeId) {
      throw Exception('Cannot follow yourself');
    }

    _batchQueue.set(
      firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followeeId),
      {
        'followedAt': FieldValue.serverTimestamp(),
      },
    );

    _batchQueue.set(
      firestore
          .collection('users')
          .doc(followeeId)
          .collection('followers')
          .doc(followerId),
      {
        'followedAt': FieldValue.serverTimestamp(),
      },
    );

    _batchQueue.update(
      firestore.collection('users').doc(followerId),
      {
        'followingCount': FieldValue.increment(1),
      },
    );

    _batchQueue.update(
      firestore.collection('users').doc(followeeId),
      {
        'followersCount': FieldValue.increment(1),
      },
    );
  }

  /// Unfollow a user
  void unfollowUser(String followerId, String followeeId) {
    _batchQueue.delete(
      firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followeeId),
    );

    _batchQueue.delete(
      firestore
          .collection('users')
          .doc(followeeId)
          .collection('followers')
          .doc(followerId),
    );

    _batchQueue.update(
      firestore.collection('users').doc(followerId),
      {
        'followingCount': FieldValue.increment(-1),
      },
    );

    _batchQueue.update(
      firestore.collection('users').doc(followeeId),
      {
        'followersCount': FieldValue.increment(-1),
      },
    );
  }

  /// Increment view count
  void incrementViewCount(String videoId) {
    _batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'views': FieldValue.increment(1),
      },
    );
  }

  /// Increment share count
  void incrementShareCount(String videoId) {
    _batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'shares': FieldValue.increment(1),
      },
    );
  }

  /// Add a comment
  void addComment(
      String userId,
      String videoId,
      String commentText,
      ) {
    final commentRef = firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .doc();

    _batchQueue.set(commentRef, {
      'userId': userId,
      'text': commentText,
      'createdAt': FieldValue.serverTimestamp(),
      'likesCount': 0,
    });

    _batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'commentsCount': FieldValue.increment(1),
      },
    );
  }

  /// Save video
  void saveVideo(String userId, String videoId) {
    _batchQueue.set(
      firestore
          .collection('users')
          .doc(userId)
          .collection('saved_videos')
          .doc(videoId),
      {
        'savedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Unsave video
  void unsaveVideo(String userId, String videoId) {
    _batchQueue.delete(
      firestore
          .collection('users')
          .doc(userId)
          .collection('saved_videos')
          .doc(videoId),
    );
  }

  /// Report a video
  void reportVideo(
      String userId,
      String videoId,
      String reason,
      ) {
    _batchQueue.set(
      firestore.collection('video_reports').doc(),
      {
        'userId': userId,
        'videoId': videoId,
        'reason': reason,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      },
    );
  }

  /// Force commit all pending operations
  Future<void> flush() async {
    await _batchQueue.commit();
  }

  /// Get current queue size
  int get pendingOperations => _batchQueue.queueSize;


  /// Get video feed for a user (following feed)
  Future<List<Video>> getFollowingFeed(String userId, {int limit = 20}) async {
    try {
      final followingSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

      if (followingIds.isEmpty) return [];

      final videosSnapshot = await firestore
          .collection('videos')
          .where('authorId', whereIn: followingIds.take(10).toList())
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

  /// Get trending videos
  Future<List<Video>> getTrendingVideos({int limit = 20}) async {
    try {
      final oneDayAgo = DateTime.now().subtract(Duration(days: 1));

      final snapshot = await firestore
          .collection('videos')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .orderBy('createdAt', descending: true)
          .limit(limit * 3)
          .get();

      final videos = snapshot.docs
          .map((doc) => Video.fromFirestore(doc))
          .toList();

      videos.sort((a, b) => b.engagementRate.compareTo(a.engagementRate));

      return videos.take(limit).toList();
    } catch (e) {
      print('Error getting trending videos: $e');
      return [];
    }
  }

  /// Search videos by title or tags
  Future<List<Video>> searchVideos(String query, {int limit = 20}) async {
    try {
      final snapshot = await firestore
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

  /// Get videos by specific tags
  Future<List<Video>> getVideosByTags(
      List<String> tags, {
        int limit = 20,
      }) async {
    try {
      final snapshot = await firestore
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

  /// Get related videos based on tags
  Future<List<Video>> getRelatedVideos(
      Video video, {
        int limit = 10,
      }) async {
    try {
      if (video.tags.isEmpty) return [];

      final snapshot = await firestore
          .collection('videos')
          .where('tags', arrayContainsAny: video.tags.take(5).toList())
          .orderBy('createdAt', descending: true)
          .limit(limit + 1)
          .get();

      return snapshot.docs
          .map((doc) => Video.fromFirestore(doc))
          .where((v) => v.id != video.id)
          .take(limit)
          .toList();
    } catch (e) {
      print('Error getting related videos: $e');
      return [];
    }
  }

  Future<List<Video>> getSavedVideos(String userId, {int limit = 20}) async {
    try {
      final savedSnapshot = await firestore
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
        final videoDoc = await firestore
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