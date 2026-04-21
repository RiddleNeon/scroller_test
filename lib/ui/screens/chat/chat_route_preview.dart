import 'package:wurp/base_logic.dart';
import 'package:wurp/logic/repositories/video_repository.dart';
import 'package:wurp/logic/users/user_model.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

class ChatRouteReference {
  final String raw;
  final Uri uri;

  const ChatRouteReference({required this.raw, required this.uri});

  String get route => uri.toString();
}

enum ChatRoutePreviewType { feed, quests, chat, search, themes }

class ChatRoutePreview {
  final ChatRoutePreviewType type;
  final String title;
  final String subtitle;
  final String route;
  final String? thumbnailUrl;
  final String? avatarUrl;

  const ChatRoutePreview({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.route,
    this.thumbnailUrl,
    this.avatarUrl,
  });
}

class ChatRoutePreviewResolver {
  static final RegExp _inAppRouteRegex = RegExp(r'(?<!\S)(/\S+)');

  const ChatRoutePreviewResolver._();

  static List<ChatRouteReference> extract(String text) {
    final seen = <String>{};
    final refs = <ChatRouteReference>[];
    for (final match in _inAppRouteRegex.allMatches(text)) {
      final raw = match.group(1);
      if (raw == null || raw.isEmpty) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.path.isEmpty) continue;
      if (!_isSupportedPath(uri.path)) continue;
      final canonical = uri.toString();
      if (seen.add(canonical)) {
        refs.add(ChatRouteReference(raw: raw, uri: uri));
      }
    }
    return refs;
  }

  static bool isRoutableToken(String token) {
    final uri = Uri.tryParse(token);
    return uri != null && uri.path.isNotEmpty && _isSupportedPath(uri.path);
  }

  static Future<ChatRoutePreview?> resolve(ChatRouteReference routeRef) async {
    final path = routeRef.uri.path;
    if (path.startsWith('/feed/')) {
      return _resolveVideo(routeRef);
    }
    if (path == '/quests') {
      return _resolveQuests(routeRef);
    }
    if (path.startsWith('/chat')) {
      return _resolveChat(routeRef);
    }
    if (path == '/search') {
      return _resolveSearch(routeRef);
    }
    if (path == '/themes') {
      return _resolveThemes(routeRef);
    }
    return null;
  }

  static bool _isSupportedPath(String path) {
    return path.startsWith('/feed/') || path == '/quests' || path.startsWith('/chat') || path == '/search' || path == '/themes';
  }

  static Future<ChatRoutePreview?> _resolveVideo(ChatRouteReference routeRef) async {
    final videoId = routeRef.uri.pathSegments.length >= 2 ? routeRef.uri.pathSegments[1] : '';
    if (videoId.isEmpty) return null;

    final Video? video = await videoRepo.getVideoByIdSupabase(videoId);
    if (video == null) return null;
    final UserProfile? author = await userRepository.getUserSupabase(video.authorId);
    return ChatRoutePreview(
      type: ChatRoutePreviewType.feed,
      title: video.title.isEmpty ? 'Untitled video' : video.title,
      subtitle: author == null ? 'by ${video.authorName}' : 'by ${author.displayName}',
      route: routeRef.route,
      thumbnailUrl: video.thumbnailUrl,
      avatarUrl: author?.profileImageUrl,
    );
  }

  static Future<ChatRoutePreview?> _resolveQuests(ChatRouteReference routeRef) async {
    final focus = routeRef.uri.queryParameters['focus'];
    final ids = (focus == null ? const <String>[] : focus.split(','))
        .map((id) => int.tryParse(id.trim()))
        .whereType<int>()
        .toList();

    if (ids.isEmpty) {
      return ChatRoutePreview(
        type: ChatRoutePreviewType.quests,
        title: 'Quest board',
        subtitle: 'Open quests map',
        route: routeRef.route,
      );
    }

    final rows = await supabaseClient
        .from('quests_latest')
        .select('quest_id, title, subject')
        .inFilter('quest_id', ids)
        .eq('is_deleted', false)
        .limit(3);
    final titles = (rows as List)
        .map((row) => (row['title'] as String?)?.trim() ?? '')
        .where((title) => title.isNotEmpty)
        .toList();
    final subject = rows.isNotEmpty ? (rows.first['subject'] as String? ?? 'General') : 'General';
    final subtitle = titles.isEmpty ? '${ids.length} focused quests in $subject' : '${titles.join(', ')}${ids.length > titles.length ? '...' : ''}';

    return ChatRoutePreview(
      type: ChatRoutePreviewType.quests,
      title: '${ids.length} focused quest${ids.length == 1 ? '' : 's'}',
      subtitle: subtitle,
      route: routeRef.route,
    );
  }

  static Future<ChatRoutePreview?> _resolveChat(ChatRouteReference routeRef) async {
    String? partnerId;
    if (routeRef.uri.pathSegments.length >= 2) {
      partnerId = routeRef.uri.pathSegments[1];
    }
    partnerId ??= routeRef.uri.queryParameters['user'];

    if (partnerId == null || partnerId.isEmpty) {
      return ChatRoutePreview(
        type: ChatRoutePreviewType.chat,
        title: 'Chats',
        subtitle: 'Open your messages',
        route: routeRef.route,
      );
    }

    final user = await userRepository.getUserSupabase(partnerId);
    if (user == null) {
      return ChatRoutePreview(
        type: ChatRoutePreviewType.chat,
        title: 'Chat',
        subtitle: 'Open conversation',
        route: routeRef.route,
      );
    }

    return ChatRoutePreview(
      type: ChatRoutePreviewType.chat,
      title: 'Chat with ${user.displayName}',
      subtitle: '@${user.username}',
      route: routeRef.route,
      avatarUrl: user.profileImageUrl,
    );
  }

  static Future<ChatRoutePreview?> _resolveSearch(ChatRouteReference routeRef) async {
    final query = routeRef.uri.queryParameters['q']?.trim() ?? '';
    if (query.isEmpty) {
      return const ChatRoutePreview(
        type: ChatRoutePreviewType.search,
        title: 'Search',
        subtitle: 'Open search screen',
        route: '/search',
      );
    }

    final scope = routeRef.uri.queryParameters['scope'];
    int videos = 0;
    int users = 0;
    if (scope == null || scope == 'all' || scope == 'videos') {
      videos = await videoRepo.countSearchVideos(query);
    }
    if (scope == null || scope == 'all' || scope == 'profiles') {
      users = await userRepository.countSearchUsers(query);
    }

    final subtitle = scope == 'videos'
        ? '$videos video results'
        : scope == 'profiles'
            ? '$users creator results'
            : '${videos + users} total results ($videos videos, $users creators)';

    return ChatRoutePreview(
      type: ChatRoutePreviewType.search,
      title: 'Search "$query"',
      subtitle: subtitle,
      route: routeRef.route,
    );
  }

  static Future<ChatRoutePreview?> _resolveThemes(ChatRouteReference routeRef) async {
    final tab = routeRef.uri.queryParameters['tab'];
    final tabLabel = tab == 'community' ? 'Community themes' : 'My themes';
    return ChatRoutePreview(
      type: ChatRoutePreviewType.themes,
      title: 'Themes',
      subtitle: tabLabel,
      route: routeRef.route,
    );
  }
}

