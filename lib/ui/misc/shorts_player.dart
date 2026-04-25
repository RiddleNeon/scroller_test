/*
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wurp/logic/video/video.dart';

class ShortPlayer extends StatefulWidget {
  final Video? video;

  const ShortPlayer({super.key, this.video});

  @override
  State<ShortPlayer> createState() => _ShortPlayerState();
}

class _ShortPlayerState extends State<ShortPlayer> {
  late final WebViewController _controller;

  final html = """
<!DOCTYPE html>
<html>
  <body style="margin:0">
    <div id="player"></div>

    <script src="https://www.youtube.com/iframe_api"></script>

    <script>
      var player;
      
      function notifyFlutterReady() {
        if (typeof window.playerReadyChannel !== "undefined") {
          console.log("Sending ready to Flutter");
          window.playerReadyChannel.postMessage("playerReady");
        } else {
          console.log("playerReadyChannel not defined, retrying...");
          setTimeout(notifyFlutterReady, 100);
        }
      }
    
      function initPlayer() {
        console.log("Creating player...");
        player = new YT.Player('player', {
          videoId: 'YDDHUQYh1yw',
          events: {            
            onReady: function () {
              window.location.href = "ready://player";
            }
          },
          playerVars: {
            autoplay: 1,
            controls: 0,
            playsinline: 1
          }
        });
      }
    
      function waitForYT() {
        if (typeof YT !== "undefined" && YT.Player) {
          console.log("YT API available");
          initPlayer();
        } else {
          console.log("Waiting for YT...");
          setTimeout(waitForYT, 100);
        }
      }
    
      // Script manuell laden
      var tag = document.createElement('script');
      tag.src = "https://www.youtube.com/iframe_api";
      document.body.appendChild(tag);
    
      // Start polling
      waitForYT();
    
      function pauseVideo() {
        console.log("Attempting to pause video...");
        if (player && player.getPlayerState) {
          var state = player.getPlayerState();
          
          // nur pausieren wenn wirklich playing
          if (state === YT.PlayerState.PLAYING) {
            player.pauseVideo();
            console.log("Paused!");
          } else {
            console.log("Not playing yet, can't pause:", state);
          }
        } else {
          console.log("Player not ready, can't pause");
        }
      }
    
      function playVideo() {
        if (player) player.playVideo();
      }
    </script>
  </body>
</html>
""";

  bool _isReady = false;

  Timer? _pauseTimer;
  Timer? _playTimer;
  
  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'playerReadyChannel',
        onMessageReceived: (message) {
          if (message.message == 'playerReady') {
            setState(() {
              _isReady = true;
            });
          }
        },
      );
    print("Loading HTML into WebView...");
    _controller.loadHtmlString(html);

    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (url) {
          print("Page loaded");
        },
        onWebResourceError: (error) {
          print("Web error: $error");
        },
      ),
    );

    _playTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isReady) {
        _controller.runJavaScript("""
        player.loadVideoById('${widget.video?.id}');
      """);
        timer.cancel();
      }
    });

    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isReady) {
        _controller.runJavaScript("if (typeof player !== 'undefined') pauseVideo();");
        print("paused video");
      } else {
        print("player not ready yet");
      }
    });
  }
  
  @override
  void dispose() {
    _playTimer?.cancel();
    _pauseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),

        Center(
          child: GestureDetector(
            onTap: () {
              _controller.runJavaScript("playVideo()");
            },
            onDoubleTap: () {
              _controller.runJavaScript("pauseVideo()");
            },
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}
*/

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class ShortVideo {
  final String id;

  ShortVideo(this.id);
}

class ShortsFeed extends StatefulWidget {
  const ShortsFeed({super.key});

  @override
  State<ShortsFeed> createState() => _ShortsFeedState();
}

class _ShortsFeedState extends State<ShortsFeed> {
  final PageController _pageController = PageController();

  final videos = [ShortVideo('YDDHUQYh1yw'), ShortVideo('dQw4w9WgXcQ'), ShortVideo('3JZ_D3ELwOQ')];

  final Map<int, YoutubePlayerController> _controllers = {};

  int _currentIndex = 0;

  YoutubePlayerController _createController(String videoId) {
    return YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(showControls: false, showFullscreenButton: false, mute: true, loop: true, playsInline: true, pointerEvents: .none, enableCaption: false),
    )..loadVideoById(videoId: videoId);
  }

  void _onPageChanged(int index) {
    // pause old
    _controllers[_currentIndex]?.close();

    // create controller if needed
    _controllers[index] ??= _createController(videos[index].id);

    // play new
    //_controllers[index]!.playVideo();

    _currentIndex = index;
  }

  @override
  void initState() {
    super.initState();

    // preload first video
    _controllers[0] = _createController(videos[0].id);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: videos.length,
      itemBuilder: (context, index) {
        _controllers[index] ??= _createController(videos[index].id);

        return ShortVideoPage(controller: _controllers[index]!);
      },
    );
  }
}

class ShortVideoPage extends StatelessWidget {
  final YoutubePlayerController controller;

  const ShortVideoPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(child: YoutubePlayer(gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{}, controller: controller, aspectRatio: 9 / 16)),
        Center(child: PointerInterceptor(child: const AspectRatio(aspectRatio: 9 / 16))),

        // tap overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: () async {
              print("tapped video, checking state...");
              final state = await controller.playerState;
              if (state == PlayerState.playing) {
                controller.pauseVideo();
              } else {
                controller.playVideo();
              }
            },
          ),
        ),
      ],
    );
  }
}
