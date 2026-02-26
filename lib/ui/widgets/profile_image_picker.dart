import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:wurp/main.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/ui/widgets/web_camera.dart';

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

class _ProfileImagePickerSheetState extends State<_ProfileImagePickerSheet>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;

  XFile? _pickedFile;
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
      if (seed.isNotEmpty) {
        setState(() => _seedPreviewUrl = createUserProfileImageUrl(seed));
      } else {
        setState(() => _seedPreviewUrl = '');
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _seedController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) {
      await _pickImageWebCamera();
    } else {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedFile = file;
        _pickedBytes = bytes;
      });
    }
  }

  Future<void> _pickImageWebCamera() async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const WebCameraDialog(),
    );
    if (bytes != null && mounted) {
      setState(() {
        _pickedFile = null;
        _pickedBytes = bytes;
      });
    }
  }
  
  static const _cloudinaryCloudName = 'dvw3vksqx';
  Future<String> _uploadToCloudinary(Uint8List bytes) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = "tmp_profile_imgs"
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'profile.jpg'));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Error during file upload: $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAFA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Change profile picture',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              ),
              const SizedBox(height: 20),

              _buildTabBar(),

              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildTabContent(),
                  ),
                ),
              ),

              _buildConfirmButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    const tabs = [
      (Icons.photo_library_outlined, 'Gallery'),
      (Icons.camera_alt_outlined, 'Camera'),
      (Icons.auto_awesome_outlined, 'Random'),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedTab = i;
                _pickedFile = null;
                _pickedBytes = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: selected ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tabs[i].$1, size: 16, color: selected ? Colors.white : Colors.black54),
                    const SizedBox(width: 5),
                    Text(
                      tabs[i].$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.black54,
                      ),
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

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildMediaTab(ImageSource.gallery, key: const ValueKey('gallery'));
      case 1:
        return _buildMediaTab(ImageSource.camera, key: const ValueKey('camera'));
      case 2:
        return _buildSeedTab(key: const ValueKey('random'));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMediaTab(ImageSource source, {Key? key}) {
    return Column(
      key: key,
      children: [
        _buildPreviewCircle(
          child: _pickedBytes != null
              ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
              : null,
          placeholder: Icon(
            source == ImageSource.gallery ? Icons.photo_library_outlined : Icons.camera_alt_outlined,
            size: 40,
            color: Colors.black26,
          ),
        ),

        const SizedBox(height: 28),

        _OutlinedActionButton(
          icon: source == ImageSource.gallery ? Icons.photo_library_outlined : Icons.camera_alt_outlined,
          label: source == ImageSource.gallery ? 'Select from gallery' : 'Take a photo',
          onTap: () => _pickImage(source),
        ),

        if (_pickedBytes != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _pickedFile = null;
              _pickedBytes = null;
            }),
            child: const Text('remove', style: TextStyle(color: Colors.black38)),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSeedTab({Key? key}) {
    return Column(
      key: key,
      children: [
        _buildPreviewCircle(
          child: _seedPreviewUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: _seedPreviewUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorWidget: (_, __, ___) => const Icon(Icons.error_outline),
          )
              : null,
          placeholder: const Icon(Icons.auto_awesome_outlined, size: 40, color: Colors.black26),
        ),

        const SizedBox(height: 28),

        TextField(
          controller: _seedController,
          decoration: InputDecoration(
            hintText: 'Enter your seed! Try your name for example!',
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFEEEEEE),
            prefixIcon: const Icon(Icons.tag, color: Colors.black38),
            suffixIcon: _seedController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.black38),
              onPressed: () => _seedController.clear(),
            )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 10),
        const Text(
          'Same seed - same result!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black38, height: 1.5),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPreviewCircle({required Widget? child, required Widget placeholder}) {
    return Center(
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE8E8E8),
          border: Border.all(color: Colors.black12, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: child != null
                ? SizedBox.expand(key: const ValueKey('img'), child: child)
                : Center(key: const ValueKey('ph'), child: placeholder),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    final bool canConfirm = (_selectedTab < 2 && _pickedBytes != null) ||
        (_selectedTab == 2 && _seedController.text.trim().isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: canConfirm ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: canConfirm && !_uploading ? _confirm : null,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: _uploading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
                  : const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
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
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlinedActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}