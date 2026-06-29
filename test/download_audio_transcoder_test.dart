import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:robyne/features/downloads/domain/download_audio_format.dart';
import 'package:robyne/features/downloads/infrastructure/download_audio_transcoder.dart';

void main() {
  test('builds ffmpeg command for mp3 conversion', () async {
    late String executable;
    late List<String> arguments;
    final transcoder = FfmpegDownloadAudioTranscoder(
      processRunner: (command, args) async {
        executable = command;
        arguments = args;
        return ProcessResult(1, 0, '', '');
      },
    );

    await transcoder.transcode(
      inputPath: 'input.m4s',
      outputPath: 'output.mp3',
      format: DownloadAudioFormat.mp3,
      metadata: const <String, String>{'title': 'Song'},
    );

    expect(executable, 'ffmpeg');
    expect(
      arguments,
      containsAllInOrder(<String>[
        '-y',
        '-hide_banner',
        '-nostdin',
        '-i',
        'input.m4s',
        '-vn',
        '-acodec',
        'libmp3lame',
        '-b:a',
        '192k',
        '-metadata',
        'title=Song',
        'output.mp3',
      ]),
    );
  });

  test('deletes partial output when conversion fails', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_transcoder_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final output = File(p.join(tempDirectory.path, 'output.wav'));
    await output.writeAsBytes(<int>[1, 2, 3]);
    final transcoder = FfmpegDownloadAudioTranscoder(
      processRunner: (command, args) async {
        return ProcessResult(1, 2, '', 'nope');
      },
    );

    await expectLater(
      transcoder.transcode(
        inputPath: 'input.m4s',
        outputPath: output.path,
        format: DownloadAudioFormat.wav,
      ),
      throwsA(isA<AudioTranscodeException>()),
    );
    expect(await output.exists(), isFalse);
  });
}
