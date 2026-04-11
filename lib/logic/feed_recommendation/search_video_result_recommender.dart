import '../video/video.dart';
import '../video/video_provider.dart';

class SearchVideoResultRecommender extends VideoProvider {
  final List<Video> listedVideos;

  SearchVideoResultRecommender({required this.listedVideos});

  @override
  Future<Video?> getVideoByIndex(int index) async => listedVideos.elementAtOrNull(index);

  @override
  Future<void> preloadVideos(int count) async {
    // nothing to preload
  }
}
