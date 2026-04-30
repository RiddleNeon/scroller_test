import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lumox/logic/repositories/user_repository.dart';
import 'package:lumox/logic/repositories/video_repository.dart';
import 'package:lumox/tools/supabase_tests/supabase_login_test.dart';

///   to make the import idempotent.

void main() async {
  const String key = String.fromEnvironment("YOUTUBE_API_KEY");
  YouTubeShortsFetcher fetcher = YouTubeShortsFetcher(key);
  final channelId = await getChannelIdFromName(key, "Fireship");
  print(await fetcher.fetchFromChannels([channelId!]));
}

Future<String?> getChannelIdFromName(String apiKey, String channelName) async {
  final url =
      "https://www.googleapis.com/youtube/v3/search"
      "?part=snippet"
      "&q=$channelName"
      "&type=channel"
      "&maxResults=1"
      "&key=$apiKey";

  final res = await http.get(Uri.parse(url));
  final data = jsonDecode(res.body);
  
  print("Channel search response: ${res.body}");

  if (data["items"].isEmpty) return null;

  return data["items"][0]["snippet"]["channelId"];
}



Future<void> publishTest() async {
  final file = await rootBundle.loadString("pixabay_videos.json");
  final allLinksFile = await rootBundle.loadString("all_cloudinary_image_urls"); 
  parseCloudinaryUrls(allLinksFile);
  final Map<String, dynamic> json = jsonDecode(file);
  final List<dynamic> items = json['data'] as List<dynamic>;

  print('Found ${items.length} video(s) to import.\n');

  final userRepo = UserRepository();
  final videoRepo = VideoRepository();
  final importer = BulkVideoImporter(userRepo: userRepo, videoRepo: videoRepo);

  await importer.importAll(items.take(1000).toList().cast<Map<String, dynamic>>());

  print('\nDone.');
}

Future<void> publishTestYoutube() async {
  final file = await rootBundle.loadString("youtube_videos.json"); 
  final Map<String, dynamic> json = jsonDecode(file);
  final List<dynamic> items = json['data'] as List<dynamic>;

  print('Found ${items.length} video(s) to import.\n');

  final userRepo = UserRepository();
  final videoRepo = VideoRepository();
  final importer = BulkVideoImporter(userRepo: userRepo, videoRepo: videoRepo);

  await importer.importAll(items.take(1000).toList().cast<Map<String, dynamic>>());

  print('\nDone. published ${items.length} videos from YouTube Shorts.');
}

Map<String, String> cloudinaryUrlMap = {};

void parseCloudinaryUrls(String fileContent) {
  final lines = fileContent.split('\n');
  for (var line in lines) {
    if (!line.contains(".webp")) {
      continue;
    }
    final importantPart = line.substring(62).replaceAll(".webp", "");
    final underscoreIndex = importantPart.lastIndexOf('_');
    final datePart = importantPart.substring(0, underscoreIndex);
    cloudinaryUrlMap[datePart] = line.trim();
  }
}

class BulkVideoImporter {
  final UserRepository userRepo;
  final VideoRepository videoRepo;

  final Map<String, String> _authorIdCache = {};

  BulkVideoImporter({required this.userRepo, required this.videoRepo});

  Future<void> importAll(List<Map<String, dynamic>> items) async {
    int created = 0;
    int skipped = 0;
    items.shuffle();

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      print('[${i + 1}/${items.length}] Processing "${item['title']?.toString()}..."');

      try {
        bool result = await _importOne(item);
        if (result) {
          created++;
          print("Created new video");
        } else {
          skipped++;
          print("Skipped (already existed)");
        }
      } catch (e, st) {
        print('Error: $e');
        print(st);
      }
    }

