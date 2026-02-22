import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:wurp/logic/repositories/video_repository.dart';

import '../../logic/models/user_model.dart';
import '../../main.dart';

class VideoGenerator {}

void videoPublishTest() async {
  print("starting video publish test...");
  print("removing all current videos...");
  await removeAllCurrentVideos();
  print("removing all users except julian...");
  await removeAllUsers();
  print("removing all preferences of current user...");
  await removeAllPreferencesOfCurrentUser();
  
  
  Map<String, dynamic> json = await loadJson();
  final videos = (json['data'] as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  int i = 0;
  for (var videoData in videos) {
    await getVideoFromJsonDataObject(videoData, videoRepo);
    i++;
    await Future.delayed(Duration(milliseconds: 200));
    print("published video $i/${videos.length} - ${videoData['title']}");
  }
}

Future<Map<String, dynamic>> loadJson() async {
  String data = await rootBundle.loadString('assets/pixabay_videos.json');
  return jsonDecode(data);
}

Future<void> removeAllCurrentVideos() async {
  QuerySnapshot snapshot = await firestore.collection('videos').get();
  for (DocumentSnapshot doc in snapshot.docs) {
    await doc.reference.delete();
  }
}
Future<void> removeAllUsers() async {
  QuerySnapshot snapshot = await firestore.collection('users').where("username", isNotEqualTo: "julian").get();
  for (DocumentSnapshot doc in snapshot.docs) {
    await doc.reference.delete();
  }
}
Future<void> removeAllPreferencesOfCurrentUser() async {
  String userId = auth!.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> profilePreferences = firestore.collection('users').doc(userId).collection("profile").doc("preferences");
  profilePreferences.set({
    "recommendationProfile": {
      "tagVector": {},
      "authorVector": {},
      "avgCompletionRate": 0.0,
      "totalInteractions": 0,
      "lastUpdated": FieldValue.serverTimestamp(),
    }
  }, SetOptions(merge: true));
}

Future<void> getVideoFromJsonDataObject(Map<String, dynamic> data, VideoRepository videoRepo) async {
  await createDummyUserModel(data['author'], "${data['author_id']}", data['thumbnail']);
  await videoRepo.publishVideo(title: data['title'] ?? 'Video by ${data['author'] ?? '[Unknown User]'}', description: data['description'] ?? 'No Description Provided', videoUrl: data['url']!, thumbnailUrl: null, authorId: "${data['author_id']}", tags: List<String>.from(data['tags'] ?? []));
}
Set<String> createdUserIds = {};
Future<UserProfile?> createDummyUserModel(String name, String id, String profileImageUrl) async {
  if(createdUserIds.contains(id)) {
    return null;
  }
  createdUserIds.add(id);
  UserProfile user = await userRepository!.createUser(id: id, username: name, profileImageUrl: profileImageUrl);
  return user;
}