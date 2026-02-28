
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class WebCamera extends StatefulWidget {
  final bool preferFrontCamera;
  final void Function()? onCameraConnected;

  const WebCamera({this.preferFrontCamera = false, super.key, this.onCameraConnected});

  @override
  State createState() => WebCameraState();
}

class WebCameraState extends State<WebCamera> {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  bool _loading = true;
  String? _error;
  int _cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCamera().then((_) => widget.onCameraConnected?.call());
  }

  Future<void> _initCamera() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No Camera Found.';
          _loading = false;
        });
        return;
      }
      if (widget.preferFrontCamera) {
        final frontIndex = cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        _cameraIndex = frontIndex >= 0 ? frontIndex : 0;
      }

      await _startCamera(_cameraIndex);
    } catch (e) {
      setState(() {
        _error = 'Camera-Error: $e';
        _loading = false;
      });
    }
  }

  Future _startCamera(int index) async {
    await controller?.dispose();
    final newController = CameraController(
      cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await newController.initialize();
    if (!mounted) return;
    setState(() {
      controller = newController;
      _cameraIndex = index;
      _loading = false;
    });
  }

  Future switchCamera() async {
    print("switching camera");
    if (cameras.length < 2) return;
    final next = (_cameraIndex + 1) % cameras.length;
    setState(() => _loading = true);
    await _startCamera(next);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                ),
              )
            : controller != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller!.value.previewSize?.height ?? 380,
                      height: controller!.value.previewSize?.width ?? 520,
                      child: CameraPreview(controller!),
                    ),
                  )
                : Container();
  }
}