    print('\nImport complete — $created created, $skipped skipped (already existed).');
  }

  Future<bool> _importOne(Map<String, dynamic> item) async {
    final String videoUrl = item['url'] as String;
    final String title = item['title'] as String? ?? '';
    final List<String> tags = (item['tags'] as List<dynamic>? ?? []).cast<String>();
    final String authorUsername = item['author'] as String? ?? 'unknown';
    final String externalAuthorId = item['author_id'].toString();
    final String? authorProfileImageUrl = item['author_profile_image'] as String?;
    final int views = item['views'] as int? ?? 0;
    final int likes = item['likes'] as int? ?? 0;
    final String raw = videoUrl.replaceAll('https://cdn.pixabay.com/video/', '').replaceAll('_large.mp4', '').replaceAll('/', '_');
    final String thumbnailUrl = cloudinaryUrlMap[raw] ?? item['thumbnail_url'] as String? ?? '';
    final String description = item['description'] as String? ?? 'automatically generated video for testing';
    final int durationInSec = item['duration'] as int? ?? 0;

    final String supabaseAuthorId = await _resolveAuthorId(
      externalAuthorId: externalAuthorId,
      username: authorUsername,
      profileImageUrl: (authorProfileImageUrl?.isEmpty ?? true) ? null : authorProfileImageUrl,
    );
    if (await _videoUrlExists(videoUrl)) {
      print('Skipped (URL already in DB)');
      return false;
    } else {
      print('Publishing new video for "$title" by "$authorUsername" (author ID: $supabaseAuthorId)');
    }

    await videoRepo.publishVideoSupabase(
      title: title,
      description: description,
      videoUrl: videoUrl,
      authorId: supabaseAuthorId,
      tags: tags,
      thumbnailUrl: thumbnailUrl,
    );

    if (views > 0 || likes > 0) {
      await _backfillMetrics(videoUrl, supabaseAuthorId, durationInSec: durationInSec, isYoutubeVid: videoUrl.contains("youtube.com"), views: views, likes: likes);
    }

    print('Published (views: $views, likes: $likes)');
    return true;
  }
  
  Future<String> _resolveAuthorId({required String externalAuthorId, required String username, String? profileImageUrl}) async {
    if (_authorIdCache.containsKey(externalAuthorId)) {
      return _authorIdCache[externalAuthorId]!;
    }
    
    const marker = 'pixabay_author_id:';
    final markerValue = '$marker$externalAuthorId';

    // Search for existing profile by the bio marker.
    final existing = await supabaseClient.from('profiles').select('id').ilike('bio', '%$markerValue%').maybeSingle();

    if (existing != null) {
      final id = existing['id'] as String;
      _authorIdCache[externalAuthorId] = id;
      print('Reusing existing profile for "$username" ($id)');
      return id;
    }
    
    
    final generatedId = _deterministicUuid(externalAuthorId);

    await userRepo.createUser(id: generatedId, username: username, bio: markerValue, profileImageUrl: profileImageUrl);

    _authorIdCache[externalAuthorId] = generatedId;
    print('Created new profile for "$username" ($generatedId)');
    return generatedId;
  }

  Future<bool> _videoUrlExists(String url) async {
    final result = await supabaseClient.from('videos').select('id').eq('video_url', url).maybeSingle();
    return result != null;
  }

  Future<void> _backfillMetrics(String videoUrl, String authorId, {required int views, required int likes, required int durationInSec, bool? isYoutubeVid}) async {
    isYoutubeVid ??= videoUrl.contains("youtube.com") || videoUrl.contains("youtu.be");
    
    try {
      print('Looking up video ID for backfilling metrics...');
      final row = await supabaseClient.from('videos').select('id').eq('video_url', videoUrl).maybeSingle();

      print('Backfilling metrics for video ID ${row?['id']} (views: $views, likes: $likes)');

      if (row == null) return;
      final int videoId = row['id'] as int;

      await supabaseClient.from('videos').update({'duration_s': durationInSec, 'is_youtube': isYoutubeVid}).eq('id', videoId);


      if (views > 0) {
        await supabaseClient.rpc('_increment_video_metric', params: {'p_video_id': videoId, 'p_column': 'view_count', 'p_delta': views});
        print('Incremented view count by $views');
      }
      if (likes > 0) {
        await supabaseClient.rpc('_increment_video_metric', params: {'p_video_id': videoId, 'p_column': 'like_count', 'p_delta': likes});
        await supabaseClient.rpc('increment_profile_metric', params: {'p_user_id': authorId, 'p_column': 'total_likes_count', 'p_delta': likes});
        print('Incremented like count by $likes');
      }
    } catch (e) {
      print('Could not back-fill metrics: $e');
    }
  }
  
  String _deterministicUuid(Object value) {
    if (value is int) {
      return _uuidFromSeed(value);
    }

    final s = value.toString();
    final hash = md5.convert(utf8.encode(s)).bytes;
    int seed = 0;
    for (var i = 0; i < 6; i++) {
      seed = (seed << 8) | (hash[i] & 0xFF);
    }
    return _uuidFromSeed(seed);
  }

  String _uuidFromSeed(int seed) {
    final paddedId = seed.toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$paddedId';
  }
}

class YouTubeShort {
  final String url;
  final String title;
  final String description;
  final List<String> tags;
  final String author;
  final String authorId;
  final String authorProfileImageUrl;
  final int views;
  final int likes;
  final int duration;
  final String thumbnailUrl;
  final String videoId;

  YouTubeShort({
    required this.url,
    required this.title,
    required this.description,
    required this.tags,
    required this.author,
    required this.authorId,
    required this.views,
    required this.likes,
    required this.duration,
    required this.thumbnailUrl,
    required this.videoId,
    required this.authorProfileImageUrl,
  });

  Map<String, dynamic> toJson() => {
    "url": url,
    "title": title,
    "description": description,
    "tags": tags,
    "author": author,
    "author_id": authorId,
    "views": views,
    "likes": likes,
    "duration": duration,
    "thumbnail_url": thumbnailUrl,
    "video_id": videoId,
    "author_profile_image": authorProfileImageUrl,
  };
}

