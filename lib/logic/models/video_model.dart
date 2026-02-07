import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String authorId;
  final DateTime createdAt;
  
  VideoModel({
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.authorId,
    required this.createdAt,
  });
  
  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return VideoModel(
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      authorId: data['authorId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}