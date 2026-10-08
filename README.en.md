<div align="center">

<img src="./assets/themes/xuan/assets/logo.png" alt="Robyne" width="128" height="128">

# Robyne

A music player built with Flutter. Runs on Windows and Android, with a plugin system for music sources.

[中文](./README.md)

</div>

## Disclaimer

This project exists to explore AI coding techniques. It ships with no music source plugins, and it does not provide, store, or distribute any copyrighted audio content. All music comes from third-party plugins that the user imports on their own.

The user is solely responsible for any infringement or other legal issues arising from the use of this project, including any plugin they import or content they access. The project authors accept no liability. Use it only where your local law permits.

Bug reports and feature suggestions are welcome in the [Issues](../../issues) section.

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
flutter build macos --release     # build/macos/Build/Products/Release/
```

The Windows output is a directory (exe + DLLs + `data/`) and only runs as a
directory, so releases ship it as a zip.

Pushing a tag builds Windows, Android and macOS, and publishes them to
GitHub Releases:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

### macOS is untested

The repository has a `macos/` platform folder and CI compiles it on every
push, but **nobody has actually run Robyne on a Mac**. A successful build
only proves the platform folders and dependencies line up — not that
playback, the tray, or plugins work.

macOS does ship an artifact (`robyne-macos-unsigned-*.zip`) so anyone with a
Mac can try it without building from source, but it is **unsigned and
unnotarized**, so macOS refuses to launch it. The release notes carry the
steps to get past that.

#### Getting past Gatekeeper

Because the bundle carries neither a signature nor a notarization ticket,
macOS blocks it. Try these in order:

1. Open **System Settings → Privacy & Security**, scroll to the Security
   section, and click **Open Anyway** once the prompt appears. On macOS 13
   Ventura and later this is the reliable route; on older versions
   right-clicking the app and choosing Open used to work, but that entry
   point is no longer dependable.
2. If macOS instead says the app **"is damaged and can't be opened. You
   should move it to the Trash"** with no way to open it, that is the
   quarantine attribute, not actual damage. Clear it in Terminal:

   ```bash
   xattr -cr /Applications/robyne.app
   ```

   Substitute the path wherever you actually put `robyne.app`.

If you try it, please open an issue describing what works and what does not;
that is the first step toward making macOS a supported platform.

Supporting it properly also needs a paid Apple Developer Program
membership for signing and notarization; without it, every user has to work
through the bypass above. See [docs/RELEASING.md](./docs/RELEASING.md).

### Android signing

Releases are signed by CI with the project's own key, so the APK installs
as-is.

If you fork this and cut your own release, CI has no key to use and falls
back to the debug key with a loud warning — that APK installs, but is not
meant for distribution. See [docs/RELEASING.md](./docs/RELEASING.md).

## Status

Usable day to day, still in development. Some community plugins fail because they call APIs that aren't supported yet; see [docs/plugin_compatibility_matrix.md](./docs/plugin_compatibility_matrix.md).

## License

See [LICENSE](./LICENSE). Third-party dependencies keep their own licenses; vendored parts in this repo (SQLite, QuickJS, the JS vendor bundle) follow their original licenses.
