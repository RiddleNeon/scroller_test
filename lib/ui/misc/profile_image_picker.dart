import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wurp/logic/repositories/user_repository.dart';

import '../../base_logic.dart';
import '../theme/theme_ui_values.dart';
import '../widgets/camera/camera_dialog.dart';

Future<String?> showProfileImagePicker(BuildContext context, {bool persistToCurrentUser = true}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProfileImagePickerSheet(persistToCurrentUser: persistToCurrentUser),
  );
}

class _ProfileImagePickerSheet extends StatefulWidget {
  const _ProfileImagePickerSheet({required this.persistToCurrentUser});

  final bool persistToCurrentUser;

  @override
  State<_ProfileImagePickerSheet> createState() => _ProfileImagePickerSheetState();
}

class _ProfileImagePickerSheetState extends State<_ProfileImagePickerSheet> with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  Uint8List? _pickedBytes;

  final TextEditingController _seedController = TextEditingController();
  String _seedPreviewUrl = '';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _seedController.addListener(() {
      final seed = _seedController.text.trim();
      setState(() => _seedPreviewUrl = seed.isNotEmpty ? createUserProfileImageUrl(seed) : '');
    });
  }

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedTab == 1 && kIsWeb) {
      await _pickImageWebCamera();
      return;
    }

    final result = await FilePicker.pickFiles(type: FileType.image, allowMultiple: false, withData: true);

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
      if (widget.persistToCurrentUser) {
        await userRepository.updateProfileImageUrl(currentUser, url);
      }
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.uiRadiusLg)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(context.uiRadiusSm)),
            ),
            const SizedBox(height: 24),
            Text(
              'Change profile picture',
              style: TextStyle(color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 24),
            _buildTabBar(cs),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutQuart,
                switchOutCurve: Curves.easeInQuart,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: animation.drive(Tween(begin: const Offset(0, 0.05), end: Offset.zero)),
                      child: child,
                    ),
                  );
                },
                child: _buildTabContent(cs),
              ),
            ),
            const SizedBox(height: 16),
            _buildConfirmButton(cs),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    const tabs = [(Icons.photo_library_outlined, 'Gallery'), (Icons.camera_alt_outlined, 'Camera'), (Icons.auto_awesome_outlined, 'Random')];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(context.uiRadiusLg)),
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
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: selected ? cs.primary : Colors.transparent, borderRadius: BorderRadius.circular(context.uiRadiusMd)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tabs[i].$1, size: 18, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      tabs[i].$2,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
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
          child: _pickedBytes != null ? Image.memory(_pickedBytes!, fit: BoxFit.cover, key: ValueKey(_pickedBytes.hashCode)) : null,
          placeholder: Icon(isCamera ? Icons.camera_alt_outlined : Icons.photo_library_outlined, size: 44, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 32),
        _OutlinedActionButton(
          cs: cs,
          icon: isCamera ? Icons.camera_alt_outlined : Icons.photo_library_outlined,
          label: isCamera ? 'Take a photo' : 'Select from gallery',
          onTap: _pickImage,
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _pickedBytes != null ? 1 : 0,
          child: _pickedBytes != null
              ? TextButton(
                  onPressed: () => setState(() => _pickedBytes = null),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  child: const Text('Remove image', style: TextStyle(fontWeight: FontWeight.w600)),
                )
              : const SizedBox(height: 48),
        ),
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
          placeholder: Icon(Icons.auto_awesome_outlined, size: 44, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _seedController,
          autofocus: false,
          decoration: InputDecoration(
            hintText: 'Type something to generate...',
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            prefixIcon: Icon(Icons.tag, color: cs.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.uiRadiusMd), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.uiRadiusMd),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Unique seeds create unique avatars.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPreviewCircle({required ColorScheme cs, required Widget? child, required Widget placeholder}) {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerHighest,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 4),
        ),
        child: ClipOval(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
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
      child: AnimatedScale(
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        scale: canConfirm ? 1.0 : 0.9,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: canConfirm ? 1.0 : 0.5,
          child: GestureDetector(
            onTap: canConfirm && !_uploading ? _confirm : null,
            child: Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(context.uiRadiusLg)),
              child: Center(
                child: _uploading
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 3))
                    : Text(
                        'Save Profile Picture',
                        style: TextStyle(color: cs.onPrimary, fontSize: 16, fontWeight: FontWeight.w800),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.uiRadiusMd),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant, width: 2),
            borderRadius: BorderRadius.circular(context.uiRadiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: cs.onSurface),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
