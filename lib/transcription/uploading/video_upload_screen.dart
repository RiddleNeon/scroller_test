import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lumox/transcription/generation_service/transcription_service.dart';

import '../../ui/theme/theme_ui_values.dart';

enum _UploadStep { idle, transcribing, done, error }

class VideoUploadWidget extends StatefulWidget {
  const VideoUploadWidget({super.key});

  @override
  State<VideoUploadWidget> createState() => _VideoUploadWidgetState();
}

class _VideoUploadWidgetState extends State<VideoUploadWidget> {
  _UploadStep _step = _UploadStep.idle;
  String _statusText = '';
  int _progress = 0;
  TranscriptionResult? _result;
  String? _errorMessage;
  PlatformFile? _selectedFile;

  Future<void> _pickAndProcess() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['mp4', 'mov', 'webm'], withData: true);
    if (picked == null || picked.files.isEmpty) return;

    setState(() {
      _selectedFile = picked.files.first;
      _step = _UploadStep.transcribing;
      _statusText = 'Loading whisper. this may take a while. please dont close the app.';
      _progress = 0;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await TranscriptionService.transcribeVideo(
        videoBytes: _selectedFile!.bytes!,
        language: 'german',
        onProgress: (percent) {
          setState(() {
            _progress = percent;
            _statusText = percent < 100 ? 'Loading model... $percent%' : 'Transcribing audio...';
          });
        },
      );

      print("RESULT: ${result.fullText.substring(0, 100)}... with ${result.chunks.length} chunks");

      setState(() {
        _step = _UploadStep.done;
        _statusText = 'Fertig!';
      });
    } catch (e) {
      setState(() {
        _step = _UploadStep.error;
        _errorMessage = e.toString();
        _statusText = 'An error occurred';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = _step == _UploadStep.idle || _step == _UploadStep.done || _step == _UploadStep.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Video')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedFile != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.video_file),
                  title: Text(_selectedFile!.name),
                  subtitle: Text('${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(1)} MB'),
                ),
              ),

            const SizedBox(height: 16),

            if (_step != _UploadStep.idle) _StatusCard(step: _step, statusText: _statusText, progress: _progress, errorMessage: _errorMessage),

            if (_result != null) ...[
              const SizedBox(height: 16),
              const Text('Generated text:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(context.uiRadiusSm)),
                child: Text(_result!.fullText, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 4),
              Text('${_result!.chunks.length} Subtitle Chunks', style: Theme.of(context).textTheme.bodySmall),
            ],

            const Spacer(),

            FilledButton.icon(
              onPressed: canUpload ? _pickAndProcess : null,
              icon: const Icon(Icons.upload),
              label: Text(_step == _UploadStep.done ? 'Load another video' : 'Choose video and upload'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final _UploadStep step;
  final String statusText;
  final int progress;
  final String? errorMessage;

  const _StatusCard({required this.step, required this.statusText, required this.progress, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final isError = step == _UploadStep.error;
    final isDone = step == _UploadStep.done;

    return Card(
      color: isError
          ? Colors.red.shade50
          : isDone
          ? Colors.green.shade800
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!isError && !isDone)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else if (isDone)
                  const Icon(Icons.check_circle, color: Colors.green, size: 16)
                else
                  const Icon(Icons.error, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(color: isError ? Colors.red.shade700 : null, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            if (!isError && !isDone && progress > 0) ...[const SizedBox(height: 8), LinearProgressIndicator(value: progress / 100)],
            if (isError && errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(errorMessage!, style: TextStyle(fontSize: 12, color: Colors.red.shade600)),
            ],
          ],
        ),
      ),
    );
  }
}
