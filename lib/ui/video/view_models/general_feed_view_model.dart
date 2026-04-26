import 'package:wurp/logic/video/video.dart';
import 'package:wurp/logic/video/video_provider.dart';
import 'package:wurp/ui/video/video_container.dart';
import 'package:wurp/ui/video/view_models/video_feed_view_model.dart';
import 'package:wurp/ui/video/view_models/youtube_feed_view_model.dart';
import 'package:wurp/base_logic.dart' as base_logic;

class GeneralFeedViewModel {
  VideoProvider? videoProvider;
  
  YoutubeFeedViewModel youtubeFeedViewModel;
  VideoFeedViewModel videoFeedViewModel;

  GeneralFeedViewModel({this.videoProvider, YoutubeFeedViewModel? ytFeedViewModel, VideoFeedViewModel? videoFeedViewModel})
      : youtubeFeedViewModel = ytFeedViewModel ?? base_logic.youtubeFeedViewModel,
        videoFeedViewModel = videoFeedViewModel ?? base_logic.feedViewModel;

  Future<VideoContainer> getVideoContainerAt(int index, {VideoProvider? customVideoProvider}) async {
    final usedVideoProvider = videoProvider ?? customVideoProvider;
    assert(usedVideoProvider != null, "VideoProvider must be provided to get a video container at index $index.");
    
    final video = await usedVideoProvider!.getVideoByIndex(index);
    if(video == null) {
      throw Exception("No video found at index $index");
    }
    
    final isYoutubeVideo = video.videoUrl.contains("youtube.com") || video.videoUrl.contains("youtu.be");
    if(isYoutubeVideo) {
      return youtubeFeedViewModel.getVideoContainerAt(index, video);
    } else {
      return videoFeedViewModel.getVideoContainerAt(index, video);
    }
  }

  Future<void> switchToVideoContainerAt(int index, {VideoProvider? customVideoProvider}) async {
    final VideoProvider? usedVideoProvider = videoProvider ?? customVideoProvider;
    assert(usedVideoProvider != null, "VideoProvider must be provided to switch to a video container at index $index.");
    
    final video = await usedVideoProvider!.getVideoByIndex(index);
    if(video == null) {
      throw Exception("No video found at index $index");
    }
    final isYoutubeVideo = video.videoUrl.contains("youtube.com") || video.videoUrl.contains("youtu.be");
    if(isYoutubeVideo) {
      await youtubeFeedViewModel.switchToVideoContainerAt(index, video);
    } else {
      await videoFeedViewModel.switchToVideoContainerAt(index, video);
    }
  }
  
  Future<void> ensureCurrentVideoPlays(Video video){
    final isYoutubeVideo = video.videoUrl.contains("youtube.com") || video.videoUrl.contains("youtu.be");
    if(isYoutubeVideo) {
      return youtubeFeedViewModel.ensureCurrentVideoPlays(video);
    } else {
      return videoFeedViewModel.ensureCurrentVideoPlays(video);
    }
  }

  Future<void> dispose() async { 
    await youtubeFeedViewModel.dispose();
    await videoFeedViewModel.dispose();
  }

  Future<void> pauseAll() async {
    await youtubeFeedViewModel.pauseAll();
    await videoFeedViewModel.pauseAll();
  }
  
  GeneralFeedViewModel copyWith({VideoProvider? videoProvider, YoutubeFeedViewModel? ytFeedViewModel, VideoFeedViewModel? videoFeedViewModel}) {
    return GeneralFeedViewModel(
      videoProvider: videoProvider ?? this.videoProvider,
      ytFeedViewModel: ytFeedViewModel ?? youtubeFeedViewModel,
      videoFeedViewModel: videoFeedViewModel ?? this.videoFeedViewModel,
    );
  }
  
}