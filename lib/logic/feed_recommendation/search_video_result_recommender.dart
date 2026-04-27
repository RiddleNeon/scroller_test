import '../video/video.dart';
import '../video/video_provider.dart';

class SearchVideoResultRecommender extends VideoProvider {
  final List<Video> listedVideos;

  SearchVideoResultRecommender({required this.listedVideos});

  @override
  Future<Video?> getVideoByIndex(int index, {bool useYoutubeVideos = false}) async => listedVideos.elementAtOrNull(index); //todo

  @override
  Future<void> preloadVideos(int count, {bool useYoutubeVideos = false}) async {
    // nothing to preload
  }
}
