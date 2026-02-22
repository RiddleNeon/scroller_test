import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/next_try/search_bar_result.dart';

class SearchScreen extends StatefulWidget {
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  TextEditingController controller = TextEditingController();
  SearchBarResult? searchBarResult;
  bool loading = false;
  bool hasSearched = false;
  bool canShowSearchResults = false;

  static const double maxSearchBarHeight = 80;
  static const int animationDuration = 1000;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.white60],
              transform: GradientRotation(0.3),
            ),
          ),
          child: Stack(
            children: [
              _buildSearchBar(),
              Positioned(
                top: maxSearchBarHeight + 60,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height - maxSearchBarHeight, // offset by the search bar height and some padding
                child: buildSearchResultContent(),
              )
            ],
          )),
    );
  }

  void onAnimationEnd() {
    if (canShowSearchResults) return;
    Future.delayed(Duration(milliseconds: 200), () {
      setState(() {
        canShowSearchResults = true;
        print("done with animation");
      }); 
    });
  }

  Widget _buildSearchBar() {
    return AnimatedAlign(
      alignment: hasSearched ? Alignment.topCenter : Alignment.center,
      duration: Duration(milliseconds: animationDuration),
      curve: Curves.easeInOutCubic,
      onEnd: onAnimationEnd,
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600,
            minWidth: 300,
            maxHeight: maxSearchBarHeight,
          ),
          child: Material(
            elevation: 20,
            type: MaterialType.card,
            color: Colors.transparent,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hint: const Text('Search for ya stuff heeree', textAlign: TextAlign.center),
                hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 18),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.transparent),
                  borderRadius: BorderRadius.circular(40),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.transparent),
                  borderRadius: BorderRadius.circular(40),
                ),
                prefixIcon: const Icon(Icons.search, size: 36),
                prefixIconColor: Colors.black,
                suffixIcon: InkWell(
                  child: const Icon(Icons.send, size: 36),
                  borderRadius: const BorderRadius.all(Radius.circular(30)),
                  highlightColor: Colors.white,
                  hoverColor: Colors.white,
                  focusColor: Colors.white,
                  radius: 30,
                  onTap: _search,
                ),
                constraints: const BoxConstraints(minHeight: 28),
                isDense: false,
                fillColor: Colors.white,
                visualDensity: VisualDensity.adaptivePlatformDensity,
                filled: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _search() async {
    hasSearched = true;
    setState(() => loading = true);
    searchBarResult = SearchBarResult.fromFirestore(controller.text);
    await searchBarResult!.complete();
    setState(() => loading = false);
  }

  Widget buildSearchResultContent() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchBarResult == null) {
      return Container();
    }

    final videos = searchBarResult!.videoResults;
    if (videos.isEmpty) {
      return const Center(child: Text("No videos found"));
    }

    return AnimatedOpacity(
        opacity: canShowSearchResults ? 1 : 0,
        duration: Duration(milliseconds: 800),
        child: !canShowSearchResults
            ? SizedBox.expand()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  return Card(
                    elevation: 6,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => print("open video ${video.videoUrl}"),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 160,
                            height: 90,
                            child: ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)), child: buildVideoPreview(video)),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  );
                },
              ));
  }

  Map<String, Future<Uint8List?>> cachedImageData = {};

  Widget buildVideoPreview(Video video) {
    if (!(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      return Shimmer(child: Container(color: Colors.grey.shade300));
    }

    cachedImageData[video.videoUrl] ??= VideoThumbnail.thumbnailData(video: video.videoUrl);

    return FutureBuilder(
        future: cachedImageData[video.videoUrl],
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!);
          }
          return Shimmer(child: Container(color: Colors.grey.shade300));
        });
  }

  @override
  void dispose() {
    cachedImageData.clear();
    super.dispose();
  }
}
