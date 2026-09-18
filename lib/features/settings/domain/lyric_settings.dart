import 'package:flutter/material.dart';

class LyricSettings {
  const LyricSettings({
    required this.desktopLyricsEnabled,
    required this.desktopLyricsAlwaysOnTop,
    required this.desktopLyricsLocked,
    required this.desktopLyricsDoubleLine,
    required this.desktopLyricFontFamily,
    required this.desktopLyricFontSize,
    required this.desktopLyricTextColorValue,
    required this.desktopLyricStrokeColorValue,
    required this.desktopLyricWindowLeft,
    required this.desktopLyricWindowTop,
  });

  const LyricSettings.defaults()
    : desktopLyricsEnabled = false,
      desktopLyricsAlwaysOnTop = true,
      desktopLyricsLocked = false,
      desktopLyricsDoubleLine = false,
      desktopLyricFontFamily = null,
      desktopLyricFontSize = 28,
      desktopLyricTextColorValue = 0xFFFFFFFF,
      desktopLyricStrokeColorValue = 0xB3000000,
      desktopLyricWindowLeft = null,
      desktopLyricWindowTop = null;

  static const minFontSize = 12;
  static const maxFontSize = 80;
  static const fontSizeStep = 2;
  static const noStrokeColorValue = 0x00000000;

  final bool desktopLyricsEnabled;
  final bool desktopLyricsAlwaysOnTop;
  final bool desktopLyricsLocked;
  final bool desktopLyricsDoubleLine;
  final String? desktopLyricFontFamily;
  final int desktopLyricFontSize;
  final int desktopLyricTextColorValue;
  final int desktopLyricStrokeColorValue;
  final double? desktopLyricWindowLeft;
  final double? desktopLyricWindowTop;

  double get fontSize =>
      desktopLyricFontSize.clamp(minFontSize, maxFontSize).toDouble();
  Color get textColor => Color(desktopLyricTextColorValue);
  Color get strokeColor => Color(desktopLyricStrokeColorValue);
  bool get hasStroke => desktopLyricStrokeColorValue != noStrokeColorValue;
  bool get hasDesktopLyricWindowPosition =>
      desktopLyricWindowLeft != null && desktopLyricWindowTop != null;
  Offset? get desktopLyricWindowOffset => hasDesktopLyricWindowPosition
      ? Offset(desktopLyricWindowLeft!, desktopLyricWindowTop!)
      : null;

  LyricSettings copyWith({
    bool? desktopLyricsEnabled,
    bool? desktopLyricsAlwaysOnTop,
    bool? desktopLyricsLocked,
    bool? desktopLyricsDoubleLine,
    String? desktopLyricFontFamily,
    bool clearDesktopLyricFontFamily = false,
    int? desktopLyricFontSize,
    int? desktopLyricTextColorValue,
    int? desktopLyricStrokeColorValue,
    double? desktopLyricWindowLeft,
    double? desktopLyricWindowTop,
    bool clearDesktopLyricWindowPosition = false,
  }) {
    return LyricSettings(
      desktopLyricsEnabled: desktopLyricsEnabled ?? this.desktopLyricsEnabled,
      desktopLyricsAlwaysOnTop:
          desktopLyricsAlwaysOnTop ?? this.desktopLyricsAlwaysOnTop,
      desktopLyricsLocked: desktopLyricsLocked ?? this.desktopLyricsLocked,
      desktopLyricsDoubleLine:
          desktopLyricsDoubleLine ?? this.desktopLyricsDoubleLine,
      desktopLyricFontFamily: clearDesktopLyricFontFamily
          ? null
          : desktopLyricFontFamily ?? this.desktopLyricFontFamily,
      desktopLyricFontSize: (desktopLyricFontSize ?? this.desktopLyricFontSize)
          .clamp(minFontSize, maxFontSize),
      desktopLyricTextColorValue:
          desktopLyricTextColorValue ?? this.desktopLyricTextColorValue,
      desktopLyricStrokeColorValue:
          desktopLyricStrokeColorValue ?? this.desktopLyricStrokeColorValue,
      desktopLyricWindowLeft: clearDesktopLyricWindowPosition
          ? null
          : desktopLyricWindowLeft ?? this.desktopLyricWindowLeft,
      desktopLyricWindowTop: clearDesktopLyricWindowPosition
          ? null
          : desktopLyricWindowTop ?? this.desktopLyricWindowTop,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'desktopLyricsEnabled': desktopLyricsEnabled,
      'desktopLyricsAlwaysOnTop': desktopLyricsAlwaysOnTop,
      'desktopLyricsLocked': desktopLyricsLocked,
      'desktopLyricsDoubleLine': desktopLyricsDoubleLine,
      'desktopLyricFontFamily': desktopLyricFontFamily,
      'desktopLyricFontSize': desktopLyricFontSize,
      'desktopLyricTextColorValue': desktopLyricTextColorValue,
      'desktopLyricStrokeColorValue': desktopLyricStrokeColorValue,
      'desktopLyricWindowLeft': desktopLyricWindowLeft,
      'desktopLyricWindowTop': desktopLyricWindowTop,
    };
  }