class YouTubeShortsFetcher {
  final String apiKey;

  YouTubeShortsFetcher(this.apiKey);

  Future<String> fetchFromChannels(List<String> channelIds) async {
    List<YouTubeShort> results = [];

    for (var channelId in channelIds) {
      final uploadsPlaylistId = await _getUploadsPlaylistId(channelId);

      final videoIds = await _getAllVideoIdsFromPlaylist(uploadsPlaylistId, limit: 180); 

      final videos = await _getVideoDetails(videoIds);

      results.addAll((videos..sort((a, b) => b.likes.compareTo(a.likes))).where((v) => v.duration < 58 && v.duration > 2 && v.likes > 8000 && v.tags.length > 2).take(70)); // Filter to likely shorts (duration < 60s) and some engagement, and sort by like count descending
    }

    return jsonEncode(results.map((e) => e.toJson()).toList());
  }

  Future<String> _getUploadsPlaylistId(String channelId) async {
    final url = "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&id=$channelId&key=$apiKey";

    final res = await http.get(Uri.parse(url));
    print("RESPONSE: ${res.body}");
    final data = jsonDecode(res.body);

    return data["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"];
  }

  Future<List<String>> _getAllVideoIdsFromPlaylist(String playlistId, {int? limit}) async {
    List<String> videoIds = [];
    String? nextPageToken;

    int fetchedCount = 0;
    do {
      if(limit != null && fetchedCount >= limit) {
        break;
      }
      final url =
          "https://www.googleapis.com/youtube/v3/playlistItems"
          "?part=contentDetails"
          "&playlistId=$playlistId"
          "&maxResults=${limit != null ? (limit - fetchedCount).clamp(1, 50) : 50}"
          "&pageToken=${nextPageToken ?? ""}"
          "&key=$apiKey";

      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);

      for (var item in data["items"]) {
        videoIds.add(item["contentDetails"]["videoId"]);
      }

      nextPageToken = data["nextPageToken"];
    } while (nextPageToken != null);

    return videoIds;
  }

  Future<List<YouTubeShort>> _getVideoDetails(List<String> videoIds) async {
    List<YouTubeShort> videos = [];

    for (int i = 0; i < videoIds.length; i += 50) {
      final chunk = videoIds.sublist(i, i + 50 > videoIds.length ? videoIds.length : i + 50);

      final url =
          "https://www.googleapis.com/youtube/v3/videos"
          "?part=snippet,contentDetails,statistics"
          "&id=${chunk.join(",")}"
          "&key=$apiKey";

      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);

      for (var item in data["items"]) {
        final duration = _parseDuration(item["contentDetails"]["duration"]);

        final videoId = item["id"];

        videos.add(
          YouTubeShort(
            url: "https://www.youtube.com/watch?v=$videoId",
            title: item["snippet"]["title"],
            description: item["snippet"]["description"],
            tags: List<String>.from(item["snippet"]["tags"] ?? []),
            author: item["snippet"]["channelTitle"],
            authorId: item["snippet"]["channelId"],
            views: int.parse(item["statistics"]["viewCount"] ?? "0"),
            likes: int.parse(item["statistics"]["likeCount"] ?? "0"),
            duration: duration,
            // Not provided by API
            thumbnailUrl: "https://img.youtube.com/vi/$videoId/hqdefault.jpg",
            videoId: videoId,
            authorProfileImageUrl: await getChannelProfileImage(item["snippet"]["channelId"]) ?? '',
          ),
        );
      }
    }

    return videos;
  }

  final Map<String, String> _channelProfileImageCache = {};

  FutureOr<String?> getChannelProfileImage(String channelId) async {
    if (_channelProfileImageCache.containsKey(channelId)) {
      return _channelProfileImageCache[channelId];
    }

    final url =
        "https://www.googleapis.com/youtube/v3/channels"
        "?part=snippet"
        "&id=$channelId"
        "&key=$apiKey";

    final res = await http.get(Uri.parse(url));
    final data = jsonDecode(res.body);

    if (data["items"]?.isEmpty ?? true) return null;

    final profileImageUrl = data["items"][0]["snippet"]["thumbnails"]["high"]["url"];
    _channelProfileImageCache[channelId] = profileImageUrl;

    return profileImageUrl;
  }

  int _parseDuration(String isoDuration) {
    final regex = RegExp(r'PT((\d+)M)?((\d+)S)?');
    final match = regex.firstMatch(isoDuration);

    int minutes = int.tryParse(match?.group(2) ?? "0") ?? 0;
    int seconds = int.tryParse(match?.group(4) ?? "0") ?? 0;

    return minutes * 60 + seconds;
  }
}
