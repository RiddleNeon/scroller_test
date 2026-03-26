import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

///   to make the import idempotent.


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await publishTest();
}

/// Tool to bulk-import videos from a JSON file into Supabase.
///
/// Usage (from project root):
///   dart run bulk_video_importer.dart path/to/videos.json
///
/// The JSON format expected:
/// {
///   "data": [
///     {
///       "url": "https://...",
///       "title": "...",
///       "tags": ["tag1", "tag2"],
///       "author": "username",
///       "author_id": 12345678,
///       "views": 1000,
///       "likes": 50,
///       "duration": 0,
///       "thumbnail": "https://...",
///       "video_id": 326081
///     }
///   ]
/// }
///
/// What it does:
/// - For each unique author_id, ensures a profile exists in Supabase
///   (creates one via UserRepository.createUser if not found).
/// - Publishes each video via VideoRepository.publishVideoSupabase,
///   including title, tags, url, thumbnail and the Supabase author UUID.
/// - After publishing, sets the initial view/like counts via RPC so that
///   the imported metrics match the source data.
/// - Skips a video if its source URL is already present in the `videos` table
Future<void> publishTest() async { //todo republish, in case there were issues
  
  final file = await rootBundle.loadString("pixabay_videos.json"); //load the file as a string
  final allLinksFile = await rootBundle.loadString("all_cloudinary_image_urls"); //load the file as a string
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
Map<String, String> cloudinaryUrlMap = {};
void parseCloudinaryUrls(String fileContent) {
  final lines = fileContent.split('\n');
  for (var line in lines) {
    if(!line.contains(".webp")) {
      continue; // Skip lines that don't match the expected length
    }
    final importantPart = line.substring(62).replaceAll(".webp", ""); // Remove the first 63 characters
    final underscoreIndex = importantPart.lastIndexOf('_');
    final datePart = importantPart.substring(0, underscoreIndex);
    cloudinaryUrlMap[datePart] = line.trim();
  }
}

class BulkVideoImporter {
  final UserRepository userRepo;
  final VideoRepository videoRepo;

  // Cache external-author-id → Supabase UUID so we only resolve once per run.
  final Map<int, String> _authorIdCache = {};

  BulkVideoImporter({required this.userRepo, required this.videoRepo});

  Future<void> importAll(List<Map<String, dynamic>> items) async {
    int created = 0;
    int skipped = 0;
    items.shuffle(); // Shuffle to mix authors and videos for better testing of the caching and parallelism

    for (int i = 0; i < 5; i++) {
      final item = items[i];
      print('[${i + 1}/${items.length}] Processing "${item['title']?.toString()}..."');

      try {
        bool result = await _importOne(item);
        if (result) {
          created++;
          print("  ✅ Created new video");
        } else {
          skipped++;
          print("  ⏭  Skipped (already existed)");
        }
      } catch (e, st) {
        print('  ❌ Error: $e');
        print(st);
      }
    }

    print('\n✅ Import complete — $created created, $skipped skipped (already existed).');
  }

  /// Returns true if a new video was published, false if it was skipped.
  Future<bool> _importOne(Map<String, dynamic> item) async {
    final String videoUrl = item['url'] as String;
    final String title = item['title'] as String? ?? '';
    final List<String> tags = (item['tags'] as List<dynamic>? ?? []).cast<String>();
    final String authorUsername = item['author'] as String? ?? 'unknown';
    final int externalAuthorId = item['author_id'] as int;
    final String? authorProfileImageUrl = item['author_profile_image'] as String?;
    final int views = item['views'] as int? ?? 0;
    final int likes = item['likes'] as int? ?? 0;
    final String raw = videoUrl.replaceAll('https://cdn.pixabay.com/video/', '').replaceAll('_large.mp4', '').replaceAll('/', '_');
    final String thumbnailUrl = cloudinaryUrlMap[raw] ?? '';
    //final int durationMs = ((item['duration'] as num?)?.toInt() ?? 0) * 1000;

    // --- 1. Ensure author profile exists --------------------------------
    final String supabaseAuthorId = await _resolveAuthorId(
      externalAuthorId: externalAuthorId,
      username: authorUsername,
      profileImageUrl: (authorProfileImageUrl?.isEmpty ?? true) ? null : authorProfileImageUrl
    );

    // --- 2. Skip if video URL already imported --------------------------
    if (await _videoUrlExists(videoUrl)) {
      print('  ⏭  Skipped (URL already in DB)');
      return false;
    } else {
      print('  🎬 Publishing new video for "$title" by "$authorUsername" (author ID: $supabaseAuthorId)');
    }

    // --- 3. Publish video -----------------------------------------------
    await videoRepo.publishVideoSupabase(
      title: title,
      description: 'automatically generated video for testing',
      videoUrl: videoUrl,
      authorId: supabaseAuthorId,
      tags: tags,
      thumbnailUrl: thumbnailUrl,
    );

    // --- 4. Back-fill view / like counts from source data ---------------
    if (views > 0 || likes > 0) {
      await _backfillMetrics(videoUrl, supabaseAuthorId, views: views, likes: likes);
    }

    print('  ✅ Published (views: $views, likes: $likes)');
    return true;
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Returns the Supabase profile UUID for the given external author.
  /// Uses a deterministic UUID derived from the external author id so that
  /// re-runs always map to the same profile without requiring a lookup table.
  Future<String> _resolveAuthorId({
    required int externalAuthorId,
    required String username,
    String? profileImageUrl,
  }) async {
    if (_authorIdCache.containsKey(externalAuthorId)) {
      return _authorIdCache[externalAuthorId]!;
    }

    // We store the mapping in the profile's bio field with a marker so we can
    // look it up on subsequent runs.
    const marker = 'pixabay_author_id:';
    final markerValue = '$marker$externalAuthorId';

    // Search for existing profile by the bio marker.
    final existing = await supabaseClient
        .from('profiles')
        .select('id')
        .ilike('bio', '%$markerValue%')
        .maybeSingle();

    if (existing != null) {
      final id = existing['id'] as String;
      _authorIdCache[externalAuthorId] = id;
      print('  👤 Reusing existing profile for "$username" ($id)');
      return id;
    }

    // Profile not found – create one. We use createUser which upserts, so it
    // is safe to call multiple times.
    // Generate a stable UUID-like string from the external id.
    final generatedId = _deterministicUuid(externalAuthorId);

    await userRepo.createUser(
      id: generatedId,
      username: username,
      bio: markerValue,
      profileImageUrl: profileImageUrl
    );

    _authorIdCache[externalAuthorId] = generatedId;
    print('  👤 Created new profile for "$username" ($generatedId)');
    return generatedId;
  }

  /// Checks whether a video with this URL already exists in Supabase.
  Future<bool> _videoUrlExists(String url) async {
    final result = await supabaseClient
        .from('videos')
        .select('id')
        .eq('video_url', url)
        .maybeSingle();
    return result != null;
  }

  /// Fetches the newly inserted video by URL and sets view/like counts.
  Future<void> _backfillMetrics(
      String videoUrl,
      String authorId, {
        required int views,
        required int likes,
      }) async {
    try {
      print('  🔍 Looking up video ID for backfilling metrics...');
      final row = await supabaseClient
          .from('videos')
          .select('id')
          .eq('video_url', videoUrl)
          .maybeSingle();
      
      print('  🔧 Backfilling metrics for video ID ${row?['id']} (views: $views, likes: $likes)');

      if (row == null) return;
      final int videoId = row['id'] as int;

      if (views > 0) {
        print('  🔧 Incremented view count by $views');
        await supabaseClient.rpc('_increment_video_metric',
            params: {'p_video_id': videoId, 'p_column': 'view_count', 'p_delta': views});
      }
      if (likes > 0) {
        print('  🔧 Incremented like count by $likes');
        await supabaseClient.rpc('_increment_video_metric',
            params: {'p_video_id': videoId, 'p_column': 'like_count', 'p_delta': likes});
        await supabaseClient.rpc('increment_profile_metric',
            params: {'p_user_id': authorId, 'p_column': 'total_likes_count', 'p_delta': likes});
      }
    } catch (e) {
      print('⚠️ Could not back-fill metrics: $e');
    }
  }

  /// Creates a stable UUID-shaped string from the external author id.
  /// Format: 00000000-0000-4000-8000-author_id_padded
  /// Simple, JS-safe, and deterministic across runs.
  String _deterministicUuid(int seed) {
    final paddedId = seed.toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$paddedId';
  }
}
