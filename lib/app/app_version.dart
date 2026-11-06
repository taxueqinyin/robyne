/// The version and build number from the `version:` field in `pubspec.yaml`,
/// optionally overridden by `--build-name` / `--build-number` at build time.
///
/// This is the single source for the About dialog. A test reads `pubspec.yaml`
/// and fails if this constant drifts from a version bump.
const String appVersion = '1.1.0+3';

/// The version shown beside the About entry: semantic version only.
String get shortAppVersion => 'v${appVersion.split('+').first}';

/// The full display version shown inside the About dialog.
String get appDisplayVersion => 'v$appVersion';

/// The Robyne project repository shown in the About dialog.
const String robyneRepositoryUrl = 'https://github.com/taxueqinyin/robyne';
