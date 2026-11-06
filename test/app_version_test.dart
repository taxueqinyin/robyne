import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/app_version.dart';

void main() {
  test('app version matches pubspec.yaml and its build metadata', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml has no version field');
    expect(appVersion, match!.group(1));
    expect(appVersion, matches(r'^\d+\.\d+\.\d+\+\d+$'));
    expect(shortAppVersion, 'v1.1.0');
    expect(appDisplayVersion, 'v$appVersion');
    expect(robyneRepositoryUrl, 'https://github.com/taxueqinyin/robyne');
  });
}
