import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/logic/models/video_model.dart';


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
}