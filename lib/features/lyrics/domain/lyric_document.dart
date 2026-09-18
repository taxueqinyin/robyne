enum LyricSourceType { embedded, sidecar, localAssociation, plugin }

class LyricLine {
  const LyricLine({required this.text, this.timestamp});

  final String text;
  final Duration? timestamp;
}

class LyricDocument {
  const LyricDocument({
    required this.raw,
    required this.lines,
    required this.sourceType,
    this.offset = Duration.zero,
  });

  final String raw;
  final List<LyricLine> lines;
  final LyricSourceType sourceType;
  final Duration offset;

  bool get isSynchronized => lines.any((line) => line.timestamp != null);

  LyricDocument copyWith({Duration? offset}) {
    return LyricDocument(
      raw: raw,
      lines: lines,
      sourceType: sourceType,
      offset: offset ?? this.offset,
    );
  }

  int activeIndex(Duration position) {
    final effectivePosition = position + offset;
    var active = -1;
    for (var index = 0; index < lines.length; index += 1) {
      final timestamp = lines[index].timestamp;
      if (timestamp == null) {
        continue;
      }
      if (timestamp <= effectivePosition) {
        active = index;
      } else {
        break;
      }
    }
    return active;
  }

  Duration? startOfCurrentLine(Duration position) {
    final index = activeIndex(position);
    if (index < 0) {
      return null;
    }
    return _seekPositionForLine(index);
  }

  Duration? startOfPreviousLine(Duration position) {
    final index = activeIndex(position);
    if (index < 0) {
      return null;
    }
    for (var candidate = index - 1; candidate >= 0; candidate -= 1) {
      if (lines[candidate].timestamp != null) {
        return _seekPositionForLine(candidate);
      }
    }
    return _seekPositionForLine(index);
  }

  Duration? startOfNextLine(Duration position) {
    final index = activeIndex(position);
    if (index < 0) {
      for (var candidate = 0; candidate < lines.length; candidate += 1) {
        if (lines[candidate].timestamp != null) {
          return _seekPositionForLine(candidate);
        }
      }
      return null;
    }
    for (var candidate = index + 1; candidate < lines.length; candidate += 1) {
      if (lines[candidate].timestamp != null) {
        return _seekPositionForLine(candidate);
      }
    }
    return _seekPositionForLine(index);
  }

  static LyricDocument parse(
    String raw, {
    required LyricSourceType sourceType,
    Duration offset = Duration.zero,
  }) {
    final lines = <LyricLine>[];
    for (final sourceLine in raw.split(RegExp(r'\r?\n'))) {
      final parsed = _parseLine(sourceLine);
      if (parsed.isEmpty && sourceLine.trim().isNotEmpty) {
        lines.add(LyricLine(text: sourceLine.trim()));
      } else {
        lines.addAll(parsed);
      }
    }
    final timed = lines.where((line) => line.timestamp != null).toList()
      ..sort((left, right) => left.timestamp!.compareTo(right.timestamp!));
    final untimed = lines.where((line) => line.timestamp == null).toList();
    return LyricDocument(
      raw: raw,
      lines: timed.isEmpty ? untimed : <LyricLine>[...timed, ...untimed],
      sourceType: sourceType,
      offset: offset,
    );
  }

  static List<LyricLine> _parseLine(String line) {
    final matches = _timestampPattern.allMatches(line).toList();
    if (matches.isEmpty) {
      return const <LyricLine>[];
    }
    final text = line.replaceAll(_timestampPattern, '').trim();
    return matches
        .map((match) => LyricLine(text: text, timestamp: _duration(match)))
        .toList(growable: false);
  }

  static Duration _duration(RegExpMatch match) {
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    final fraction = match.group(4);
    final milliseconds = fraction == null
        ? 0
        : int.parse(fraction.padRight(3, '0').substring(0, 3));
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  Duration? _seekPositionForLine(int index) {
    final timestamp = lines[index].timestamp;
    if (timestamp == null) {
      return null;
    }
    final effective = timestamp - offset;
    return effective.isNegative ? Duration.zero : effective;
  }
}

final _timestampPattern = RegExp(
  r'\[(?:(\d{1,2}):)?(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]',
);
