import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/logic/batches/batch_service.dart';
import 'package:wurp/logic/comments/comment.dart';
import 'package:wurp/logic/video/video.dart';

import '../../main.dart';

VideoRepository videoRepo = VideoRepository();
final FirestoreBatchQueue batchQueue = FirestoreBatchQueue();

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

    batchQueue.set(videoRef, {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'authorId': authorId,
      'createdAt': FieldValue.serverTimestamp(),
      'tags': tags.map((tag) => tag.toLowerCase()).toList(),
      'likesCount': 0,
      'sharesCount': 0,
      'commentsCount': 0,
      'viewsCount': 0,
    });

    batchQueue.set(
      firestore.collection('users').doc(authorId).collection('videos').doc(videoRef.id),
      {
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    videoQueueLength++;
    if (videoQueueLength >= 10) {
      await flush();
      videoQueueLength = 0;
    }
  }

  

  /// Like a video
  void likeVideo(String userId, String videoId, String authorId) async {
    batchQueue.set(
      firestore.collection('users').doc(userId).collection('liked_videos').doc(videoId),
      {
        'likedAt': FieldValue.serverTimestamp(),
      },
    );

    batchQueue.set(
      firestore.collection('videos').doc(videoId).collection('likes').doc(userId),
      {
        'likedAt': FieldValue.serverTimestamp(),
      },
    );

    batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'likesCount': FieldValue.increment(1),
      },
    );
    
    firestore.collection('users').doc(authorId).update({'totalLikes': FieldValue.increment(1)});
  }

  /// Unlike a video
  void unlikeVideo(String userId, String videoId, String authorId) {
    batchQueue.delete(
      firestore.collection('users').doc(userId).collection('liked_videos').doc(videoId),
    );

    batchQueue.delete(
      firestore.collection('videos').doc(videoId).collection('likes').doc(userId),
    );

    batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'likesCount': FieldValue.increment(-1),
      },
    );

    firestore.collection('users').doc(authorId).update({'totalLikes': FieldValue.increment(-1)});
  }

  void dislikeVideo(String userId, String videoId) {
    batchQueue.set(
      firestore.collection('users').doc(userId).collection('disliked_videos').doc(videoId),
      {
        'dislikedAt': FieldValue.serverTimestamp(),
      },
    );

    batchQueue.set(
      firestore.collection('videos').doc(videoId).collection('dislikes').doc(userId),
      {
        'dislikedAt': FieldValue.serverTimestamp(),
      },
    );

    batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'dislikesCount': FieldValue.increment(1),
      },
    );
  }

  /// Unlike a video
  void undislikeVideo(String userId, String videoId) {
    batchQueue.delete(
      firestore.collection('users').doc(userId).collection('disliked_videos').doc(videoId),
    );

    batchQueue.delete(
      firestore.collection('videos').doc(videoId).collection('dislikes').doc(userId),
    );

    batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'dislikesCount': FieldValue.increment(-1),
      },
    );
  }

  /// Increment view count
  void incrementViewCount(String videoId) {
    batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'viewsCount': FieldValue.increment(1),
      },
    );
  }

  /// Increment share count
  void incrementShareCount(String videoId) {
    batchQueue.update(
      firestore.collection('videos').doc(videoId),
      {
        'shares': FieldValue.increment(1),
      },
    );
  }

  /// Add a comment
  Future<void> addComment(String videoId, Comment comment) async {
    print("adding ${comment.toFirestore()} to ${comment.id}");
    await firestore.collection('videos').doc(videoId).collection('comments').doc(comment.id).set(comment.toFirestore());
    await firestore.collection('videos').doc(videoId).set(
      {
        "commentsCount": FieldValue.increment(1)
      },
      SetOptions(merge: true)
    );
  }

  Future<({List<Comment> comments, DocumentSnapshot? lastDoc})> getComments(String videoId,
      {String? commentId, DocumentSnapshot? startAfter, int limit = 20}) async {
    Query baseQuery = firestore.collection('videos').doc(videoId).collection('comments');
    
    if (startAfter != null) {
      baseQuery = baseQuery.startAfterDocument(startAfter);
    }
    if(commentId == null){
      baseQuery = baseQuery.where('parentId', isNull: true);
    } else {
      baseQuery = baseQuery.where('parentId', isEqualTo: commentId);
    }

    final result = await baseQuery.limit(limit).get();
    DocumentSnapshot? lastDoc = result.docs.lastOrNull;

    List<Comment> comments = result.docs
        .map((e) {
          Object? data = e.data();
          if (data is! Map<String, dynamic>) return null;
          try {
            return Comment.fromFirestore(e.id, data);
          } on TypeError catch (_) {
            return null;
          }
        })
        .whereType<Comment>()
        .toList();

    return (
      comments: comments,
      lastDoc: lastDoc,
    );
  }

  /// Save video
  void saveVideo(String userId, String videoId) {
    batchQueue.set(
      firestore.collection('users').doc(userId).collection('saved_videos').doc(videoId),
      {
        'savedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Unsave video
  void unsaveVideo(String userId, String videoId) {
    batchQueue.delete(
      firestore.collection('users').doc(userId).collection('saved_videos').doc(videoId),
    );
  }

  /// Report a video
  void reportVideo(
    String userId,
    String videoId,
    String reason,
  ) {
    batchQueue.set(
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
    await batchQueue.commit();
  }

  /// Get current queue size
  int get pendingOperations => batchQueue.queueSize;

  /// Get video feed for a user (following feed)
  Future<List<Video>> getFollowingFeed(String userId, {int limit = 20}) async {
    try {
      final followingSnapshot = await firestore.collection('users').doc(userId).collection('following').get();

      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();

      if (followingIds.isEmpty) return [];

      final videosSnapshot = await firestore
          .collection('videos')
          .where('authorId', whereIn: followingIds.take(10).toList())
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return videosSnapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting following feed: $e');
      return [];
    }
  }

  /// Get trending videos
  Future<List<Video>> getTrendingVideos({int limit = 20}) async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));

      final snapshot = await firestore
          .collection('videos')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .orderBy('createdAt', descending: true)
          .limit(limit * 3)
          .get();

      final videos = snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();

      videos.sort((a, b) => b.engagementRate.compareTo(a.engagementRate));

      return videos.take(limit).toList();
    } catch (e) {
      print('Error getting trending videos: $e');
      return [];
    }
  }

  /// Search videos by title or tags
  Future<({List<Video> videos, DocumentSnapshot? lastDoc})> searchVideos(
    String query, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    var queryRef = firestore.collection('videos').orderBy('title').startAt([query]).endAt([query + '\uf8ff']).limit(limit);

    if (startAfter != null) {
      queryRef = queryRef.startAfterDocument(startAfter);
    }

    final snapshot = await queryRef.get();
    final videos = snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();

    return (
      videos: videos,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    );
  }

  Future<({List<Video> videos, DocumentSnapshot? lastDoc})> searchVideosByTag(
    String tag, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    var queryRef = firestore
        .collection('videos')
        .where('tags', arrayContains: tag)
        .orderBy('likesCount') //todo switch when using new naming for new videos
        .limit(limit);

    if (startAfter != null) {
      queryRef = queryRef.startAfterDocument(startAfter);
    }

    final snapshot = await queryRef.get();
    final videos = snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();

    return (
      videos: videos,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    );
  }

  /// Get videos by specific tags
  Future<List<Video>> getVideosByTags(
    List<String> tags, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await firestore.collection('videos').where('tags', arrayContainsAny: tags).orderBy('createdAt', descending: true).limit(limit).get();

      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList();
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

      return snapshot.docs.map((doc) => Video.fromFirestore(doc)).where((v) => v.id != video.id).take(limit).toList();
    } catch (e) {
      print('Error getting related videos: $e');
      return [];
    }
  }

  Future<List<Video>> getSavedVideos(String userId, {int limit = 20}) async {
    try {
      final savedSnapshot = await firestore.collection('users').doc(userId).collection('saved_videos').orderBy('savedAt', descending: true).limit(limit).get();

      final videoIds = savedSnapshot.docs.map((doc) => doc.id).toList();

      if (videoIds.isEmpty) return [];

      final videos = <Video>[];
      for (final videoId in videoIds) {
        final videoDoc = await firestore.collection('videos').doc(videoId).get();

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

  Future<List<Video>> fetchVideosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final videos = <Video>[];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      videos.addAll(snapshot.docs.map((doc) => Video.fromFirestore(doc)));
    }
    return videos;
  }
}
