# Robyne Android bundled SQLite

`package:sqlite3` in this project resolves its native library with
`dlopen("libsqlite3.so")` at runtime (configured via `hooks.user_defines` in
`pubspec.yaml`). On Windows that resolves to the OS-provided `winsqlite3.dll`.
Android has no public `libsqlite3.so`, so we compile SQLite from the upstream
amalgamation and ship it in `android/app/src/main/jniLibs/<abi>/libsqlite3.so`.

`android/app/build.gradle.kts` sets `useLegacyPackaging = true` so the `.so`
files are extracted to the filesystem at install time; without that,
`dlopen` by name cannot see libraries that stay inside the APK.

The shipped binaries were compiled with the same feature flags as the
prebuilt binaries the sqlite3.dart project distributes (FTS5, R-Tree,
math functions, session/preupdate, etc.).

## Rebuilding

Run from the repo root (requires the Android NDK; the script auto-detects
the newest installed NDK under `%ANDROID_HOME%\ndk`):

```powershell
pwsh native/sqlite3/build_android.ps1
```

The script downloads the amalgamation from sqlite.org, compiles
`arm64-v8a`, `armeabi-v7a`, `x86_64`, and `riscv64`, and verifies that
`sqlite3_initialize` is exported from each build. Re-run it whenever you
bump the SQLite version or change compile flags.
