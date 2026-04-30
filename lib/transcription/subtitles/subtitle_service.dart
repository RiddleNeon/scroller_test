import 'package:lumox/transcription/generation_service/transcription_service.dart';

class SubtitleService {
  static String chunksToSrt(List<TranscriptChunk> chunks) {
    final buffer = StringBuffer();

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      if (chunk.text.isEmpty) continue;

      buffer.writeln(i + 1);
      buffer.writeln('${_formatSrtTime(chunk.start)} --> ${_formatSrtTime(chunk.end)}');
      buffer.writeln(chunk.text);
      buffer.writeln();
    }

    return buffer.toString();
  }

  static String _formatSrtTime(double seconds) {
    final ms = (seconds * 1000).round();
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;

    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')},'
        '${millis.toString().padLeft(3, '0')}';
  }

  static String chunksToVtt(List<TranscriptChunk> chunks) {
    final buffer = StringBuffer('WEBVTT\n\n');

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      if (chunk.text.isEmpty) continue;

      buffer.writeln('${_formatVttTime(chunk.start)} --> ${_formatVttTime(chunk.end)}');
      buffer.writeln(chunk.text);
      buffer.writeln();
    }

    return buffer.toString();
  }

  static String _formatVttTime(double seconds) {
    return _formatSrtTime(seconds).replaceAll(',', '.');
  }
}
