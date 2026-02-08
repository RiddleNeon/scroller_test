import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:wurp/logic/repositories/video_repository.dart';

import '../../firebase_options.dart';
import '../../main.dart';

class VideoGenerator {}

void videoPublishTest() async {
  String title = "Test Video";
  String description = "This is a test video generated for testing purposes.";
  String videoUrl = "https://example.com/video.mp4";
  String thumbnailUrl = "https://example.com/thumbnail.jpg";
  String authorId = auth!.currentUser!.uid;
  List<String> tags = ["test", "video", "generator"];
  VideoRepository videoRepo = VideoRepository();
  
  
  print("Publishing test video... (user is ${auth?.currentUser})");
  videoRepo.publishVideo(title: title, description: description, videoUrl: videoUrl, thumbnailUrl: thumbnailUrl, authorId: authorId, tags: tags);
  print("Test video published successfully.");
}
