# Android Validation

Last updated: 2026-05-27

## Environment

| Item | Result |
|---|---|
| Flutter | 3.41.3 stable |
| Android SDK | `D:\software\AndroidSDK`, Android SDK 35.0.0 with platform android-36 |
| Android licenses | Accepted |
| NDK side by side / CMake | Installed by user; debug APK builds successfully |
| Connected device | `25019PNF3C` / `9b234798`, Android 16 API 36 |
| Internet permission | Present |
| Cleartext HTTP | `android:usesCleartextTraffic="true"` present in main manifest |

## Verified

| Check | Result | Command / evidence |
|---|---|---|
| `flutter doctor -v` Android toolchain | Passed | Doctor reports Android toolchain OK and all licenses accepted. |
| Debug APK build | Passed | `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn flutter build apk --debug` |
| Debug APK install | Passed once; latest retry blocked by device policy | `flutter install --debug -d 9b234798` installed `app-debug.apk` earlier. A later reinstall was cancelled by the phone with `INSTALL_FAILED_USER_RESTRICTED`, after uninstalling the old app. |
| App process start | Passed once; latest retry unavailable after cancelled reinstall | Earlier `adb shell am start -n com.robyne.robyne/.MainActivity` returned a process id. Latest retry failed because the app was no longer installed after the cancelled reinstall. |
| Startup crash check | Passed | `adb logcat` sample after launch showed no `FATAL EXCEPTION` / `AndroidRuntime` crash. |
| Windows debug build after Android changes | Passed | `flutter build windows --debug` |

## Remaining Android Checks

These require interactive device use:

| Check | Status | Notes |
|---|---|---|
| Import plugin on Android | Pending | Needs file picker / storage path validation on device. |
| Search via enabled plugins | Pending | Verify both HTTPS and HTTP-backed plugins. |
| Play HTTPS stream | Pending | Confirm media_kit Android playback and headers. |
| Play HTTP cleartext stream | Pending | Cleartext is configured; still needs a real plugin media source test. |
| Last-click-wins playback race | Pending | Start a slow source, then immediately start another source and confirm old source cannot replace current playback. |

## Network Note

Direct access to `https://storage.googleapis.com/` fails on this machine with a TLS handshake error. Android builds succeed when Flutter artifacts are downloaded through the Flutter mirror:

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
flutter build apk --debug
```
