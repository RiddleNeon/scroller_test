import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:wurp/ui/theme/theme_ui_values.dart';
import 'package:wurp/ui/widgets/camera/web_camera.dart';

class WebCameraDialog extends StatefulWidget {
  final bool preferFrontCamera;
  final bool showControls;

  const WebCameraDialog({super.key, this.preferFrontCamera = false, this.showControls = true});

  @override
  State createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<WebCameraDialog> {
  bool _takingPhoto = false;
  final GlobalObjectKey<WebCameraState> _webCameraState = const GlobalObjectKey('WebCamera');

  CameraController? get _controller => _webCameraState.currentState?.controller;

  List<CameraDescription> get _cameras => _webCameraState.currentState?.cameras ?? [];

  void switchCamera() {
    _webCameraState.currentState?.switchCamera();
  }

  Future _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _takingPhoto) return;
    setState(() => _takingPhoto = true);
    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (e) {
      setState(() => _takingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.inverseSurface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.uiRadiusLg)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.uiRadiusLg),
        child: SizedBox(
          width: 380,
          height: 520,
          child: Stack(
            fit: StackFit.expand,
            children: [
              WebCamera(preferFrontCamera: widget.preferFrontCamera, key: _webCameraState),
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(null),
                  child: Container(
                    width: 36,
                    height: 36,
                      decoration: BoxDecoration(color: cs.inverseSurface.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(context.uiRadiusLg)),
                      child: Icon(Icons.close, color: cs.onInverseSurface, size: 20),
                  ),
                ),
              ),

              if (_cameras.length > 1)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: switchCamera,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: cs.inverseSurface.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(context.uiRadiusLg)),
                      child: Icon(Icons.flip_camera_ios_outlined, color: cs.onInverseSurface, size: 20),
                    ),
                  ),
                ),

              Positioned(
                bottom: 28,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _takePhoto,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: _takingPhoto ? 60 : 70,
                      height: _takingPhoto ? 60 : 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.surfaceBright,
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8), width: 4),
                        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: 2)],
                      ),
                      child: _takingPhoto ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant)) : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
