import 'dart:io';

import '../domain/download_audio_format.dart';

typedef AudioTranscodeProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

abstract interface class DownloadAudioTranscoder {
  Future<void> transcode({
    required String inputPath,
    required String outputPath,
    required DownloadAudioFormat format,
    Map<String, String> metadata = const <String, String>{},
  });
}

class FfmpegDownloadAudioTranscoder implements DownloadAudioTranscoder {
  FfmpegDownloadAudioTranscoder({
    this.executable = 'ffmpeg',
    AudioTranscodeProcessRunner? processRunner,
  }) : _processRunner = processRunner ?? _runProcess;

  final String executable;
  final AudioTranscodeProcessRunner _processRunner;

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments);
  }

  @override
  Future<void> transcode({
    required String inputPath,
    required String outputPath,
    required DownloadAudioFormat format,
    Map<String, String> metadata = const <String, String>{},
  }) async {
    if (format == DownloadAudioFormat.original) {
      return;
    }

    final arguments = _arguments(
      inputPath: inputPath,
      outputPath: outputPath,
      format: format,
      metadata: metadata,
    );

    ProcessResult result;
    try {
      result = await _processRunner(executable, arguments);
    } on ProcessException catch (error) {
      await _deleteIfExists(outputPath);
      throw AudioTranscodeException(
        'FFmpeg is not available. Install ffmpeg or choose Original in Settings.',
        cause: error,
      );
    } on UnsupportedError catch (error) {
      await _deleteIfExists(outputPath);
      throw AudioTranscodeException(
        'Audio conversion is not supported on this platform without bundled ffmpeg.',
        cause: error,
      );
    }

    if (result.exitCode != 0) {
      await _deleteIfExists(outputPath);
      throw AudioTranscodeException(_failureMessage(result));
    }
  }

  List<String> _arguments({
    required String inputPath,
    required String outputPath,
    required DownloadAudioFormat format,
    required Map<String, String> metadata,
  }) {
    final arguments = <String>[
      '-y',
      '-hide_banner',
      '-nostdin',
      '-i',
      inputPath,
      '-vn',
      '-map_metadata',
      '0',
    ];

    switch (format) {
      case DownloadAudioFormat.mp3:
        arguments.addAll(<String>[
          '-acodec',
          'libmp3lame',
          '-b:a',
          '192k',
          '-id3v2_version',
          '3',
        ]);
      case DownloadAudioFormat.wav:
        arguments.addAll(<String>['-acodec', 'pcm_s16le']);
      case DownloadAudioFormat.original:
        break;
    }

    for (final entry in metadata.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        continue;
      }
      arguments.addAll(<String>['-metadata', '${entry.key}=$value']);
    }

    arguments.add(outputPath);
    return arguments;
  }

  static String _failureMessage(ProcessResult result) {
    final output = result.stderr.toString().trim().isEmpty
        ? result.stdout.toString().trim()
        : result.stderr.toString().trim();
    final detail = output.isEmpty ? '' : ' ${_truncate(output)}';
    return 'Audio conversion failed with exit code ${result.exitCode}.$detail';
  }

  static String _truncate(String value) {
    const maxLength = 500;
    return value.length <= maxLength
        ? value
        : '${value.substring(0, maxLength)}...';
  }

  static Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class AudioTranscodeException implements Exception {
  const AudioTranscodeException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
