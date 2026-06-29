enum DownloadAudioFormat { original, mp3, wav }

extension DownloadAudioFormatExtension on DownloadAudioFormat {
  String get label {
    return switch (this) {
      DownloadAudioFormat.original => 'Original',
      DownloadAudioFormat.mp3 => 'MP3',
      DownloadAudioFormat.wav => 'WAV',
    };
  }

  String? get extension {
    return switch (this) {
      DownloadAudioFormat.original => null,
      DownloadAudioFormat.mp3 => '.mp3',
      DownloadAudioFormat.wav => '.wav',
    };
  }
}
