import 'dart:convert';

enum RobyneWindowType { main, desktopLyrics }

class RobyneWindowArguments {
  const RobyneWindowArguments({required this.type});

  const RobyneWindowArguments.main() : type = RobyneWindowType.main;

  const RobyneWindowArguments.desktopLyrics()
    : type = RobyneWindowType.desktopLyrics;

  final RobyneWindowType type;

  String encode() {
    return jsonEncode(<String, Object?>{'type': type.name});
  }

  static RobyneWindowArguments parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const RobyneWindowArguments.main();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const RobyneWindowArguments.main();
      }
      final type = decoded['type']?.toString();
      return switch (type) {
        'desktopLyrics' => const RobyneWindowArguments.desktopLyrics(),
        _ => const RobyneWindowArguments.main(),
      };
    } catch (_) {
      return const RobyneWindowArguments.main();
    }
  }
}
