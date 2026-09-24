import '../domain/theme_package.dart';
import 'theme_manifest_parser.dart';

/// Parses a decoded `theme.json` payload into a [ThemePackage].
///
/// Shared by the built-in and user repositories so both sources produce
/// identical models.
ThemePackage? parseThemeManifest(
  Object? raw, {
  required ThemeSource source,
  String? fallbackId,
}) {
  return const ThemeManifestParser().tryParse(
    raw,
    source: source,
    fallbackId: fallbackId,
  );
}
