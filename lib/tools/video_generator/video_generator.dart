import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wurp/logic/repositories/video_repository.dart';

import '../../logic/models/user_model.dart';
import '../../main.dart';

class VideoGenerator {}

void videoPublishTest() async {
  VideoRepository videoRepo = VideoRepository();
  Map<String, dynamic> json = await loadJson();
  final videos = (json['data'] as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  for (var videoData in videos) {
    await getVideoFromJsonDataObject(videoData, videoRepo);
  }
}

Future<Map<String, dynamic>> loadJson() async {
  String data = await rootBundle.loadString('assets/pixabay_videos.json');
  return jsonDecode(data);
}


Future<void> getVideoFromJsonDataObject(Map<String, dynamic> data, VideoRepository videoRepo) async {
  await createDummyUserModel(data['author'], "${data['author_id']}", data['thumbnail']);
  videoRepo.publishVideo(title: data['title'] ?? 'Video by ${data['author'] ?? '[Unknown User]'}', description: data['description'] ?? 'No Description Provided', videoUrl: data['url']!, thumbnailUrl: null, authorId: "${data['author_id']}", tags: List<String>.from(data['tags'] ?? []));
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