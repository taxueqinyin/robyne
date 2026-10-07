import 'dart:io';

import 'package:image/image.dart' as image;

/// Regenerates the Windows, Android, and skin logos from one master PNG.
Future<void> main() async {
  const sourcePath = 'assets/branding/robyne_logo_source.png';
  const skinLogoPath = 'assets/themes/xuan/assets/logo.png';
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing source logo: $sourcePath');
    exitCode = 1;
    return;
  }

  final decoded = image.decodePng(await sourceFile.readAsBytes());
  if (decoded == null) {
    stderr.writeln('Could not decode $sourcePath as PNG.');
    exitCode = 1;
    return;
  }

  final master = _centerSquare(decoded);
  await _writePng(skinLogoPath, _resizeSquare(master, 256));

  const androidIcons = <String, int>{
    'mipmap-mdpi/ic_launcher.png': 48,
    'mipmap-hdpi/ic_launcher.png': 72,
    'mipmap-xhdpi/ic_launcher.png': 96,
    'mipmap-xxhdpi/ic_launcher.png': 144,
    'mipmap-xxxhdpi/ic_launcher.png': 192,
  };
  for (final entry in androidIcons.entries) {
    await _writePng(
      'android/app/src/main/res/${entry.key}',
      _resizeSquare(master, entry.value),
    );
  }

  final iconResult = await Process.run('magick', <String>[
    sourcePath,
    '-define',
    'icon:auto-resize=256,128,64,48,32,16',
    'windows/runner/resources/app_icon.ico',
  ], runInShell: true);
  if (iconResult.exitCode != 0) {
    stderr.writeln(iconResult.stderr);
    exitCode = iconResult.exitCode;
    return;
  }

  stdout.writeln(
    'Wrote $skinLogoPath and ${androidIcons.length} Android launcher icons.',
  );
}

image.Image _resizeSquare(image.Image source, int size) {
  return image.copyResize(
    source,
    width: size,
    height: size,
    interpolation: image.Interpolation.cubic,
  );
}

Future<void> _writePng(String path, image.Image output) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(image.encodePng(output));
}

image.Image _centerSquare(image.Image source) {
  if (source.width == source.height) {
    return source;
  }
  final side = source.width < source.height ? source.width : source.height;
  final x = (source.width - side) ~/ 2;
  final y = (source.height - side) ~/ 2;
  return image.copyCrop(source, x: x, y: y, width: side, height: side);
}
