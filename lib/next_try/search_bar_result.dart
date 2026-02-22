import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wurp/logic/models/user_model.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/main.dart';

class SearchBarResult {
  String searchText;
  List<Video> videoResults = [];
  List<UserProfile> userResults = [];
  DocumentSnapshot? _lastVideoDocument;
  DocumentSnapshot? _lastUserDocument;
  bool _hasMoreVideos = true;
  bool _hasMoreUsers = true;
  bool _isLoadingVideos = false;
  bool _isLoadingUsers = false;

  SearchBarResult.fromFirestore(this.searchText);

  Future<void> complete({int limit = 20}) async {
    await Future.wait([loadVideos(limit: limit), loadUsers(limit: limit)]);
  }
  
  Future<void> loadVideos({int limit = 20}) async{
    if (_isLoadingVideos) return;
    _isLoadingVideos = true;

    final videoResult = await videoRepo.searchVideos(searchText, limit: limit);
    videoResults = videoResult.videos;
    print("done, results: ${videoResults}");
    _lastVideoDocument = videoResult.lastDoc;
    _hasMoreVideos = videoResult.videos.length >= limit;

    _isLoadingVideos = false;
  }

  Future<void> loadUsers({int limit = 20}) async{
    if (_isLoadingUsers) return;
    _isLoadingUsers = true;

    final userResult = await userRepository!.searchUsers(searchText, limit: limit);
    userResults = userResult.users;
    _lastUserDocument = userResult.lastDoc;
    _hasMoreUsers = userResult.users.length >= limit;

    _isLoadingUsers = false;
  }

  Future<void> preloadMoreVideos({int limit = 20}) async {
    if (_isLoadingVideos || !_hasMoreVideos) return;
    _isLoadingVideos = true;

    final result = await videoRepo.searchVideos(
      searchText,
      startAfter: _lastVideoDocument,
      limit: limit
    );

    videoResults.addAll(result.videos);
    _lastVideoDocument = result.lastDoc;
    _hasMoreVideos = result.videos.length >= limit;

    _isLoadingVideos = false;
  }  
  
  Future<void> preloadMoreUsers({int limit = 20}) async {
    if (_isLoadingUsers || !_hasMoreUsers) return;
    _isLoadingUsers = true;

    final result = await userRepository!.searchUsers(
      searchText,
      startAfter: _lastUserDocument,
      limit: limit
    );

    userResults.addAll(result.users);
    _lastUserDocument = result.lastDoc;
    _hasMoreUsers = result.users.length >= limit;

    _isLoadingUsers = false;
  }
}