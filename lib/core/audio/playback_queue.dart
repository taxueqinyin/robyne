import 'dart:math';

import 'package:collection/collection.dart';
import 'package:robyne/shared/models/song_model.dart';

enum PlaybackMode {
  sequential,
  shuffle,
  singleLoop,
  listLoop,
}

class PlaybackQueue {
  List<SongModel> _queue = [];
  List<SongModel> _originalQueue = [];
  int _currentIndex = -1;
  PlaybackMode _mode = PlaybackMode.sequential;
  final _random = Random();

  List<SongModel> get queue => UnmodifiableListView(_queue);
  int get currentIndex => _currentIndex;
  PlaybackMode get mode => _mode;
  SongModel? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;

  void setQueue(List<SongModel> songs, {int startIndex = 0}) {
    _originalQueue = List.from(songs);
    _queue = List.from(songs);
    _currentIndex = startIndex.clamp(0, songs.length - 1);

    if (_mode == PlaybackMode.shuffle) {
      _shuffleQueue(keepCurrent: true);
    }
  }

  void addToQueue(SongModel song) {
    _queue.add(song);
    _originalQueue.add(song);
  }

  void insertNext(SongModel song) {
    final insertIndex = _currentIndex + 1;
    _queue.insert(insertIndex, song);

    final originalIndex = _originalQueue.indexOf(currentSong!);
    if (originalIndex >= 0) {
      _originalQueue.insert(originalIndex + 1, song);
    }
  }

  void removeAt(int index) {
    if (index < 0 || index >= _queue.length) return;

    final song = _queue[index];
    _queue.removeAt(index);
    _originalQueue.remove(song);

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
    }
  }

  void clear() {
    _queue.clear();
    _originalQueue.clear();
    _currentIndex = -1;
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex >= _queue.length) return;

    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);

    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
  }

  SongModel? next() {
    if (_queue.isEmpty) return null;

    switch (_mode) {
      case PlaybackMode.singleLoop:
        return currentSong;

      case PlaybackMode.sequential:
      case PlaybackMode.listLoop:
        if (_currentIndex < _queue.length - 1) {
          _currentIndex++;
        } else if (_mode == PlaybackMode.listLoop) {
          _currentIndex = 0;
        } else {
          return null;
        }
        return currentSong;

      case PlaybackMode.shuffle:
        if (_queue.length <= 1) return currentSong;
        int nextIndex;
        do {
          nextIndex = _random.nextInt(_queue.length);
        } while (nextIndex == _currentIndex);
        _currentIndex = nextIndex;
        return currentSong;
    }
  }

  SongModel? previous() {
    if (_queue.isEmpty) return null;

    switch (_mode) {
      case PlaybackMode.singleLoop:
        return currentSong;

      case PlaybackMode.sequential:
      case PlaybackMode.listLoop:
        if (_currentIndex > 0) {
          _currentIndex--;
        } else if (_mode == PlaybackMode.listLoop) {
          _currentIndex = _queue.length - 1;
        } else {
          return null;
        }
        return currentSong;

      case PlaybackMode.shuffle:
        if (_queue.length <= 1) return currentSong;
        int prevIndex;
        do {
          prevIndex = _random.nextInt(_queue.length);
        } while (prevIndex == _currentIndex);
        _currentIndex = prevIndex;
        return currentSong;
    }
  }

  void setMode(PlaybackMode mode) {
    if (_mode == mode) return;

    if (mode == PlaybackMode.shuffle) {
      _shuffleQueue(keepCurrent: true);
    } else if (_mode == PlaybackMode.shuffle) {
      _restoreOriginalOrder();
    }

    _mode = mode;
  }

  void _shuffleQueue({bool keepCurrent = true}) {
    final current = keepCurrent ? currentSong : null;
    _queue.shuffle(_random);

    if (keepCurrent && current != null) {
      final index = _queue.indexOf(current);
      if (index > 0) {
        _queue.removeAt(index);
        _queue.insert(0, current);
        _currentIndex = 0;
      }
    }
  }

  void _restoreOriginalOrder() {
    final current = currentSong;
    _queue = List.from(_originalQueue);

    if (current != null) {
      _currentIndex = _queue.indexOf(current);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'queue': _queue.map((s) => s.toJson()).toList(),
      'originalQueue': _originalQueue.map((s) => s.toJson()).toList(),
      'currentIndex': _currentIndex,
      'mode': _mode.name,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    _queue = (json['queue'] as List)
        .map((s) => SongModel.fromJson(s as Map<String, dynamic>))
        .toList();
    _originalQueue = (json['originalQueue'] as List)
        .map((s) => SongModel.fromJson(s as Map<String, dynamic>))
        .toList();
    _currentIndex = json['currentIndex'] as int;
    _mode = PlaybackMode.values.firstWhere(
      (m) => m.name == json['mode'],
      orElse: () => PlaybackMode.sequential,
    );
  }
}
