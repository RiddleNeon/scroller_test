import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wurp/logic/themes/theme_model.dart';
import 'package:wurp/ui/theme/theme_editor_screen.dart';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';


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
    colors: CustomThemeColors.fromPrimary(const Color(0xFF6C5443)),
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
          _myThemes = (res as List).map((e) => CustomThemeModel.fromJson(e)).toList();
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
      final res = await _supabase
          .from('themes')
          .select()
          .eq('is_public', true)
          .order('likes_count', ascending: false);
      if (mounted) {
        setState(() {
          _communityThemes = (res as List).map((e) => CustomThemeModel.fromJson(e)).toList();
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
      await _supabase.from('themes').upsert(theme.toJson());
      await _loadMyThemes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Theme Saved!'), duration: Duration(seconds: 2)), snackBarAnimationStyle: const AnimationStyle(curve: Curves.ease, duration: Duration(milliseconds: 400)));
    } catch (e) {
      debugPrint('Error saving theme: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error when saving: $e')));
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

    // Optimistic update
    setState(() {
      if (isLiked) {
        _likedIds.remove(themeId);
        final idx = _communityThemes.indexWhere((t) => t.id == themeId);
        if (idx != -1) {
          _communityThemes[idx] = _communityThemes[idx].copyWith(
              likesCount: (_communityThemes[idx].likesCount - 1).clamp(0, 999999));
        }
      } else {
        _likedIds.add(themeId);
        final idx = _communityThemes.indexWhere((t) => t.id == themeId);
        if (idx != -1) {
          _communityThemes[idx] =
              _communityThemes[idx].copyWith(likesCount: _communityThemes[idx].likesCount + 1);
        }
      }
    });

    try {
      if (isLiked) {
        await _supabase
            .from('theme_likes')
            .delete()
            .eq('theme_id', themeId)
            .eq('user_id', _uid!);
      } else {
        await _supabase.from('theme_likes').insert({'theme_id': themeId, 'user_id': _uid!});
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      await _loadCommunityThemes();
      await _loadLikedIds();
    }
  }
  
  void _applyTheme(String id) {
    setState(() => _selectedThemeId = id);
    // TODO: propagate to your app root via Provider/Riverpod/Bloc so the whole
    // app rebuilds with the new ThemeData. Example:
    //   context.read<ThemeNotifier>().apply(theme.colors.toThemeData());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Theme angewendet! (Root-Theme-Propagation noch verbinden)')),
    );
  }
  
  Future<void> _openEditor({CustomThemeModel? existing}) async {
    final result = await Navigator.push<CustomThemeModel>(
      context,
      MaterialPageRoute(builder: (_) => ThemeEditorScreen(existingTheme: existing)),
    );
    if (result != null) await _saveTheme(result);
  }
  
  Future<void> _exportTheme() async {
    if (_selectedThemeId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Choose a theme first.')));
      return;
    }
    final theme = [_defaultTheme, ..._myThemes]
        .firstWhere((t) => t.id == _selectedThemeId!, orElse: () => _defaultTheme);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(theme.toJson());
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${theme.name.replaceAll(' ', '_')}.json');
    await file.writeAsString(jsonStr);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Export: ${file.path}')));
  }

  Future<void> _importTheme() async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null) return;

      final file = File(result.files.single.path!);
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final imported = CustomThemeModel.fromJson(json).copyWith(
        id: UniqueKey().toString(),
        isPublic: false,
      );
      await _saveTheme(imported);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${imported.name}" imported!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
  
  void _showThemeDetails(CustomThemeModel theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(theme.name, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Created by: ${theme.createdBy?.substring(0, 6) ?? "Unknown"}',
                  style: Theme.of(ctx).textTheme.bodySmall),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Theme Manager'),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              onPressed: _importTheme,
              tooltip: 'import theme from file',
            ),
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: _exportTheme,
              tooltip: 'export selected theme to file',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.palette_outlined), text: 'Meine Themes'),
              Tab(icon: Icon(Icons.public), text: 'Community'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyThemesTab(),
            _buildCommunityTab(),
          ],
        ),
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

    final all = [_defaultTheme, ..._myThemes];

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemCount: all.length,
      itemBuilder: (context, i) {
        final theme = all[i];
        final isSelected = _selectedThemeId == theme.id;
        final isDefault = theme.id == 'default';
        final c = theme.colors;

        return GestureDetector(
          onTap: () => _applyTheme(theme.id),
          onLongPress: isDefault ? null : () => _deleteTheme(theme),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? c.primary : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(color: c.primary.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 1),
              ],
            ),
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            c.primary.withValues(alpha: 0.15),
                            c.secondary.withValues(alpha: 0.10),
                            c.tertiary.withValues(alpha: 0.12),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 12, right: 12,
                    child: Row( 
                      children: [c.primary, c.secondary, c.tertiary]
                          .map((col) => Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      )).toList(),
                    ),
                  ),

                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          backgroundColor: c.primary,
                          radius: 26,
                          child: Icon(Icons.palette, color: c.onPrimary, size: 22),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            theme.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDefault)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Standard',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (isSelected)
                    const Positioned(
                      top: 10, left: 10,
                      child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    ),

                  if (!isDefault)
                    Positioned(
                      bottom: 0, right: 0,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, size: 18),
                        onSelected: (val) async {
                          switch (val) {
                            case 'edit':
                              await _openEditor(existing: theme);
                            case 'share':
                              await _saveTheme(theme.copyWith(isPublic: true));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Shared with the Community!')),
                                );
                              }
                            case 'details':
                              _showThemeDetails(theme);
                            case 'delete':
                              await _deleteTheme(theme);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'), dense: true)),
                          const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.public), title: Text('share with Community'), dense: true)),
                          const PopupMenuItem(value: 'details', child: ListTile(leading: Icon(Icons.info_outline), title: Text('Details'), dense: true)),
                          const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)), dense: true)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Community list ────────────────────────────────────────────────────────

  Widget _buildCommunityTab() {
    if (_loadingCommunity) return const Center(child: CircularProgressIndicator());
    if (_communityThemes.isEmpty) {
      return const Center(child: Text('No public themes yet! Create and share yours with the community.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _communityThemes.length,
      itemBuilder: (context, i) {
        final theme = _communityThemes[i];
        final c = theme.colors;
        final isLiked = _likedIds.contains(theme.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: c.primary,
              child: Icon(Icons.palette, color: c.onPrimary, size: 20),
            ),
            title: Text(theme.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Row(
              children: [
                Text('by: ${theme.createdBy?.substring(0, 6) ?? "Unknown"}'),
                const SizedBox(width: 8),
                ...([c.primary, c.secondary, c.tertiary].map(
                      (col) => Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                  ),
                )),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(theme.id),
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
                const SizedBox(width: 2),
                Text('${theme.likesCount}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.download_rounded, size: 20),
                  tooltip: 'To my themes',
                  onPressed: () {
                    final cloned = theme.copyWith(
                      id: UniqueKey().toString(),
                      isPublic: false,
                    );
                    _saveTheme(cloned);
                  },
                ),
              ],
            ),
            onTap: () => _showThemeDetails(theme),
          ),
        );
      },
    );
  }
}

class _DetailSwatch extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailSwatch(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
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
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)],
          ),
          child: Center(
            child: Text(
              hex.substring(1, 3), // first two hex digits as preview
              style: TextStyle(
                color: isLight ? Colors.black54 : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
        Text(hex, style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace')),
      ],
    );
  }
}