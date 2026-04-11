// lib/services/transcription_service.dart
//
// Ruft die in web/index.html definierten JS-Funktionen auf.
// Funktioniert NUR auf Flutter Web.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('transcribeAudio')
external JSPromise _transcribeAudio(JSAny audioBlob, JSString language, JSString prompt, JSFunction? onProgress);

@JS('extractAudioFromVideo')
external JSPromise _extractAudioFromVideo(JSAny videoBlob);

@JS('Blob')
@staticInterop
class _JSBlob {
  external factory _JSBlob(JSArray parts, JSObject options);
}

@JS()
@anonymous
@staticInterop
class _BlobOptions {
  external factory _BlobOptions({required JSString type});
}

class TranscriptChunk {
  final double start;
  final double end;
  final String text;

  const TranscriptChunk({required this.start, required this.end, required this.text});

  factory TranscriptChunk.fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'] as List<dynamic>? ?? [0.0, 0.0];
    return TranscriptChunk(
      start: (timestamp[0] as num?)?.toDouble() ?? 0.0,
      end: (timestamp[1] as num?)?.toDouble() ?? 0.0,
      text: (json['text'] as String? ?? '').trim(),
    );
  }
}

class TranscriptionResult {
  final String fullText;
  final List<TranscriptChunk> chunks;

  const TranscriptionResult({required this.fullText, required this.chunks});
}

class TranscriptionService {
  static Future<TranscriptionResult> transcribeVideo({
    required Uint8List videoBytes,
    String language = 'german',
    String prompt = '',
    void Function(int percent)? onProgress,
  }) async {
    if (!kIsWeb) {
      throw UnsupportedError('Transcription service is currently only supported on Flutter Web.');
    }

    debugPrint('[Whisper] Extracting audio...');
    final jsUint8Array = videoBytes.toJS;
    final jsBlob = _JSBlob([jsUint8Array].toJS, _BlobOptions(type: 'video/mp4'.toJS) as JSObject);

    final audioBlob = await _extractAudioFromVideo(jsBlob as JSAny).toDart;

    if (audioBlob == null) {
      throw Exception(
        'Audio-Extraction failed. '
        'make sure the file is a valid MP4/WebM-file?',
      );
    }

    debugPrint('[Whisper] starting transcription...');

    JSFunction? progressFn;
    if (onProgress != null) {
      progressFn = ((JSNumber percent) {
        onProgress(percent.toDartInt);
      }).toJS;
    }

    final resultJson = await _transcribeAudio(audioBlob, language.toJS, prompt.toJS, progressFn).toDart;

    final resultStr = (resultJson as JSString).toDart;
    final resultMap = jsonDecode(resultStr) as Map<String, dynamic>;

    if (resultMap['success'] != true) {
      throw Exception('Whisper-Error: ${resultMap['error']}');
    }

    final data = resultMap['data'] as Map<String, dynamic>;
    final chunks = (data['chunks'] as List<dynamic>? ?? []).map((c) => TranscriptChunk.fromJson(c as Map<String, dynamic>)).toList();

    return TranscriptionResult(fullText: data['text'] as String? ?? '', chunks: chunks);
  }
}
