import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_file_saver/flutter_web_file_saver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wurp/base_ui.dart';
import 'package:wurp/logic/themes/theme_model.dart';
import 'package:wurp/ui/theme/theme_editor_screen.dart';

import 'app_theme.dart';

class ThemeManagerScreen extends StatefulWidget {
  const ThemeManagerScreen({super.key});

  @override
  State<ThemeManagerScreen> createState() => _ThemeManagerScreenState();
}

class _ThemeManagerScreenState extends State<ThemeManagerScreen> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  List<CustomThemeModel> _myThemes = [];
  List<CustomThemeModel> _communityThemes = [];
  String? _selectedThemeId;
  bool _loadingMine = true;
  bool _loadingCommunity = true;

  final Set<String> _likedIds = {};

  static final CustomThemeModel _defaultTheme = CustomThemeModel(
    id: 'default',
    name: 'Default Cappuccino',
    colors: CustomThemeColors.fromPrimary(AppTheme.lightScheme.primary, dark: false),
  );

  static final CustomThemeModel _defaultThemeDark = CustomThemeModel(
    id: 'default-dark',
    name: 'Default Cappuccino - Dark',
    colors: CustomThemeColors.fromPrimary(AppTheme.lightScheme.primary, dark: true),
  );

  @override
  void initState() {
    super.initState();
    _loadMyThemes();
    _loadCommunityThemes();
    _loadLikedIds();
  }

  String? get _uid => _supabase.auth.currentUser?.id;

  Future<void> _loadMyThemes() async {
    if (_uid == null) return;
    try {
      final res = await _supabase.from('themes').select().eq('created_by', _uid!);
      if (mounted) {
        setState(() {
          _myThemes = (res..removeWhere((element) => (element['id'] == defaultLightThemeId || element['id'] == defaultDarkThemeId))).map((e) => CustomThemeModel.fromJson(e)).toList();
          _loadingMine = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading my themes: $e');
      if (mounted) setState(() => _loadingMine = false);
    }
  }

  Future<void> _loadCommunityThemes() async {
    try {
      final res = await _supabase.from('themes').select().eq('is_public', true).order('likes_count', ascending: false);
      if (mounted) {
        setState(() {
          _communityThemes = (res as List)
              .where((element) => element['id'] != defaultDarkThemeId && element['id'] != defaultLightThemeId)
              .map((e) => CustomThemeModel.fromJson(e))
              .toList();
          _loadingCommunity = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading community themes: $e');
      if (mounted) setState(() => _loadingCommunity = false);
    }
  }

  Future<void> _loadLikedIds() async {
    if (_uid == null) return;
    try {
      final res = await _supabase.from('theme_likes').select('theme_id').eq('user_id', _uid!);
      if (mounted) {
        setState(() {
          _likedIds.addAll((res as List).map((e) => e['theme_id'] as String));
        });
      }
    } catch (_) {}
  }

  Future<void> _saveTheme(CustomThemeModel theme) async {
    try {
      final existing = await _supabase.from('themes').select().eq('id', theme.id).maybeSingle() != null;

      if (!existing) {
        await _supabase.from('themes').insert(theme.toJson());
      } else {
        await _supabase.from('themes').update(theme.toJson()).eq('id', theme.id);
      }
      await _loadMyThemes();
      await _loadCommunityThemes();
      if (_selectedThemeId == theme.id) await applyTheme(theme.id, false);
      if (!mounted) return;
      showSnackBar(context, 'Theme Uploaded!');
    } catch (e) {
      debugPrint('Error uploading theme: $e');
      if (!mounted) return;
      showSnackBar(context, 'Error when saving: $e');
    }
  }

  Future<void> _deleteTheme(CustomThemeModel theme) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('delete theme?'),
        content: Text('"${theme.name}" will be deleted permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _supabase.from('themes').delete().eq('id', theme.id);
      setState(() {
        _myThemes.removeWhere((t) => t.id == theme.id);
        if (_selectedThemeId == theme.id) _selectedThemeId = null;
      });
    } catch (e) {
      debugPrint('Error deleting theme: $e');
    }
  }

  Future<void> _toggleLike(String themeId) async {
    if (_uid == null) return;
    final isLiked = _likedIds.contains(themeId);
    try {
      final currentLikes = _communityThemes.firstWhere((t) => t.id == themeId, orElse: () => _defaultTheme).likesCount;
      if (isLiked) {
        await _supabase.from('theme_likes').delete().eq('theme_id', themeId).eq('user_id', _uid!);
        await _supabase.from('themes').update({'likes_count': currentLikes - 1}).eq('id', themeId);
        setState(() {
          _likedIds.remove(themeId);
          final idx = _communityThemes.indexWhere((t) => t.id == themeId);
          if (idx != -1) {
            _communityThemes[idx] = _communityThemes[idx].copyWith(likesCount: (_communityThemes[idx].likesCount - 1).clamp(0, 999999));
          }
        });
      } else {
        await _supabase.from('theme_likes').insert({'theme_id': themeId, 'user_id': _uid!});
        await _supabase.from('themes').update({'likes_count': currentLikes + 1}).eq('id', themeId);
        setState(() {
          _likedIds.add(themeId);
          final idx = _communityThemes.indexWhere((t) => t.id == themeId);
          if (idx != -1) {
            _communityThemes[idx] = _communityThemes[idx].copyWith(likesCount: _communityThemes[idx].likesCount + 1);
          }
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      await _loadCommunityThemes();
      await _loadLikedIds();
    }
  }

  Future<void> applyTheme(String id, [bool pushToServer = true]) async {
    if(_selectedThemeId == id) return;
    setState(() => _selectedThemeId = id);
    appThemeNotifier.value = (getTheme(id), id);
    if (id == 'default' || id == defaultLightThemeId) {
      await _supabase.from("applied_themes").upsert({'user_id': _uid, 'theme_id': defaultLightThemeId});
    } else if (id == 'default-dark' || id == defaultDarkThemeId) {
      await _supabase.from("applied_themes").upsert({'user_id': _uid, 'theme_id': defaultDarkThemeId});
    } else {
      await _supabase.from("applied_themes").upsert({'user_id': _uid, 'theme_id': id});
    }

    if (!mounted) return;
    //showSnackBar(context, 'Theme applied!');
  }

  Future<void> _openEditor({CustomThemeModel? existing}) async {
    final result = await Navigator.push<CustomThemeModel>(context, MaterialPageRoute(builder: (_) => ThemeEditorScreen(existingTheme: existing)));
    if (result != null) await _saveTheme(result);
  }

  Future<void> _exportTheme() async {
    if (_selectedThemeId == null) {
      showSnackBar(context, 'Choose a theme first.');

      return;
    }
    final theme = [_defaultTheme, _defaultThemeDark, ..._myThemes].firstWhere((t) => t.id == _selectedThemeId!, orElse: () => _defaultThemeDark);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(theme.toJson());
    await FlutterWebFileSaver.saveText(content: jsonStr, filename: "${theme.name.replaceAll(' ', '_')}.json");
    if (!mounted) return;
    showSnackBar(context, 'Exported!}');
  }

  Future<void> _importTheme() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (result == null) return;

      final file = result.files.first.bytes!;
      final fileAsString = utf8.decode(file);
      final json = jsonDecode(fileAsString) as Map<String, dynamic>;
      final imported = CustomThemeModel.fromJson(json).copyWith(id: const Uuid().v4(), isPublic: false);
      await _saveTheme(imported);
      if (!mounted) return;
      showSnackBar(context, '"${imported.name}" imported!');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Import failed: $e');
    }
  }

  ThemeData getTheme(String id) {
    if (id == 'default' || id == defaultLightThemeId) return AppTheme.light;
    if (id == 'default-dark' || id == defaultDarkThemeId) return AppTheme.dark;
    final theme = _myThemes.firstWhere((t) => t.id == id, orElse: () => _defaultTheme);
    return theme.colors.toThemeData();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          title: const Text('Theme Manager'),
          actions: [
            IconButton(icon: const Icon(Icons.file_download_outlined), onPressed: _importTheme, tooltip: 'import theme from file'),
            IconButton(icon: const Icon(Icons.file_upload_outlined), onPressed: _exportTheme, tooltip: 'export selected theme to file'),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.palette_outlined), text: 'My Themes'),
              Tab(icon: Icon(Icons.public), text: 'Community'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildMyThemesTab(), _buildCommunityTab()]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.color_lens_outlined),
          label: const Text('create new'),
        ),
      ),
    );
  }

  Widget _buildMyThemesTab() {
    if (_loadingMine) return const Center(child: CircularProgressIndicator());

    final all = [_defaultTheme, _defaultThemeDark, ..._myThemes];

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85),
      itemCount: all.length,
      itemBuilder: (context, i) {
        final theme = all[i];
        final isSelected = _selectedThemeId == theme.id;
        final isDefault = theme.id == 'default' || theme.id == 'default-dark';
        final c = theme.colors;

        return GestureDetector(
          onTap: () => applyTheme(theme.id),
          onLongPress: isDefault ? null : () => _deleteTheme(theme),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? c.primary : Colors.transparent, width: 2.5),
            ),
            child: ThemePreview(
              c: c,
              theme: theme,
              isDefault: isDefault,
              openEditor: _openEditor,
              saveTheme: _saveTheme,
              deleteTheme: _deleteTheme,
              isSelected: isSelected,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommunityTab() {
    if (_loadingCommunity) return const Center(child: CircularProgressIndicator());
    if (_communityThemes.isEmpty) {
      return const Center(child: Text('No public themes yet! Create and share yours with the community.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85),
      itemCount: _communityThemes.length,
      itemBuilder: (context, i) {
        final theme = _communityThemes[i];
        final c = theme.colors;
        final isSelected = _selectedThemeId == theme.id;
        final isLiked = _likedIds.contains(theme.id);

        return GestureDetector(
          onTap: () async {
            final newId = const Uuid().v4();
            await _saveTheme(theme.copyWith(name: "${theme.name} - ${theme.createdBy}", id: newId, isPublic: false, likesCount: 0));
            applyTheme(newId);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? c.primary : Colors.transparent, width: 2.5),
            ),
            child: ThemePreview(
              c: c,
              theme: theme,
              isDefault: false,
              openEditor: null,
              saveTheme: null,
              deleteTheme: null,
              isSelected: isSelected,
              onLikeToggle: _toggleLike,
              likesCount: theme.likesCount,
              initiallyLiked: isLiked,
              authorName: theme.createdBy,
            ),
          ),
        );
      },
    );
  }
}

class ThemePreview extends StatefulWidget {
  final CustomThemeColors c;
  final CustomThemeModel theme;
  final bool isDefault;
  final Future<void> Function({CustomThemeModel existing})? openEditor;
  final Future<void> Function(CustomThemeModel)? saveTheme;
  final Future<void> Function(CustomThemeModel)? deleteTheme;
  final bool isSelected;

  final String? authorName;
  final int? likesCount;
  final void Function(String)? onLikeToggle;
  final bool initiallyLiked;

  const ThemePreview({
    super.key,
    required this.c,
    required this.theme,
    required this.isDefault,
    required this.openEditor,
    required this.saveTheme,
    required this.deleteTheme,
    required this.isSelected,
    this.authorName,
    this.likesCount,
    this.onLikeToggle,
    this.initiallyLiked = false,
  });

  @override
  State<ThemePreview> createState() => _ThemePreviewState();
}

class _ThemePreviewState extends State<ThemePreview> {
  late bool isLiked = widget.initiallyLiked;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: widget.c.background,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: widget.c.background)),

          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [widget.c.primary, widget.c.secondary, widget.c.tertiary]
                  .map(
                    (col) => Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(color: widget.c.primary, borderRadius: BorderRadius.circular(6)),
                ),

                const SizedBox(height: 8),

                Container(
                  height: 8,
                  width: 80,
                  decoration: BoxDecoration(color: widget.c.onBackground.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 8,
                  width: 50,
                  decoration: BoxDecoration(color: widget.c.onBackground.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
                ),

                const Spacer(),

                Container(
                  height: 26,
                  decoration: BoxDecoration(color: widget.c.secondary, borderRadius: BorderRadius.circular(8)),
                  child: Center(
                    child: Text(
                      "Button",
                      style: TextStyle(color: widget.c.onSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.theme.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.c.onBackground),
                ),
                if (widget.authorName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          widthFactor: 0.75,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'by ${widget.authorName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 9, color: widget.c.onBackground.withValues(alpha: 0.7)),
                          ),
                        ),
                      ),
                      if (widget.likesCount != null)
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                widget.onLikeToggle?.call(widget.theme.id);
                                setState(() {
                                  isLiked = !isLiked;
                                });
                                print("Liked ${widget.theme.name}: $isLiked");
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  key: ValueKey(isLiked),
                                  color: isLiked ? Colors.redAccent : Colors.grey,
                                  size: 20,
                                ),
                              ),
                            ),
                            Text('${widget.likesCount}', style: TextStyle(fontSize: 9, color: widget.c.onBackground.withValues(alpha: 0.7))),
                            if (!widget.isDefault) const SizedBox(width: 28),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          Positioned(
            top: 13,
            right: 14,
            child: Icon(widget.c.isDark ? Icons.dark_mode : Icons.light_mode, size: 16, color: widget.c.isDark ? Colors.white : Colors.black),
          ),

          if (widget.isSelected) const Positioned(top: 10, left: 10, child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)),

          if (!widget.isDefault)
            Positioned(
              bottom: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, size: 18, color: widget.c.isDark ? Colors.white : Colors.black),
                onSelected: (val) async {
                  switch (val) {
                    case 'edit':
                      await widget.openEditor!(existing: widget.theme);
                    case 'share':
                      await widget.saveTheme!(widget.theme.copyWith(isPublic: true));
                      if (context.mounted) {
                        showSnackBar(context, 'Shared with the Community!');
                      }
                    case 'details':
                      _showThemeDetails(context, widget.theme);
                    case 'delete':
                      await widget.deleteTheme!(widget.theme);
                  }
                },
                itemBuilder: (_) => [
                  if (widget.openEditor != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'), dense: true),
                    ),
                  if (widget.saveTheme != null && !widget.theme.isPublic)
                    const PopupMenuItem(
                      value: 'share',
                      child: ListTile(leading: Icon(Icons.public), title: Text('share with Community'), dense: true),
                    ),
                  const PopupMenuItem(
                    value: 'details',
                    child: ListTile(leading: Icon(Icons.info_outline), title: Text('Details'), dense: true),
                  ),
                  if (widget.deleteTheme != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        dense: true,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

void _showThemeDetails(BuildContext context, CustomThemeModel theme) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final c = theme.colors;
      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(theme.name, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Created by: ${theme.createdBy?.substring(0, 6) ?? "Unknown"}', style: Theme.of(ctx).textTheme.bodySmall),
            Text('Likes: ${theme.likesCount}', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 20),
            Text('Palette', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DetailSwatch('Primary', c.primary),
                _DetailSwatch('Secondary', c.secondary),
                _DetailSwatch('Tertiary', c.tertiary),
                _DetailSwatch('Background', c.background),
                _DetailSwatch('Surface', c.surface),
                _DetailSwatch('Error', c.error),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _DetailSwatch extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailSwatch(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final isLight = color.computeLuminance() > 0.45;
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
          ),
          child: Center(
            child: Text(
              hex.substring(1, 3),
              style: TextStyle(color: isLight ? Colors.black54 : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
        Text(
          hex,
          style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

void showSnackBar(BuildContext context, String message, {Duration duration = const Duration(seconds: 1)}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: duration),
    snackBarAnimationStyle: const AnimationStyle(curve: Curves.ease, duration: Duration(milliseconds: 400)),
  );
}