  factory LyricSettings.fromJson(Map<Object?, Object?> json) {
    const fallback = LyricSettings.defaults();
    final rawFontFamily = json['desktopLyricFontFamily']?.toString().trim();
    return LyricSettings(
      desktopLyricsEnabled: json['desktopLyricsEnabled'] == true,
      desktopLyricsAlwaysOnTop: json['desktopLyricsAlwaysOnTop'] is bool
          ? json['desktopLyricsAlwaysOnTop']! as bool
          : fallback.desktopLyricsAlwaysOnTop,
      desktopLyricsLocked: json['desktopLyricsLocked'] == true,
      desktopLyricsDoubleLine: json['desktopLyricsDoubleLine'] == true,
      desktopLyricFontFamily: rawFontFamily == null || rawFontFamily.isEmpty
          ? null
          : rawFontFamily,
      desktopLyricFontSize:
          (json['desktopLyricFontSize'] as num?)?.toInt() ??
          fallback.desktopLyricFontSize,
      desktopLyricTextColorValue:
          (json['desktopLyricTextColorValue'] as num?)?.toInt() ??
          fallback.desktopLyricTextColorValue,
      desktopLyricStrokeColorValue:
          (json['desktopLyricStrokeColorValue'] as num?)?.toInt() ??
          fallback.desktopLyricStrokeColorValue,
      desktopLyricWindowLeft: (json['desktopLyricWindowLeft'] as num?)
          ?.toDouble(),
      desktopLyricWindowTop: (json['desktopLyricWindowTop'] as num?)
          ?.toDouble(),
    ).copyWith();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LyricSettings &&
        other.desktopLyricsEnabled == desktopLyricsEnabled &&
        other.desktopLyricsAlwaysOnTop == desktopLyricsAlwaysOnTop &&
        other.desktopLyricsLocked == desktopLyricsLocked &&
        other.desktopLyricsDoubleLine == desktopLyricsDoubleLine &&
        other.desktopLyricFontFamily == desktopLyricFontFamily &&
        other.desktopLyricFontSize == desktopLyricFontSize &&
        other.desktopLyricTextColorValue == desktopLyricTextColorValue &&
        other.desktopLyricStrokeColorValue == desktopLyricStrokeColorValue &&
        other.desktopLyricWindowLeft == desktopLyricWindowLeft &&
        other.desktopLyricWindowTop == desktopLyricWindowTop;
  }

  @override
  int get hashCode => Object.hash(
    desktopLyricsEnabled,
    desktopLyricsAlwaysOnTop,
    desktopLyricsLocked,
    desktopLyricsDoubleLine,
    desktopLyricFontFamily,
    desktopLyricFontSize,
    desktopLyricTextColorValue,
    desktopLyricStrokeColorValue,
    desktopLyricWindowLeft,
    desktopLyricWindowTop,
  );
}
