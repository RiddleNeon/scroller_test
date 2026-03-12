import 'package:wurp/logic/models/user_model.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/video/video.dart';

import '../../../base_logic.dart';

class SearchBarResult {
  String searchText;
  List<Video> videoResults = [];
  List<UserProfile> userResults = [];
  int _videoOffset = 0;
  int _userOffset = 0;
  bool _hasMoreVideos = true;
  bool _hasMoreUsers = true;
  bool _isLoadingVideos = false;
  bool _isLoadingUsers = false;

  SearchBarResult(this.searchText);

  Future<void> complete({int limit = 20}) async {
    await Future.wait([loadVideos(limit: limit), loadUsers(limit: limit)]);
  }
  
  Future<void> loadVideos({int limit = 20}) async{
    if (_isLoadingVideos) return;
    _isLoadingVideos = true;
    
    
    final videoResult = await videoRepo.searchVideos(searchText, limit: limit);
    videoResults = videoResult.videos;
    print("done, results: ${videoResults}");
    _videoOffset = videoResult.nextOffset ?? _videoOffset;
    _hasMoreVideos = videoResult.nextOffset != null;

    _isLoadingVideos = false;
  }

  Future<void> loadUsers({int limit = 20}) async{
    if (_isLoadingUsers) return;
    _isLoadingUsers = true;

    final userResult = await userRepository.searchUsers(searchText, limit: limit);
    userResults = userResult.users;
    _userOffset = userResult.nextOffset ?? _userOffset;
    _hasMoreUsers = userResult.nextOffset != null;

    _isLoadingUsers = false;
  }

  Future<void> preloadMoreVideos({int limit = 20}) async {
    if (_isLoadingVideos || !_hasMoreVideos) return;
    _isLoadingVideos = true;

    final result = await videoRepo.searchVideosByTag(
      searchText,
      offset: _videoOffset,
      limit: limit
    );

    videoResults.addAll(result.videos);
    _videoOffset = result.nextOffset ?? _videoOffset;
    _hasMoreVideos = result.nextOffset != null;

    _isLoadingVideos = false;
  }
  
  Future<void> preloadMoreUsers({int limit = 20}) async {
    if (_isLoadingUsers || !_hasMoreUsers) return;
    _isLoadingUsers = true;

    final result = await userRepository.searchUsers(
      searchText,
      offset: _userOffset,
      limit: limit
    );

    userResults.addAll(result.users);
    _userOffset = result.nextOffset ?? _userOffset;
    _hasMoreUsers = result.nextOffset != null;

    _isLoadingUsers = false;
  }
}
