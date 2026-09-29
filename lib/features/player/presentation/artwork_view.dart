import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/infrastructure/token_resolver.dart';

class ArtworkView extends StatefulWidget {
  const ArtworkView({
    super.key,
    this.artworkUrl,
    this.size = 48,
    this.fit = BoxFit.cover,
    this.expand = false,
  });

  static final Map<String, ImageProvider<Object>> _resolvedProviders =
      <String, ImageProvider<Object>>{};
  static final Map<String, Future<ImageProvider<Object>?>> _pendingProviders =
      <String, Future<ImageProvider<Object>?>>{};

  final String? artworkUrl;
  final double size;

  /// How the image is fitted inside its box.
  final BoxFit fit;

  /// Fill the incoming constraints instead of a square of [size].
  ///
  /// Collection covers are wide, not square, so a card cannot use the default
  /// square. The cache is shared either way: only the box changes, never where
  /// the bytes are stored.
  final bool expand;

  static Future<void> precacheUrls(
    BuildContext context,
    Iterable<String?> artworkUrls, {
    int limit = 60,
  }) async {
    final urls = <String>[];
    final seen = <String>{};
    for (final rawUrl in artworkUrls) {
      final url = rawUrl?.trim();
      if (url == null || url.isEmpty || !seen.add(url)) {
        continue;
      }
      urls.add(url);
      if (urls.length >= limit) {
        break;
      }
    }

    await Future.wait<void>(
      urls.map((url) async {
        try {
          final provider = await _providerForUrl(url);
          if (provider != null && context.mounted) {
            await precacheImage(provider, context);
          }
        } catch (_) {
          // Broken artwork URLs should not affect search results.
        }
      }),
    );
  }

  @override
  State<ArtworkView> createState() => _ArtworkViewState();

  static Future<ImageProvider<Object>?> _providerForUrl(String url) {
    final resolved = _resolvedProviders[url];
    if (resolved != null) {
      return Future<ImageProvider<Object>?>.value(resolved);
    }
    return _pendingProviders.putIfAbsent(url, () async {
      try {
        final provider = await _loadProvider(url);
        if (provider != null) {
          _resolvedProviders[url] = provider;
        }
        return provider;
      } finally {
        _pendingProviders.remove(url);
      }
    });
  }

  static Future<ImageProvider<Object>?> _loadProvider(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }

    if (uri.scheme == 'file') {
      final file = File.fromUri(uri);
      return await file.exists() ? FileImage(file) : null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      final file = File(url);
      return await file.exists() ? FileImage(file) : null;
    }

    final cachedFile = await _cacheFileForUrl(url);
    if (await cachedFile.exists() && await cachedFile.length() > 0) {
      return FileImage(cachedFile);
    }

    final tempFile = File('${cachedFile.path}.download');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return NetworkImage(url);
      }
      await response.pipe(tempFile.openWrite());
      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
      await tempFile.rename(cachedFile.path);
      return FileImage(cachedFile);
    } catch (_) {
      if (await tempFile.exists()) {
        unawaited(tempFile.delete());
      }
      return NetworkImage(url);
    } finally {
      client.close(force: true);
    }
  }

  static Future<File> _cacheFileForUrl(String url) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/robyne_artwork_cache',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/${_stableHash(url)}.img');
  }

  static String _stableHash(String value) {
    var hash = 0xcbf29ce484222325;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}

class _ArtworkViewState extends State<ArtworkView> {
  Future<ImageProvider<Object>?>? _providerFuture;
  String? _loadedUrl;

  @override
  void initState() {
    super.initState();
    _updateProviderFuture();
  }

  @override
  void didUpdateWidget(covariant ArtworkView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkUrl != widget.artworkUrl) {
      _updateProviderFuture();
    }
  }

  void _updateProviderFuture() {
    final url = widget.artworkUrl?.trim();
    _loadedUrl = url;
    _providerFuture = url == null || url.isEmpty
        ? null
        : ArtworkView._providerForUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.artworkUrl?.trim();
    final cachedProvider = url == null || url.isEmpty
        ? null
        : ArtworkView._resolvedProviders[url];
    return ClipRRect(
      // Artwork corners follow the skin's small radius rather than a literal.
      borderRadius: BorderRadius.circular(
        RobyneTheme.of(context).tokens.radius.sm,
      ),
      child: widget.expand
          ? SizedBox.expand(child: _body(url, cachedProvider))
          : SizedBox.square(
              dimension: widget.size,
              child: _body(url, cachedProvider),
            ),
    );
  }

  /// The resolved image, or the placeholder while it loads / on failure.
  Widget _body(String? url, ImageProvider<Object>? cachedProvider) {
    if (url == null || url.isEmpty) {
      return _FallbackArtwork(size: widget.size);
    }
    if (cachedProvider != null) {
      return _ArtworkImage(
        provider: cachedProvider,
        size: widget.size,
        fit: widget.fit,
      );
    }
    return FutureBuilder<ImageProvider<Object>?>(
      future: _providerFuture,
      builder: (context, snapshot) {
        if (_loadedUrl != url ||
            snapshot.connectionState != ConnectionState.done ||
            snapshot.data == null) {
          return _FallbackArtwork(size: widget.size);
        }
        return _ArtworkImage(
          provider: snapshot.data!,
          size: widget.size,
          fit: widget.fit,
        );
      },
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({
    required this.provider,
    required this.size,
    this.fit = BoxFit.cover,
  });

  final ImageProvider<Object> provider;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: provider,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          _FallbackArtwork(size: size),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return _FallbackArtwork(size: size);
      },
    );
  }
}

class _FallbackArtwork extends StatelessWidget {
  const _FallbackArtwork({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.components.card.surface),
      child: Icon(
        Icons.album,
        size: size * 0.44,
        color: tokens.color.textMuted,
      ),
    );
  }
}
