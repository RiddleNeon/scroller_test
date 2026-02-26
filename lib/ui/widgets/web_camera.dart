import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class WebCameraDialog extends StatefulWidget {
  const WebCameraDialog();

  @override
  State<WebCameraDialog> createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<WebCameraDialog> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _loading = true;
  String? _error;
  bool _takingPhoto = false;
  int _cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() { _loading = true; _error = null; });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() { _error = 'No Camera Found.'; _loading = false; });
        return;
      }
      await _startCamera(_cameraIndex);
    } catch (e) {
      setState(() { _error = 'Camera-Error: $e'; _loading = false; });
    }
  }

  Future<void> _startCamera(int index) async {
    await _controller?.dispose();
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() {
      _controller = controller;
      _cameraIndex = index;
      _loading = false;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    setState(() => _loading = true);
    await _startCamera(next);
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _takingPhoto) return;
    setState(() => _takingPhoto = true);
    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (e) {
      setState(() => _takingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 380,
          height: 520,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_loading)
                const Center(child: CircularProgressIndicator(color: Colors.white))
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  ),
                )
              else if (_controller != null)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.previewSize?.height ?? 380,
                      height: _controller!.value.previewSize?.width ?? 520,
                      child: CameraPreview(_controller!),
                    ),
                  ),

              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(null),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),

              if (_cameras.length > 1)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _switchCamera,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white, size: 20),
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
                        color: Colors.white,
                        border: Border.all(color: Colors.white38, width: 4),
                        boxShadow: [
                          const BoxShadow(color: Colors.black26, blurRadius: 12, spreadRadius: 2),
                        ],
                      ),
                      child: _takingPhoto
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                          : null,
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