enum ShortcutAction {
  playPause,
  nextTrack,
  previousTrack,
  volumeUp,
  volumeDown,
  desktopLyrics,
  toggleFavorite,
  currentLyricLine,
  previousLyricLine,
  nextLyricLine,
}

extension ShortcutActionX on ShortcutAction {
  String get storageKey {
    return switch (this) {
      ShortcutAction.playPause => 'play_pause',
      ShortcutAction.nextTrack => 'next_track',
      ShortcutAction.previousTrack => 'previous_track',
      ShortcutAction.volumeUp => 'volume_up',
      ShortcutAction.volumeDown => 'volume_down',
      ShortcutAction.desktopLyrics => 'desktop_lyrics',
      ShortcutAction.toggleFavorite => 'toggle_favorite',
      ShortcutAction.currentLyricLine => 'current_lyric_line',
      ShortcutAction.previousLyricLine => 'previous_lyric_line',
      ShortcutAction.nextLyricLine => 'next_lyric_line',
    };
  }

  String get label {
    return switch (this) {
      ShortcutAction.playPause => '播放 / 暂停',
      ShortcutAction.nextTrack => '下一首',
      ShortcutAction.previousTrack => '上一首',
      ShortcutAction.volumeUp => '音量 +',
      ShortcutAction.volumeDown => '音量 -',
      ShortcutAction.desktopLyrics => '桌面歌词',
      ShortcutAction.toggleFavorite => '喜欢 / 取消喜欢',
      ShortcutAction.currentLyricLine => '本句开头',
      ShortcutAction.previousLyricLine => '上一句',
      ShortcutAction.nextLyricLine => '下一句',
    };
  }

  String get description {
    return switch (this) {
      ShortcutAction.playPause => '切换当前播放状态',
      ShortcutAction.nextTrack => '跳到下一首歌曲',
      ShortcutAction.previousTrack => '回到上一首歌曲',
      ShortcutAction.volumeUp => '提高播放器音量',
      ShortcutAction.volumeDown => '降低播放器音量',
      ShortcutAction.desktopLyrics => '显示或隐藏桌面歌词窗口',
      ShortcutAction.toggleFavorite => '切换当前歌曲的喜欢状态',
      ShortcutAction.currentLyricLine => '回到当前歌词句子的开始时间',
      ShortcutAction.previousLyricLine => '跳到上一句歌词的开始时间',
      ShortcutAction.nextLyricLine => '跳到下一句歌词的开始时间',
    };
  }
}
