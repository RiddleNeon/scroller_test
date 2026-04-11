import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/ui/animations/slide_morph_transitions.dart';

import '../../base_logic.dart';
import '../widgets/camera/camera_dialog.dart';

Future<String?> showProfileImagePicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ProfileImagePickerSheet(),
  );
}

class _ProfileImagePickerSheet extends StatefulWidget {
  const _ProfileImagePickerSheet();

  @override
  State<_ProfileImagePickerSheet> createState() => _ProfileImagePickerSheetState();
}

class _ProfileImagePickerSheetState extends State<_ProfileImagePickerSheet> with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  Uint8List? _pickedBytes;

  final TextEditingController _seedController = TextEditingController();
  String _seedPreviewUrl = '';
  bool _uploading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _seedController.addListener(() {
      final seed = _seedController.text.trim();
      setState(() => _seedPreviewUrl = seed.isNotEmpty ? createUserProfileImageUrl(seed) : '');
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _seedController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedTab == 1 && kIsWeb) {
      await _pickImageWebCamera();
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);

    if (result != null && result.files.first.bytes != null) {
      setState(() {
        _pickedBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _pickImageWebCamera() async {
    final bytes = await showDialog<Uint8List>(context: context, barrierDismissible: false, builder: (_) => const WebCameraDialog(preferFrontCamera: true));
    if (bytes != null && mounted) {
      setState(() {
        _pickedBytes = bytes;
      });
    }
  }

  static const _cloudinaryCloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');

  Future<String> _uploadToCloudinary(Uint8List bytes) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = 'tmp_profile_imgs'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'profile.jpg'));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw Exception('Upload failed: $body');
    }
    return (jsonDecode(body) as Map<String, dynamic>)['secure_url'] as String;
  }

  Future<void> _confirm() async {
    setState(() => _uploading = true);
    try {
      String url;
      if (_selectedTab == 2) {
        final seed = _seedController.text.trim();
        if (seed.isEmpty) {
          _showSnack('Please enter a seed!');
          return;
        }
        url = createUserProfileImageUrl(seed);
      } else {
        if (_pickedBytes == null) {
          _showSnack('Please choose an image first!');
          return;
        }
        url = await _uploadToCloudinary(_pickedBytes!);
      }
      await userRepository.updateProfileImageUrl(currentUser, url);
      if (mounted) Navigator.of(context).pop(url);
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SlideMorphTransitions.build(
      _fadeAnim,
      DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(
                'Change profile picture',
                style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              ),
              const SizedBox(height: 20),
              _buildTabBar(cs),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) =>
                        SlideMorphTransitions.switcher(child, animation, beginOffset: const Offset(0, 0.1), beginScale: 0.95),
                    child: _buildTabContent(cs),
                  ),
                ),
              ),
              _buildConfirmButton(cs),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      beginOffset: const Offset(0, 0.08),
      beginScale: 0.98,
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    const tabs = [(Icons.photo_library_outlined, 'Gallery'), (Icons.camera_alt_outlined, 'Camera'), (Icons.auto_awesome_outlined, 'Random')];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 52,
      decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedTab = i;
                _pickedBytes = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: selected ? cs.primary : Colors.transparent, borderRadius: BorderRadius.circular(13)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tabs[i].$1, size: 16, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(
                      tabs[i].$2,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(ColorScheme cs) {
    switch (_selectedTab) {
      case 0:
        return _buildMediaTab(cs, isCamera: false, key: const ValueKey('gallery'));
      case 1:
        return _buildMediaTab(cs, isCamera: true, key: const ValueKey('camera'));
      case 2:
        return _buildSeedTab(cs, key: const ValueKey('random'));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMediaTab(ColorScheme cs, {required bool isCamera, Key? key}) {
    return Column(
      key: key,
      children: [
        _buildPreviewCircle(
          cs: cs,
          child: _pickedBytes != null ? Image.memory(_pickedBytes!, fit: BoxFit.cover) : null,
          placeholder: Icon(isCamera ? Icons.camera_alt_outlined : Icons.photo_library_outlined, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 28),
        _OutlinedActionButton(
          cs: cs,
          icon: isCamera ? Icons.camera_alt_outlined : Icons.photo_library_outlined,
          label: isCamera ? 'Take a photo' : 'Select file',
          onTap: _pickImage,
        ),
        if (_pickedBytes != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _pickedBytes = null),
            child: Text(
              'Remove',
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSeedTab(ColorScheme cs, {Key? key}) {
    return Column(
      key: key,
      children: [
        _buildPreviewCircle(
          cs: cs,
          child: _seedPreviewUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: _seedPreviewUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
                  errorWidget: (_, _, _) => Icon(Icons.error_outline, color: cs.onSurfaceVariant),
                )
              : null,
          placeholder: Icon(Icons.auto_awesome_outlined, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _seedController,
          style: TextStyle(color: cs.onSurface),
          cursorColor: cs.primary,
          decoration: InputDecoration(
            hintText: 'Enter a seed — try your name!',
            hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            filled: true,
            fillColor: cs.surfaceContainer,
            prefixIcon: Icon(Icons.tag, color: cs.onSurfaceVariant),
            suffixIcon: _seedController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                    onPressed: () => _seedController.clear(),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Same seed → same result every time',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ... (Rest der Hilfs-Widgets _buildPreviewCircle, _buildConfirmButton, _OutlinedActionButton bleibt gleich)

  Widget _buildPreviewCircle({required ColorScheme cs, required Widget? child, required Widget placeholder}) {
    return Center(
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerHighest,
          border: Border.all(color: cs.outlineVariant, width: 2),
          boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 6))],
        ),
        child: ClipOval(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => SlideMorphTransitions.switcher(child, animation, beginOffset: const Offset(0, 0.1), beginScale: 0.95),
            child: child != null ? SizedBox.expand(key: const ValueKey('img'), child: child) : Center(key: const ValueKey('ph'), child: placeholder),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(ColorScheme cs) {
    final canConfirm = (_selectedTab < 2 && _pickedBytes != null) || (_selectedTab == 2 && _seedController.text.trim().isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        offset: canConfirm ? Offset.zero : const Offset(0, 0.04),
        child: GestureDetector(
          onTap: canConfirm && !_uploading ? _confirm : null,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            scale: canConfirm ? 1.0 : 0.96,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: canConfirm ? 1 : 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: _uploading
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 2.5))
                    : Text(
                        'Save',
                        style: TextStyle(color: cs.onPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({required this.cs, required this.icon, required this.label, required this.onTap});

  final ColorScheme cs;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: cs.onSurface),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
