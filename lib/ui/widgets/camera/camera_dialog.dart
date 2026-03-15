import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
  
  void switchCamera(){
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
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
      if(mounted){
        setState(() {});
      }
    });
    super.initState();
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
              WebCamera(preferFrontCamera: widget.preferFrontCamera, key: _webCameraState),
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
                    onTap: switchCamera,
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