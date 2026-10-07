# Robyne

A music player built with Flutter. Runs on Windows and Android, with a plugin system for music sources.

[中文](./README.md)

## What it does

Robyne ships with no music sources of its own. It provides the plugin layer: you import JS plugins, and it runs them, searches, resolves playable URLs, and plays. The music comes from plugins, and plugins are yours to manage.

- MusicFree-style JS source plugins, importable from a local file, a folder, or a URL
- Search, play queue, repeat modes, and resume from last position
- Lyrics with offset tuning, plus multi-window desktop lyrics
- Local library, playlists, and online playlist collections
- Downloads with audio format conversion
- An importable skin system; the official UI is itself a skin
- Windows desktop extras: system tray, global hotkeys, capsule window mode

## Getting started

Requires Flutter 3.41+ (SDK `^3.11.1`). On Windows you also need the Visual Studio C++ toolchain, since QuickJS has a native component.

```bash
flutter pub get
flutter run -d windows    # or -d android
```

Release build for Windows:

```bash
flutter build windows
```

If Android builds stall behind the Great Firewall, set the Flutter mirror first:

```bash
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## Adding a music source

Open the Plugins page and import from a local file, folder, or URL. Imported plugins show up in the list, and you can start searching from the Search page.

Plugins may ask for user variables such as cookies or quality preferences; fill them in on the plugin detail page. Variables flagged as sensitive are masked in the UI. Malicious plugins remain a possibility, so only install ones you trust.

## Skins

A skin is a directory containing `theme.json`, or that directory zipped into a `.rtheme`. The minimal version is two fields:

```json
{
  "id": "mytheme",
  "name": "My first skin"
}
```

**Skins are pure data with no executable code**, so a skin has no way to harm your device. Missing fields fall back to built-in defaults, so skipping one never gets you a blank screen or an error.

To write a real skin, see [docs/THEME_AUTHORING.md](./docs/THEME_AUTHORING.md). The bundled skins in [`assets/themes/`](./assets/themes/) are good references.

## Project layout

Clean Architecture layering, one directory per feature:

```
lib/
  app/          app shell, routing, desktop window control
  core/theme/   skin engine (tokens, materials, import/export)
  features/     discover library player lyrics playlists
                plugin search settings downloads tray
native/sqlite3/ SQLite sources for Android
```

Stack: Flutter + Riverpod + media_kit (playback) + drift/SQLite (local storage) + QuickJS (plugin runtime).

## Tests

```bash
flutter test
```

Around 550 cases covering UI, business rules, skin parsing, and security boundaries.

## Building

```bash
flutter build windows --release   # build/windows/x64/runner/Release/
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
```

The Windows output is a directory (exe + DLLs + `data/`) and only runs as a
directory, so releases ship it as a zip.

Pushing a tag builds Windows and Android and publishes them to GitHub
Releases:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

### Android signing

Without a keystore the APK is signed with the debug key — installable, but
not a distributable release. To sign properly, set the repo variable
`SIGN_ANDROID=true` and these secrets: `ANDROID_KEYSTORE_BASE64`
(`base64 -i keystore.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`. Never commit the keystore itself.

## Status

Usable day to day, still in development. Some community plugins fail because they call APIs that aren't supported yet; see [docs/plugin_compatibility_matrix.md](./docs/plugin_compatibility_matrix.md).

## License

See [LICENSE](./LICENSE). Third-party dependencies keep their own licenses; vendored parts in this repo (SQLite, QuickJS, the JS vendor bundle) follow their original licenses.

