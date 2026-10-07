// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PlaybackItemsTable extends PlaybackItems
    with TableInfo<$PlaybackItemsTable, PlaybackItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _musicIdMeta = const VerificationMeta(
    'musicId',
  );
  @override
  late final GeneratedColumn<String> musicId = GeneratedColumn<String>(
    'music_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    platform,
    musicId,
    localPath,
    artist,
    album,
    durationMs,
    artworkUrl,
    rawJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    }
    if (data.containsKey('music_id')) {
      context.handle(
        _musicIdMeta,
        musicId.isAcceptableOrUnknown(data['music_id']!, _musicIdMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      ),
      musicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}music_id'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaybackItemsTable createAlias(String alias) {
    return $PlaybackItemsTable(attachedDatabase, alias);
  }
}

class PlaybackItem extends DataClass implements Insertable<PlaybackItem> {
  final String id;
  final String type;
  final String title;
  final String? platform;
  final String? musicId;
  final String? localPath;
  final String? artist;
  final String? album;
  final int? durationMs;
  final String? artworkUrl;
  final String rawJson;
  final DateTime updatedAt;
  const PlaybackItem({
    required this.id,
    required this.type,
    required this.title,
    this.platform,
    this.musicId,
    this.localPath,
    this.artist,
    this.album,
    this.durationMs,
    this.artworkUrl,
    required this.rawJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || platform != null) {
      map['platform'] = Variable<String>(platform);
    }
    if (!nullToAbsent || musicId != null) {
      map['music_id'] = Variable<String>(musicId);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    map['raw_json'] = Variable<String>(rawJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaybackItemsCompanion toCompanion(bool nullToAbsent) {
    return PlaybackItemsCompanion(
      id: Value(id),
      type: Value(type),
      title: Value(title),
      platform: platform == null && nullToAbsent
          ? const Value.absent()
          : Value(platform),
      musicId: musicId == null && nullToAbsent
          ? const Value.absent()
          : Value(musicId),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      rawJson: Value(rawJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaybackItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackItem(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      platform: serializer.fromJson<String?>(json['platform']),
      musicId: serializer.fromJson<String?>(json['musicId']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'platform': serializer.toJson<String?>(platform),
      'musicId': serializer.toJson<String?>(musicId),
      'localPath': serializer.toJson<String?>(localPath),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'durationMs': serializer.toJson<int?>(durationMs),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'rawJson': serializer.toJson<String>(rawJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaybackItem copyWith({
    String? id,
    String? type,
    String? title,
    Value<String?> platform = const Value.absent(),
    Value<String?> musicId = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<String?> artist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> artworkUrl = const Value.absent(),
    String? rawJson,
    DateTime? updatedAt,
  }) => PlaybackItem(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    platform: platform.present ? platform.value : this.platform,
    musicId: musicId.present ? musicId.value : this.musicId,
    localPath: localPath.present ? localPath.value : this.localPath,
    artist: artist.present ? artist.value : this.artist,
    album: album.present ? album.value : this.album,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    rawJson: rawJson ?? this.rawJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaybackItem copyWithCompanion(PlaybackItemsCompanion data) {
    return PlaybackItem(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      platform: data.platform.present ? data.platform.value : this.platform,
      musicId: data.musicId.present ? data.musicId.value : this.musicId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackItem(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('platform: $platform, ')
          ..write('musicId: $musicId, ')
          ..write('localPath: $localPath, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('rawJson: $rawJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    platform,
    musicId,
    localPath,
    artist,
    album,
    durationMs,
    artworkUrl,
    rawJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackItem &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.platform == this.platform &&
          other.musicId == this.musicId &&
          other.localPath == this.localPath &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.durationMs == this.durationMs &&
          other.artworkUrl == this.artworkUrl &&
          other.rawJson == this.rawJson &&
          other.updatedAt == this.updatedAt);
}

class PlaybackItemsCompanion extends UpdateCompanion<PlaybackItem> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> title;
  final Value<String?> platform;
  final Value<String?> musicId;
  final Value<String?> localPath;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<int?> durationMs;
  final Value<String?> artworkUrl;
  final Value<String> rawJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlaybackItemsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.platform = const Value.absent(),
    this.musicId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackItemsCompanion.insert({
    required String id,
    required String type,
    required String title,
    this.platform = const Value.absent(),
    this.musicId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       title = Value(title);
  static Insertable<PlaybackItem> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? platform,
    Expression<String>? musicId,
    Expression<String>? localPath,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<int>? durationMs,
    Expression<String>? artworkUrl,
    Expression<String>? rawJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (platform != null) 'platform': platform,
      if (musicId != null) 'music_id': musicId,
      if (localPath != null) 'local_path': localPath,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (durationMs != null) 'duration_ms': durationMs,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (rawJson != null) 'raw_json': rawJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? title,
    Value<String?>? platform,
    Value<String?>? musicId,
    Value<String?>? localPath,
    Value<String?>? artist,
    Value<String?>? album,
    Value<int?>? durationMs,
    Value<String?>? artworkUrl,
    Value<String>? rawJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlaybackItemsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      platform: platform ?? this.platform,
      musicId: musicId ?? this.musicId,
      localPath: localPath ?? this.localPath,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      rawJson: rawJson ?? this.rawJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (musicId.present) {
      map['music_id'] = Variable<String>(musicId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackItemsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('platform: $platform, ')
          ..write('musicId: $musicId, ')
          ..write('localPath: $localPath, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('rawJson: $rawJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayerStateRowsTable extends PlayerStateRows
    with TableInfo<$PlayerStateRowsTable, PlayerStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayerStateRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _currentItemIdMeta = const VerificationMeta(
    'currentItemId',
  );
  @override
  late final GeneratedColumn<String> currentItemId = GeneratedColumn<String>(
    'current_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playback_items (id)',
    ),
  );
  static const VerificationMeta _playbackModeMeta = const VerificationMeta(
    'playbackMode',
  );
  @override
  late final GeneratedColumn<String> playbackMode = GeneratedColumn<String>(
    'playback_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('sequence'),
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<double> volume = GeneratedColumn<double>(
    'volume',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _lastPositionMsMeta = const VerificationMeta(
    'lastPositionMs',
  );
  @override
  late final GeneratedColumn<int> lastPositionMs = GeneratedColumn<int>(
    'last_position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastDurationMsMeta = const VerificationMeta(
    'lastDurationMs',
  );
  @override
  late final GeneratedColumn<int> lastDurationMs = GeneratedColumn<int>(
    'last_duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currentItemId,
    playbackMode,
    volume,
    lastPositionMs,
    lastDurationMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'player_state_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayerStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_item_id')) {
      context.handle(
        _currentItemIdMeta,
        currentItemId.isAcceptableOrUnknown(
          data['current_item_id']!,
          _currentItemIdMeta,
        ),
      );
    }
    if (data.containsKey('playback_mode')) {
      context.handle(
        _playbackModeMeta,
        playbackMode.isAcceptableOrUnknown(
          data['playback_mode']!,
          _playbackModeMeta,
        ),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    if (data.containsKey('last_position_ms')) {
      context.handle(
        _lastPositionMsMeta,
        lastPositionMs.isAcceptableOrUnknown(
          data['last_position_ms']!,
          _lastPositionMsMeta,
        ),
      );
    }
    if (data.containsKey('last_duration_ms')) {
      context.handle(
        _lastDurationMsMeta,
        lastDurationMs.isAcceptableOrUnknown(
          data['last_duration_ms']!,
          _lastDurationMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayerStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayerStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currentItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_item_id'],
      ),
      playbackMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playback_mode'],
      )!,
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume'],
      )!,
      lastPositionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_position_ms'],
      )!,
      lastDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_duration_ms'],
      )!,
    );
  }

  @override
  $PlayerStateRowsTable createAlias(String alias) {
    return $PlayerStateRowsTable(attachedDatabase, alias);
  }
}

class PlayerStateRow extends DataClass implements Insertable<PlayerStateRow> {
  final int id;
  final String? currentItemId;
  final String playbackMode;
  final double volume;
  final int lastPositionMs;
  final int lastDurationMs;
  const PlayerStateRow({
    required this.id,
    this.currentItemId,
    required this.playbackMode,
    required this.volume,
    required this.lastPositionMs,
    required this.lastDurationMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || currentItemId != null) {
      map['current_item_id'] = Variable<String>(currentItemId);
    }
    map['playback_mode'] = Variable<String>(playbackMode);
    map['volume'] = Variable<double>(volume);
    map['last_position_ms'] = Variable<int>(lastPositionMs);
    map['last_duration_ms'] = Variable<int>(lastDurationMs);
    return map;
  }

  PlayerStateRowsCompanion toCompanion(bool nullToAbsent) {
    return PlayerStateRowsCompanion(
      id: Value(id),
      currentItemId: currentItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentItemId),
      playbackMode: Value(playbackMode),
      volume: Value(volume),
      lastPositionMs: Value(lastPositionMs),
      lastDurationMs: Value(lastDurationMs),
    );
  }

  factory PlayerStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayerStateRow(
      id: serializer.fromJson<int>(json['id']),
      currentItemId: serializer.fromJson<String?>(json['currentItemId']),
      playbackMode: serializer.fromJson<String>(json['playbackMode']),
      volume: serializer.fromJson<double>(json['volume']),
      lastPositionMs: serializer.fromJson<int>(json['lastPositionMs']),
      lastDurationMs: serializer.fromJson<int>(json['lastDurationMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentItemId': serializer.toJson<String?>(currentItemId),
      'playbackMode': serializer.toJson<String>(playbackMode),
      'volume': serializer.toJson<double>(volume),
      'lastPositionMs': serializer.toJson<int>(lastPositionMs),
      'lastDurationMs': serializer.toJson<int>(lastDurationMs),
    };
  }

  PlayerStateRow copyWith({
    int? id,
    Value<String?> currentItemId = const Value.absent(),
    String? playbackMode,
    double? volume,
    int? lastPositionMs,
    int? lastDurationMs,
  }) => PlayerStateRow(
    id: id ?? this.id,
    currentItemId: currentItemId.present
        ? currentItemId.value
        : this.currentItemId,
    playbackMode: playbackMode ?? this.playbackMode,
    volume: volume ?? this.volume,
    lastPositionMs: lastPositionMs ?? this.lastPositionMs,
    lastDurationMs: lastDurationMs ?? this.lastDurationMs,
  );
  PlayerStateRow copyWithCompanion(PlayerStateRowsCompanion data) {
    return PlayerStateRow(
      id: data.id.present ? data.id.value : this.id,
      currentItemId: data.currentItemId.present
          ? data.currentItemId.value
          : this.currentItemId,
      playbackMode: data.playbackMode.present
          ? data.playbackMode.value
          : this.playbackMode,
      volume: data.volume.present ? data.volume.value : this.volume,
      lastPositionMs: data.lastPositionMs.present
          ? data.lastPositionMs.value
          : this.lastPositionMs,
      lastDurationMs: data.lastDurationMs.present
          ? data.lastDurationMs.value
          : this.lastDurationMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayerStateRow(')
          ..write('id: $id, ')
          ..write('currentItemId: $currentItemId, ')
          ..write('playbackMode: $playbackMode, ')
          ..write('volume: $volume, ')
          ..write('lastPositionMs: $lastPositionMs, ')
          ..write('lastDurationMs: $lastDurationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    currentItemId,
    playbackMode,
    volume,
    lastPositionMs,
    lastDurationMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayerStateRow &&
          other.id == this.id &&
          other.currentItemId == this.currentItemId &&
          other.playbackMode == this.playbackMode &&
          other.volume == this.volume &&
          other.lastPositionMs == this.lastPositionMs &&
          other.lastDurationMs == this.lastDurationMs);
}

class PlayerStateRowsCompanion extends UpdateCompanion<PlayerStateRow> {
  final Value<int> id;
  final Value<String?> currentItemId;
  final Value<String> playbackMode;
  final Value<double> volume;
  final Value<int> lastPositionMs;
  final Value<int> lastDurationMs;
  const PlayerStateRowsCompanion({
    this.id = const Value.absent(),
    this.currentItemId = const Value.absent(),
    this.playbackMode = const Value.absent(),
    this.volume = const Value.absent(),
    this.lastPositionMs = const Value.absent(),
    this.lastDurationMs = const Value.absent(),
  });
  PlayerStateRowsCompanion.insert({
    this.id = const Value.absent(),
    this.currentItemId = const Value.absent(),
    this.playbackMode = const Value.absent(),
    this.volume = const Value.absent(),
    this.lastPositionMs = const Value.absent(),
    this.lastDurationMs = const Value.absent(),
  });
  static Insertable<PlayerStateRow> custom({
    Expression<int>? id,
    Expression<String>? currentItemId,
    Expression<String>? playbackMode,
    Expression<double>? volume,
    Expression<int>? lastPositionMs,
    Expression<int>? lastDurationMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentItemId != null) 'current_item_id': currentItemId,
      if (playbackMode != null) 'playback_mode': playbackMode,
      if (volume != null) 'volume': volume,
      if (lastPositionMs != null) 'last_position_ms': lastPositionMs,
      if (lastDurationMs != null) 'last_duration_ms': lastDurationMs,
    });
  }

  PlayerStateRowsCompanion copyWith({
    Value<int>? id,
    Value<String?>? currentItemId,
    Value<String>? playbackMode,
    Value<double>? volume,
    Value<int>? lastPositionMs,
    Value<int>? lastDurationMs,
  }) {
    return PlayerStateRowsCompanion(
      id: id ?? this.id,
      currentItemId: currentItemId ?? this.currentItemId,
      playbackMode: playbackMode ?? this.playbackMode,
      volume: volume ?? this.volume,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      lastDurationMs: lastDurationMs ?? this.lastDurationMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentItemId.present) {
      map['current_item_id'] = Variable<String>(currentItemId.value);
    }
    if (playbackMode.present) {
      map['playback_mode'] = Variable<String>(playbackMode.value);
    }
    if (volume.present) {
      map['volume'] = Variable<double>(volume.value);
    }
    if (lastPositionMs.present) {
      map['last_position_ms'] = Variable<int>(lastPositionMs.value);
    }
    if (lastDurationMs.present) {
      map['last_duration_ms'] = Variable<int>(lastDurationMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayerStateRowsCompanion(')
          ..write('id: $id, ')
          ..write('currentItemId: $currentItemId, ')
          ..write('playbackMode: $playbackMode, ')
          ..write('volume: $volume, ')
          ..write('lastPositionMs: $lastPositionMs, ')
          ..write('lastDurationMs: $lastDurationMs')
          ..write(')'))
        .toString();
  }
}

class $QueueEntriesTable extends QueueEntries
    with TableInfo<$QueueEntriesTable, QueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playback_items (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [position, itemId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  QueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueEntry(
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
    );
  }

  @override
  $QueueEntriesTable createAlias(String alias) {
    return $QueueEntriesTable(attachedDatabase, alias);
  }
}

class QueueEntry extends DataClass implements Insertable<QueueEntry> {
  final int position;
  final String itemId;
  const QueueEntry({required this.position, required this.itemId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['item_id'] = Variable<String>(itemId);
    return map;
  }

  QueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return QueueEntriesCompanion(
      position: Value(position),
      itemId: Value(itemId),
    );
  }

  factory QueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueEntry(
      position: serializer.fromJson<int>(json['position']),
      itemId: serializer.fromJson<String>(json['itemId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'itemId': serializer.toJson<String>(itemId),
    };
  }

  QueueEntry copyWith({int? position, String? itemId}) => QueueEntry(
    position: position ?? this.position,
    itemId: itemId ?? this.itemId,
  );
  QueueEntry copyWithCompanion(QueueEntriesCompanion data) {
    return QueueEntry(
      position: data.position.present ? data.position.value : this.position,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueEntry(')
          ..write('position: $position, ')
          ..write('itemId: $itemId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(position, itemId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueEntry &&
          other.position == this.position &&
          other.itemId == this.itemId);
}

class QueueEntriesCompanion extends UpdateCompanion<QueueEntry> {
  final Value<int> position;
  final Value<String> itemId;
  final Value<int> rowid;
  const QueueEntriesCompanion({
    this.position = const Value.absent(),
    this.itemId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QueueEntriesCompanion.insert({
    required int position,
    required String itemId,
    this.rowid = const Value.absent(),
  }) : position = Value(position),
       itemId = Value(itemId);
  static Insertable<QueueEntry> custom({
    Expression<int>? position,
    Expression<String>? itemId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (itemId != null) 'item_id': itemId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QueueEntriesCompanion copyWith({
    Value<int>? position,
    Value<String>? itemId,
    Value<int>? rowid,
  }) {
    return QueueEntriesCompanion(
      position: position ?? this.position,
      itemId: itemId ?? this.itemId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueEntriesCompanion(')
          ..write('position: $position, ')
          ..write('itemId: $itemId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackHistoryRowsTable extends PlaybackHistoryRows
    with TableInfo<$PlaybackHistoryRowsTable, PlaybackHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackHistoryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playback_items (id)',
    ),
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, itemId, playedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_history_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaybackHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}played_at'],
      )!,
    );
  }

  @override
  $PlaybackHistoryRowsTable createAlias(String alias) {
    return $PlaybackHistoryRowsTable(attachedDatabase, alias);
  }
}

class PlaybackHistoryRow extends DataClass
    implements Insertable<PlaybackHistoryRow> {
  final int id;
  final String itemId;
  final DateTime playedAt;
  const PlaybackHistoryRow({
    required this.id,
    required this.itemId,
    required this.playedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['item_id'] = Variable<String>(itemId);
    map['played_at'] = Variable<DateTime>(playedAt);
    return map;
  }

  PlaybackHistoryRowsCompanion toCompanion(bool nullToAbsent) {
    return PlaybackHistoryRowsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      playedAt: Value(playedAt),
    );
  }

  factory PlaybackHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackHistoryRow(
      id: serializer.fromJson<int>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemId': serializer.toJson<String>(itemId),
      'playedAt': serializer.toJson<DateTime>(playedAt),
    };
  }

  PlaybackHistoryRow copyWith({int? id, String? itemId, DateTime? playedAt}) =>
      PlaybackHistoryRow(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        playedAt: playedAt ?? this.playedAt,
      );
  PlaybackHistoryRow copyWithCompanion(PlaybackHistoryRowsCompanion data) {
    return PlaybackHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackHistoryRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, playedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackHistoryRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.playedAt == this.playedAt);
}

class PlaybackHistoryRowsCompanion extends UpdateCompanion<PlaybackHistoryRow> {
  final Value<int> id;
  final Value<String> itemId;
  final Value<DateTime> playedAt;
  const PlaybackHistoryRowsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.playedAt = const Value.absent(),
  });
  PlaybackHistoryRowsCompanion.insert({
    this.id = const Value.absent(),
    required String itemId,
    required DateTime playedAt,
  }) : itemId = Value(itemId),
       playedAt = Value(playedAt);
  static Insertable<PlaybackHistoryRow> custom({
    Expression<int>? id,
    Expression<String>? itemId,
    Expression<DateTime>? playedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (playedAt != null) 'played_at': playedAt,
    });
  }

  PlaybackHistoryRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? itemId,
    Value<DateTime>? playedAt,
  }) {
    return PlaybackHistoryRowsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      playedAt: playedAt ?? this.playedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackHistoryRowsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalLibraryTracksTable extends LocalLibraryTracks
    with TableInfo<$LocalLibraryTracksTable, LocalLibraryTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalLibraryTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playback_items (id)',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_library_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalLibraryTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  LocalLibraryTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalLibraryTrack(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $LocalLibraryTracksTable createAlias(String alias) {
    return $LocalLibraryTracksTable(attachedDatabase, alias);
  }
}

class LocalLibraryTrack extends DataClass
    implements Insertable<LocalLibraryTrack> {
  final String itemId;
  final DateTime addedAt;
  const LocalLibraryTrack({required this.itemId, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  LocalLibraryTracksCompanion toCompanion(bool nullToAbsent) {
    return LocalLibraryTracksCompanion(
      itemId: Value(itemId),
      addedAt: Value(addedAt),
    );
  }

  factory LocalLibraryTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalLibraryTrack(
      itemId: serializer.fromJson<String>(json['itemId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  LocalLibraryTrack copyWith({String? itemId, DateTime? addedAt}) =>
      LocalLibraryTrack(
        itemId: itemId ?? this.itemId,
        addedAt: addedAt ?? this.addedAt,
      );
  LocalLibraryTrack copyWithCompanion(LocalLibraryTracksCompanion data) {
    return LocalLibraryTrack(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalLibraryTrack(')
          ..write('itemId: $itemId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalLibraryTrack &&
          other.itemId == this.itemId &&
          other.addedAt == this.addedAt);
}

class LocalLibraryTracksCompanion extends UpdateCompanion<LocalLibraryTrack> {
  final Value<String> itemId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const LocalLibraryTracksCompanion({
    this.itemId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalLibraryTracksCompanion.insert({
    required String itemId,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId);
  static Insertable<LocalLibraryTrack> custom({
    Expression<String>? itemId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalLibraryTracksCompanion copyWith({
    Value<String>? itemId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return LocalLibraryTracksCompanion(
      itemId: itemId ?? this.itemId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalLibraryTracksCompanion(')
          ..write('itemId: $itemId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PluginDefinitionRowsTable extends PluginDefinitionRows
    with TableInfo<$PluginDefinitionRowsTable, PluginDefinitionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PluginDefinitionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supportedSearchTypesJsonMeta =
      const VerificationMeta('supportedSearchTypesJson');
  @override
  late final GeneratedColumn<String> supportedSearchTypesJson =
      GeneratedColumn<String>(
        'supported_search_types_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _userVariablesJsonMeta = const VerificationMeta(
    'userVariablesJson',
  );
  @override
  late final GeneratedColumn<String> userVariablesJson =
      GeneratedColumn<String>(
        'user_variables_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _userVariableValuesJsonMeta =
      const VerificationMeta('userVariableValuesJson');
  @override
  late final GeneratedColumn<String> userVariableValuesJson =
      GeneratedColumn<String>(
        'user_variable_values_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    platform,
    version,
    author,
    description,
    sourcePath,
    enabled,
    installedAt,
    updatedAt,
    supportedSearchTypesJson,
    userVariablesJson,
    userVariableValuesJson,
    sortIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plugin_definition_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PluginDefinitionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('supported_search_types_json')) {
      context.handle(
        _supportedSearchTypesJsonMeta,
        supportedSearchTypesJson.isAcceptableOrUnknown(
          data['supported_search_types_json']!,
          _supportedSearchTypesJsonMeta,
        ),
      );
    }
    if (data.containsKey('user_variables_json')) {
      context.handle(
        _userVariablesJsonMeta,
        userVariablesJson.isAcceptableOrUnknown(
          data['user_variables_json']!,
          _userVariablesJsonMeta,
        ),
      );
    }
    if (data.containsKey('user_variable_values_json')) {
      context.handle(
        _userVariableValuesJsonMeta,
        userVariableValuesJson.isAcceptableOrUnknown(
          data['user_variable_values_json']!,
          _userVariableValuesJsonMeta,
        ),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PluginDefinitionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PluginDefinitionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      supportedSearchTypesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supported_search_types_json'],
      )!,
      userVariablesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_variables_json'],
      )!,
      userVariableValuesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_variable_values_json'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  $PluginDefinitionRowsTable createAlias(String alias) {
    return $PluginDefinitionRowsTable(attachedDatabase, alias);
  }
}

class PluginDefinitionRow extends DataClass
    implements Insertable<PluginDefinitionRow> {
  final String id;
  final String platform;
  final String? version;
  final String? author;
  final String? description;
  final String sourcePath;
  final bool enabled;
  final DateTime installedAt;
  final DateTime updatedAt;
  final String supportedSearchTypesJson;
  final String userVariablesJson;
  final String userVariableValuesJson;

  /// The user's manual order within the plugin page.
  ///
  /// Not a sort preference: dragging a row rewrites this column, which is why
  /// it lives on the row rather than in settings. Positive values are explicit
  /// user placements and `0` means "never dragged", so freshly imported
  /// plugins and legacy rows stay in install order instead of colliding at a
  /// default rank.
  final int sortIndex;
  const PluginDefinitionRow({
    required this.id,
    required this.platform,
    this.version,
    this.author,
    this.description,
    required this.sourcePath,
    required this.enabled,
    required this.installedAt,
    required this.updatedAt,
    required this.supportedSearchTypesJson,
    required this.userVariablesJson,
    required this.userVariableValuesJson,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['platform'] = Variable<String>(platform);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<String>(version);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['source_path'] = Variable<String>(sourcePath);
    map['enabled'] = Variable<bool>(enabled);
    map['installed_at'] = Variable<DateTime>(installedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['supported_search_types_json'] = Variable<String>(
      supportedSearchTypesJson,
    );
    map['user_variables_json'] = Variable<String>(userVariablesJson);
    map['user_variable_values_json'] = Variable<String>(userVariableValuesJson);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  PluginDefinitionRowsCompanion toCompanion(bool nullToAbsent) {
    return PluginDefinitionRowsCompanion(
      id: Value(id),
      platform: Value(platform),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      sourcePath: Value(sourcePath),
      enabled: Value(enabled),
      installedAt: Value(installedAt),
      updatedAt: Value(updatedAt),
      supportedSearchTypesJson: Value(supportedSearchTypesJson),
      userVariablesJson: Value(userVariablesJson),
      userVariableValuesJson: Value(userVariableValuesJson),
      sortIndex: Value(sortIndex),
    );
  }

  factory PluginDefinitionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PluginDefinitionRow(
      id: serializer.fromJson<String>(json['id']),
      platform: serializer.fromJson<String>(json['platform']),
      version: serializer.fromJson<String?>(json['version']),
      author: serializer.fromJson<String?>(json['author']),
      description: serializer.fromJson<String?>(json['description']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      supportedSearchTypesJson: serializer.fromJson<String>(
        json['supportedSearchTypesJson'],
      ),
      userVariablesJson: serializer.fromJson<String>(json['userVariablesJson']),
      userVariableValuesJson: serializer.fromJson<String>(
        json['userVariableValuesJson'],
      ),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'platform': serializer.toJson<String>(platform),
      'version': serializer.toJson<String?>(version),
      'author': serializer.toJson<String?>(author),
      'description': serializer.toJson<String?>(description),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'enabled': serializer.toJson<bool>(enabled),
      'installedAt': serializer.toJson<DateTime>(installedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'supportedSearchTypesJson': serializer.toJson<String>(
        supportedSearchTypesJson,
      ),
      'userVariablesJson': serializer.toJson<String>(userVariablesJson),
      'userVariableValuesJson': serializer.toJson<String>(
        userVariableValuesJson,
      ),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  PluginDefinitionRow copyWith({
    String? id,
    String? platform,
    Value<String?> version = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<String?> description = const Value.absent(),
    String? sourcePath,
    bool? enabled,
    DateTime? installedAt,
    DateTime? updatedAt,
    String? supportedSearchTypesJson,
    String? userVariablesJson,
    String? userVariableValuesJson,
    int? sortIndex,
  }) => PluginDefinitionRow(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    version: version.present ? version.value : this.version,
    author: author.present ? author.value : this.author,
    description: description.present ? description.value : this.description,
    sourcePath: sourcePath ?? this.sourcePath,
    enabled: enabled ?? this.enabled,
    installedAt: installedAt ?? this.installedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    supportedSearchTypesJson:
        supportedSearchTypesJson ?? this.supportedSearchTypesJson,
    userVariablesJson: userVariablesJson ?? this.userVariablesJson,
    userVariableValuesJson:
        userVariableValuesJson ?? this.userVariableValuesJson,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  PluginDefinitionRow copyWithCompanion(PluginDefinitionRowsCompanion data) {
    return PluginDefinitionRow(
      id: data.id.present ? data.id.value : this.id,
      platform: data.platform.present ? data.platform.value : this.platform,
      version: data.version.present ? data.version.value : this.version,
      author: data.author.present ? data.author.value : this.author,
      description: data.description.present
          ? data.description.value
          : this.description,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      supportedSearchTypesJson: data.supportedSearchTypesJson.present
          ? data.supportedSearchTypesJson.value
          : this.supportedSearchTypesJson,
      userVariablesJson: data.userVariablesJson.present
          ? data.userVariablesJson.value
          : this.userVariablesJson,
      userVariableValuesJson: data.userVariableValuesJson.present
          ? data.userVariableValuesJson.value
          : this.userVariableValuesJson,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PluginDefinitionRow(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('version: $version, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('enabled: $enabled, ')
          ..write('installedAt: $installedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('supportedSearchTypesJson: $supportedSearchTypesJson, ')
          ..write('userVariablesJson: $userVariablesJson, ')
          ..write('userVariableValuesJson: $userVariableValuesJson, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    platform,
    version,
    author,
    description,
    sourcePath,
    enabled,
    installedAt,
    updatedAt,
    supportedSearchTypesJson,
    userVariablesJson,
    userVariableValuesJson,
    sortIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PluginDefinitionRow &&
          other.id == this.id &&
          other.platform == this.platform &&
          other.version == this.version &&
          other.author == this.author &&
          other.description == this.description &&
          other.sourcePath == this.sourcePath &&
          other.enabled == this.enabled &&
          other.installedAt == this.installedAt &&
          other.updatedAt == this.updatedAt &&
          other.supportedSearchTypesJson == this.supportedSearchTypesJson &&
          other.userVariablesJson == this.userVariablesJson &&
          other.userVariableValuesJson == this.userVariableValuesJson &&
          other.sortIndex == this.sortIndex);
}

class PluginDefinitionRowsCompanion
    extends UpdateCompanion<PluginDefinitionRow> {
  final Value<String> id;
  final Value<String> platform;
  final Value<String?> version;
  final Value<String?> author;
  final Value<String?> description;
  final Value<String> sourcePath;
  final Value<bool> enabled;
  final Value<DateTime> installedAt;
  final Value<DateTime> updatedAt;
  final Value<String> supportedSearchTypesJson;
  final Value<String> userVariablesJson;
  final Value<String> userVariableValuesJson;
  final Value<int> sortIndex;
  final Value<int> rowid;
  const PluginDefinitionRowsCompanion({
    this.id = const Value.absent(),
    this.platform = const Value.absent(),
    this.version = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.enabled = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.supportedSearchTypesJson = const Value.absent(),
    this.userVariablesJson = const Value.absent(),
    this.userVariableValuesJson = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PluginDefinitionRowsCompanion.insert({
    required String id,
    required String platform,
    this.version = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    required String sourcePath,
    this.enabled = const Value.absent(),
    required DateTime installedAt,
    required DateTime updatedAt,
    this.supportedSearchTypesJson = const Value.absent(),
    this.userVariablesJson = const Value.absent(),
    this.userVariableValuesJson = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       platform = Value(platform),
       sourcePath = Value(sourcePath),
       installedAt = Value(installedAt),
       updatedAt = Value(updatedAt);
  static Insertable<PluginDefinitionRow> custom({
    Expression<String>? id,
    Expression<String>? platform,
    Expression<String>? version,
    Expression<String>? author,
    Expression<String>? description,
    Expression<String>? sourcePath,
    Expression<bool>? enabled,
    Expression<DateTime>? installedAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? supportedSearchTypesJson,
    Expression<String>? userVariablesJson,
    Expression<String>? userVariableValuesJson,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platform != null) 'platform': platform,
      if (version != null) 'version': version,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (sourcePath != null) 'source_path': sourcePath,
      if (enabled != null) 'enabled': enabled,
      if (installedAt != null) 'installed_at': installedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (supportedSearchTypesJson != null)
        'supported_search_types_json': supportedSearchTypesJson,
      if (userVariablesJson != null) 'user_variables_json': userVariablesJson,
      if (userVariableValuesJson != null)
        'user_variable_values_json': userVariableValuesJson,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PluginDefinitionRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? platform,
    Value<String?>? version,
    Value<String?>? author,
    Value<String?>? description,
    Value<String>? sourcePath,
    Value<bool>? enabled,
    Value<DateTime>? installedAt,
    Value<DateTime>? updatedAt,
    Value<String>? supportedSearchTypesJson,
    Value<String>? userVariablesJson,
    Value<String>? userVariableValuesJson,
    Value<int>? sortIndex,
    Value<int>? rowid,
  }) {
    return PluginDefinitionRowsCompanion(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      version: version ?? this.version,
      author: author ?? this.author,
      description: description ?? this.description,
      sourcePath: sourcePath ?? this.sourcePath,
      enabled: enabled ?? this.enabled,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supportedSearchTypesJson:
          supportedSearchTypesJson ?? this.supportedSearchTypesJson,
      userVariablesJson: userVariablesJson ?? this.userVariablesJson,
      userVariableValuesJson:
          userVariableValuesJson ?? this.userVariableValuesJson,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (supportedSearchTypesJson.present) {
      map['supported_search_types_json'] = Variable<String>(
        supportedSearchTypesJson.value,
      );
    }
    if (userVariablesJson.present) {
      map['user_variables_json'] = Variable<String>(userVariablesJson.value);
    }
    if (userVariableValuesJson.present) {
      map['user_variable_values_json'] = Variable<String>(
        userVariableValuesJson.value,
      );
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PluginDefinitionRowsCompanion(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('version: $version, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('enabled: $enabled, ')
          ..write('installedAt: $installedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('supportedSearchTypesJson: $supportedSearchTypesJson, ')
          ..write('userVariablesJson: $userVariablesJson, ')
          ..write('userVariableValuesJson: $userVariableValuesJson, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioCacheEntriesTable extends AudioCacheEntries
    with TableInfo<$AudioCacheEntriesTable, AudioCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playback_items (id)',
    ),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAccessedAt =
      GeneratedColumn<DateTime>(
        'last_accessed_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    sourceUrl,
    path,
    size,
    createdAt,
    lastAccessedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  AudioCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioCacheEntry(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed_at'],
      )!,
    );
  }

  @override
  $AudioCacheEntriesTable createAlias(String alias) {
    return $AudioCacheEntriesTable(attachedDatabase, alias);
  }
}

class AudioCacheEntry extends DataClass implements Insertable<AudioCacheEntry> {
  final String itemId;
  final String sourceUrl;
  final String path;
  final int size;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  const AudioCacheEntry({
    required this.itemId,
    required this.sourceUrl,
    required this.path,
    required this.size,
    required this.createdAt,
    required this.lastAccessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['source_url'] = Variable<String>(sourceUrl);
    map['path'] = Variable<String>(path);
    map['size'] = Variable<int>(size);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt);
    return map;
  }

  AudioCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return AudioCacheEntriesCompanion(
      itemId: Value(itemId),
      sourceUrl: Value(sourceUrl),
      path: Value(path),
      size: Value(size),
      createdAt: Value(createdAt),
      lastAccessedAt: Value(lastAccessedAt),
    );
  }

  factory AudioCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioCacheEntry(
      itemId: serializer.fromJson<String>(json['itemId']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      path: serializer.fromJson<String>(json['path']),
      size: serializer.fromJson<int>(json['size']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAccessedAt: serializer.fromJson<DateTime>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'path': serializer.toJson<String>(path),
      'size': serializer.toJson<int>(size),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAccessedAt': serializer.toJson<DateTime>(lastAccessedAt),
    };
  }

  AudioCacheEntry copyWith({
    String? itemId,
    String? sourceUrl,
    String? path,
    int? size,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
  }) => AudioCacheEntry(
    itemId: itemId ?? this.itemId,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    path: path ?? this.path,
    size: size ?? this.size,
    createdAt: createdAt ?? this.createdAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  AudioCacheEntry copyWithCompanion(AudioCacheEntriesCompanion data) {
    return AudioCacheEntry(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      path: data.path.present ? data.path.value : this.path,
      size: data.size.present ? data.size.value : this.size,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheEntry(')
          ..write('itemId: $itemId, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('path: $path, ')
          ..write('size: $size, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(itemId, sourceUrl, path, size, createdAt, lastAccessedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioCacheEntry &&
          other.itemId == this.itemId &&
          other.sourceUrl == this.sourceUrl &&
          other.path == this.path &&
          other.size == this.size &&
          other.createdAt == this.createdAt &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class AudioCacheEntriesCompanion extends UpdateCompanion<AudioCacheEntry> {
  final Value<String> itemId;
  final Value<String> sourceUrl;
  final Value<String> path;
  final Value<int> size;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastAccessedAt;
  final Value<int> rowid;
  const AudioCacheEntriesCompanion({
    this.itemId = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.path = const Value.absent(),
    this.size = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioCacheEntriesCompanion.insert({
    required String itemId,
    required String sourceUrl,
    required String path,
    required int size,
    required DateTime createdAt,
    required DateTime lastAccessedAt,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       sourceUrl = Value(sourceUrl),
       path = Value(path),
       size = Value(size),
       createdAt = Value(createdAt),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<AudioCacheEntry> custom({
    Expression<String>? itemId,
    Expression<String>? sourceUrl,
    Expression<String>? path,
    Expression<int>? size,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAccessedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (path != null) 'path': path,
      if (size != null) 'size': size,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioCacheEntriesCompanion copyWith({
    Value<String>? itemId,
    Value<String>? sourceUrl,
    Value<String>? path,
    Value<int>? size,
    Value<DateTime>? createdAt,
    Value<DateTime>? lastAccessedAt,
    Value<int>? rowid,
  }) {
    return AudioCacheEntriesCompanion(
      itemId: itemId ?? this.itemId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      path: path ?? this.path,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheEntriesCompanion(')
          ..write('itemId: $itemId, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('path: $path, ')
          ..write('size: $size, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LyricPreferencesTable extends LyricPreferences
    with TableInfo<$LyricPreferencesTable, LyricPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playback_items (id)',
    ),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _associatedPathMeta = const VerificationMeta(
    'associatedPath',
  );
  @override
  late final GeneratedColumn<String> associatedPath = GeneratedColumn<String>(
    'associated_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pluginPlatformMeta = const VerificationMeta(
    'pluginPlatform',
  );
  @override
  late final GeneratedColumn<String> pluginPlatform = GeneratedColumn<String>(
    'plugin_platform',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pluginItemRawJsonMeta = const VerificationMeta(
    'pluginItemRawJson',
  );
  @override
  late final GeneratedColumn<String> pluginItemRawJson =
      GeneratedColumn<String>(
        'plugin_item_raw_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _rawLyricMeta = const VerificationMeta(
    'rawLyric',
  );
  @override
  late final GeneratedColumn<String> rawLyric = GeneratedColumn<String>(
    'raw_lyric',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offsetMsMeta = const VerificationMeta(
    'offsetMs',
  );
  @override
  late final GeneratedColumn<int> offsetMs = GeneratedColumn<int>(
    'offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    sourceType,
    associatedPath,
    pluginPlatform,
    pluginItemRawJson,
    rawLyric,
    offsetMs,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyric_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('associated_path')) {
      context.handle(
        _associatedPathMeta,
        associatedPath.isAcceptableOrUnknown(
          data['associated_path']!,
          _associatedPathMeta,
        ),
      );
    }
    if (data.containsKey('plugin_platform')) {
      context.handle(
        _pluginPlatformMeta,
        pluginPlatform.isAcceptableOrUnknown(
          data['plugin_platform']!,
          _pluginPlatformMeta,
        ),
      );
    }
    if (data.containsKey('plugin_item_raw_json')) {
      context.handle(
        _pluginItemRawJsonMeta,
        pluginItemRawJson.isAcceptableOrUnknown(
          data['plugin_item_raw_json']!,
          _pluginItemRawJsonMeta,
        ),
      );
    }
    if (data.containsKey('raw_lyric')) {
      context.handle(
        _rawLyricMeta,
        rawLyric.isAcceptableOrUnknown(data['raw_lyric']!, _rawLyricMeta),
      );
    }
    if (data.containsKey('offset_ms')) {
      context.handle(
        _offsetMsMeta,
        offsetMs.isAcceptableOrUnknown(data['offset_ms']!, _offsetMsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  LyricPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricPreference(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      ),
      associatedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}associated_path'],
      ),
      pluginPlatform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_platform'],
      ),
      pluginItemRawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_item_raw_json'],
      ),
      rawLyric: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_lyric'],
      ),
      offsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_ms'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LyricPreferencesTable createAlias(String alias) {
    return $LyricPreferencesTable(attachedDatabase, alias);
  }
}

class LyricPreference extends DataClass implements Insertable<LyricPreference> {
  final String itemId;
  final String? sourceType;
  final String? associatedPath;
  final String? pluginPlatform;
  final String? pluginItemRawJson;
  final String? rawLyric;
  final int offsetMs;
  final DateTime updatedAt;
  const LyricPreference({
    required this.itemId,
    this.sourceType,
    this.associatedPath,
    this.pluginPlatform,
    this.pluginItemRawJson,
    this.rawLyric,
    required this.offsetMs,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || sourceType != null) {
      map['source_type'] = Variable<String>(sourceType);
    }
    if (!nullToAbsent || associatedPath != null) {
      map['associated_path'] = Variable<String>(associatedPath);
    }
    if (!nullToAbsent || pluginPlatform != null) {
      map['plugin_platform'] = Variable<String>(pluginPlatform);
    }
    if (!nullToAbsent || pluginItemRawJson != null) {
      map['plugin_item_raw_json'] = Variable<String>(pluginItemRawJson);
    }
    if (!nullToAbsent || rawLyric != null) {
      map['raw_lyric'] = Variable<String>(rawLyric);
    }
    map['offset_ms'] = Variable<int>(offsetMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LyricPreferencesCompanion toCompanion(bool nullToAbsent) {
    return LyricPreferencesCompanion(
      itemId: Value(itemId),
      sourceType: sourceType == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceType),
      associatedPath: associatedPath == null && nullToAbsent
          ? const Value.absent()
          : Value(associatedPath),
      pluginPlatform: pluginPlatform == null && nullToAbsent
          ? const Value.absent()
          : Value(pluginPlatform),
      pluginItemRawJson: pluginItemRawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(pluginItemRawJson),
      rawLyric: rawLyric == null && nullToAbsent
          ? const Value.absent()
          : Value(rawLyric),
      offsetMs: Value(offsetMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory LyricPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricPreference(
      itemId: serializer.fromJson<String>(json['itemId']),
      sourceType: serializer.fromJson<String?>(json['sourceType']),
      associatedPath: serializer.fromJson<String?>(json['associatedPath']),
      pluginPlatform: serializer.fromJson<String?>(json['pluginPlatform']),
      pluginItemRawJson: serializer.fromJson<String?>(
        json['pluginItemRawJson'],
      ),
      rawLyric: serializer.fromJson<String?>(json['rawLyric']),
      offsetMs: serializer.fromJson<int>(json['offsetMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'sourceType': serializer.toJson<String?>(sourceType),
      'associatedPath': serializer.toJson<String?>(associatedPath),
      'pluginPlatform': serializer.toJson<String?>(pluginPlatform),
      'pluginItemRawJson': serializer.toJson<String?>(pluginItemRawJson),
      'rawLyric': serializer.toJson<String?>(rawLyric),
      'offsetMs': serializer.toJson<int>(offsetMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LyricPreference copyWith({
    String? itemId,
    Value<String?> sourceType = const Value.absent(),
    Value<String?> associatedPath = const Value.absent(),
    Value<String?> pluginPlatform = const Value.absent(),
    Value<String?> pluginItemRawJson = const Value.absent(),
    Value<String?> rawLyric = const Value.absent(),
    int? offsetMs,
    DateTime? updatedAt,
  }) => LyricPreference(
    itemId: itemId ?? this.itemId,
    sourceType: sourceType.present ? sourceType.value : this.sourceType,
    associatedPath: associatedPath.present
        ? associatedPath.value
        : this.associatedPath,
    pluginPlatform: pluginPlatform.present
        ? pluginPlatform.value
        : this.pluginPlatform,
    pluginItemRawJson: pluginItemRawJson.present
        ? pluginItemRawJson.value
        : this.pluginItemRawJson,
    rawLyric: rawLyric.present ? rawLyric.value : this.rawLyric,
    offsetMs: offsetMs ?? this.offsetMs,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LyricPreference copyWithCompanion(LyricPreferencesCompanion data) {
    return LyricPreference(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      associatedPath: data.associatedPath.present
          ? data.associatedPath.value
          : this.associatedPath,
      pluginPlatform: data.pluginPlatform.present
          ? data.pluginPlatform.value
          : this.pluginPlatform,
      pluginItemRawJson: data.pluginItemRawJson.present
          ? data.pluginItemRawJson.value
          : this.pluginItemRawJson,
      rawLyric: data.rawLyric.present ? data.rawLyric.value : this.rawLyric,
      offsetMs: data.offsetMs.present ? data.offsetMs.value : this.offsetMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricPreference(')
          ..write('itemId: $itemId, ')
          ..write('sourceType: $sourceType, ')
          ..write('associatedPath: $associatedPath, ')
          ..write('pluginPlatform: $pluginPlatform, ')
          ..write('pluginItemRawJson: $pluginItemRawJson, ')
          ..write('rawLyric: $rawLyric, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    itemId,
    sourceType,
    associatedPath,
    pluginPlatform,
    pluginItemRawJson,
    rawLyric,
    offsetMs,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricPreference &&
          other.itemId == this.itemId &&
          other.sourceType == this.sourceType &&
          other.associatedPath == this.associatedPath &&
          other.pluginPlatform == this.pluginPlatform &&
          other.pluginItemRawJson == this.pluginItemRawJson &&
          other.rawLyric == this.rawLyric &&
          other.offsetMs == this.offsetMs &&
          other.updatedAt == this.updatedAt);
}

class LyricPreferencesCompanion extends UpdateCompanion<LyricPreference> {
  final Value<String> itemId;
  final Value<String?> sourceType;
  final Value<String?> associatedPath;
  final Value<String?> pluginPlatform;
  final Value<String?> pluginItemRawJson;
  final Value<String?> rawLyric;
  final Value<int> offsetMs;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LyricPreferencesCompanion({
    this.itemId = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.associatedPath = const Value.absent(),
    this.pluginPlatform = const Value.absent(),
    this.pluginItemRawJson = const Value.absent(),
    this.rawLyric = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LyricPreferencesCompanion.insert({
    required String itemId,
    this.sourceType = const Value.absent(),
    this.associatedPath = const Value.absent(),
    this.pluginPlatform = const Value.absent(),
    this.pluginItemRawJson = const Value.absent(),
    this.rawLyric = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId);
  static Insertable<LyricPreference> custom({
    Expression<String>? itemId,
    Expression<String>? sourceType,
    Expression<String>? associatedPath,
    Expression<String>? pluginPlatform,
    Expression<String>? pluginItemRawJson,
    Expression<String>? rawLyric,
    Expression<int>? offsetMs,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (sourceType != null) 'source_type': sourceType,
      if (associatedPath != null) 'associated_path': associatedPath,
      if (pluginPlatform != null) 'plugin_platform': pluginPlatform,
      if (pluginItemRawJson != null) 'plugin_item_raw_json': pluginItemRawJson,
      if (rawLyric != null) 'raw_lyric': rawLyric,
      if (offsetMs != null) 'offset_ms': offsetMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LyricPreferencesCompanion copyWith({
    Value<String>? itemId,
    Value<String?>? sourceType,
    Value<String?>? associatedPath,
    Value<String?>? pluginPlatform,
    Value<String?>? pluginItemRawJson,
    Value<String?>? rawLyric,
    Value<int>? offsetMs,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LyricPreferencesCompanion(
      itemId: itemId ?? this.itemId,
      sourceType: sourceType ?? this.sourceType,
      associatedPath: associatedPath ?? this.associatedPath,
      pluginPlatform: pluginPlatform ?? this.pluginPlatform,
      pluginItemRawJson: pluginItemRawJson ?? this.pluginItemRawJson,
      rawLyric: rawLyric ?? this.rawLyric,
      offsetMs: offsetMs ?? this.offsetMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (associatedPath.present) {
      map['associated_path'] = Variable<String>(associatedPath.value);
    }
    if (pluginPlatform.present) {
      map['plugin_platform'] = Variable<String>(pluginPlatform.value);
    }
    if (pluginItemRawJson.present) {
      map['plugin_item_raw_json'] = Variable<String>(pluginItemRawJson.value);
    }
    if (rawLyric.present) {
      map['raw_lyric'] = Variable<String>(rawLyric.value);
    }
    if (offsetMs.present) {
      map['offset_ms'] = Variable<int>(offsetMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricPreferencesCompanion(')
          ..write('itemId: $itemId, ')
          ..write('sourceType: $sourceType, ')
          ..write('associatedPath: $associatedPath, ')
          ..write('pluginPlatform: $pluginPlatform, ')
          ..write('pluginItemRawJson: $pluginItemRawJson, ')
          ..write('rawLyric: $rawLyric, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFavoritesMeta = const VerificationMeta(
    'isFavorites',
  );
  @override
  late final GeneratedColumn<bool> isFavorites = GeneratedColumn<bool>(
    'is_favorites',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorites" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isFavorites,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_favorites')) {
      context.handle(
        _isFavoritesMeta,
        isFavorites.isAcceptableOrUnknown(
          data['is_favorites']!,
          _isFavoritesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isFavorites: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorites'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final String id;
  final String name;
  final bool isFavorites;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Playlist({
    required this.id,
    required this.name,
    required this.isFavorites,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['is_favorites'] = Variable<bool>(isFavorites);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      isFavorites: Value(isFavorites),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isFavorites: serializer.fromJson<bool>(json['isFavorites']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'isFavorites': serializer.toJson<bool>(isFavorites),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Playlist copyWith({
    String? id,
    String? name,
    bool? isFavorites,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    isFavorites: isFavorites ?? this.isFavorites,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isFavorites: data.isFavorites.present
          ? data.isFavorites.value
          : this.isFavorites,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isFavorites: $isFavorites, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, isFavorites, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.isFavorites == this.isFavorites &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<String> id;
  final Value<String> name;
  final Value<bool> isFavorites;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isFavorites = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    required String id,
    required String name,
    this.isFavorites = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Playlist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<bool>? isFavorites,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isFavorites != null) 'is_favorites': isFavorites,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<bool>? isFavorites,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isFavorites: isFavorites ?? this.isFavorites,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isFavorites.present) {
      map['is_favorites'] = Variable<bool>(isFavorites.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isFavorites: $isFavorites, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistItemsTable extends PlaylistItems
    with TableInfo<$PlaylistItemsTable, PlaylistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id)',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playback_items (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [playlistId, itemId, position, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, itemId};
  @override
  PlaylistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistItem(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $PlaylistItemsTable createAlias(String alias) {
    return $PlaylistItemsTable(attachedDatabase, alias);
  }
}

class PlaylistItem extends DataClass implements Insertable<PlaylistItem> {
  final String playlistId;
  final String itemId;
  final int position;
  final DateTime addedAt;
  const PlaylistItem({
    required this.playlistId,
    required this.itemId,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['item_id'] = Variable<String>(itemId);
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  PlaylistItemsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistItemsCompanion(
      playlistId: Value(playlistId),
      itemId: Value(itemId),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory PlaylistItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistItem(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'itemId': serializer.toJson<String>(itemId),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  PlaylistItem copyWith({
    String? playlistId,
    String? itemId,
    int? position,
    DateTime? addedAt,
  }) => PlaylistItem(
    playlistId: playlistId ?? this.playlistId,
    itemId: itemId ?? this.itemId,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
  );
  PlaylistItem copyWithCompanion(PlaylistItemsCompanion data) {
    return PlaylistItem(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistItem(')
          ..write('playlistId: $playlistId, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, itemId, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistItem &&
          other.playlistId == this.playlistId &&
          other.itemId == this.itemId &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class PlaylistItemsCompanion extends UpdateCompanion<PlaylistItem> {
  final Value<String> playlistId;
  final Value<String> itemId;
  final Value<int> position;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const PlaylistItemsCompanion({
    this.playlistId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistItemsCompanion.insert({
    required String playlistId,
    required String itemId,
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       itemId = Value(itemId);
  static Insertable<PlaylistItem> custom({
    Expression<String>? playlistId,
    Expression<String>? itemId,
    Expression<int>? position,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (itemId != null) 'item_id': itemId,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistItemsCompanion copyWith({
    Value<String>? playlistId,
    Value<String>? itemId,
    Value<int>? position,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return PlaylistItemsCompanion(
      playlistId: playlistId ?? this.playlistId,
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistItemsCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadTasksTable extends DownloadTasks
    with TableInfo<$DownloadTasksTable, DownloadTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playback_items (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    status,
    progress,
    sourceUrl,
    filePath,
    errorMessage,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadTasksTable createAlias(String alias) {
    return $DownloadTasksTable(attachedDatabase, alias);
  }
}

class DownloadTask extends DataClass implements Insertable<DownloadTask> {
  final String id;
  final String itemId;
  final String status;
  final double progress;
  final String? sourceUrl;
  final String? filePath;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  const DownloadTask({
    required this.id,
    required this.itemId,
    required this.status,
    required this.progress,
    this.sourceUrl,
    this.filePath,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return DownloadTasksCompanion(
      id: Value(id),
      itemId: Value(itemId),
      status: Value(status),
      progress: Value(progress),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory DownloadTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadTask(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<double>(json['progress']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<double>(progress),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'filePath': serializer.toJson<String?>(filePath),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  DownloadTask copyWith({
    String? id,
    String? itemId,
    String? status,
    double? progress,
    Value<String?> sourceUrl = const Value.absent(),
    Value<String?> filePath = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => DownloadTask(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
    filePath: filePath.present ? filePath.value : this.filePath,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  DownloadTask copyWithCompanion(DownloadTasksCompanion data) {
    return DownloadTask(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTask(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('filePath: $filePath, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    status,
    progress,
    sourceUrl,
    filePath,
    errorMessage,
    createdAt,
    updatedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadTask &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.sourceUrl == this.sourceUrl &&
          other.filePath == this.filePath &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class DownloadTasksCompanion extends UpdateCompanion<DownloadTask> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> status;
  final Value<double> progress;
  final Value<String?> sourceUrl;
  final Value<String?> filePath;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const DownloadTasksCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.filePath = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadTasksCompanion.insert({
    required String id,
    required String itemId,
    required String status,
    this.progress = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.filePath = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       status = Value(status);
  static Insertable<DownloadTask> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? status,
    Expression<double>? progress,
    Expression<String>? sourceUrl,
    Expression<String>? filePath,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (filePath != null) 'file_path': filePath,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? status,
    Value<double>? progress,
    Value<String?>? sourceUrl,
    Value<String?>? filePath,
    Value<String?>? errorMessage,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return DownloadTasksCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadTasksCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('filePath: $filePath, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteCollectionsTable extends FavoriteCollections
    with TableInfo<$FavoriteCollectionsTable, FavoriteCollection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionKeyMeta = const VerificationMeta(
    'collectionKey',
  );
  @override
  late final GeneratedColumn<String> collectionKey = GeneratedColumn<String>(
    'collection_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artworkUrlMeta = const VerificationMeta(
    'artworkUrl',
  );
  @override
  late final GeneratedColumn<String> artworkUrl = GeneratedColumn<String>(
    'artwork_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    collectionKey,
    pluginId,
    platform,
    kind,
    collectionId,
    title,
    description,
    artworkUrl,
    rawJson,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteCollection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_key')) {
      context.handle(
        _collectionKeyMeta,
        collectionKey.isAcceptableOrUnknown(
          data['collection_key']!,
          _collectionKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionKeyMeta);
    }
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginIdMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('artwork_url')) {
      context.handle(
        _artworkUrlMeta,
        artworkUrl.isAcceptableOrUnknown(data['artwork_url']!, _artworkUrlMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionKey};
  @override
  FavoriteCollection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteCollection(
      collectionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_key'],
      )!,
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      artworkUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_url'],
      ),
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $FavoriteCollectionsTable createAlias(String alias) {
    return $FavoriteCollectionsTable(attachedDatabase, alias);
  }
}

class FavoriteCollection extends DataClass
    implements Insertable<FavoriteCollection> {
  /// `OnlineCollectionItem.uniqueKey`: `<pluginId>:<kind>:<id>`.
  final String collectionKey;
  final String pluginId;
  final String platform;

  /// `OnlineCollectionKind.name`, so a ranking and a sheet never collide.
  final String kind;
  final String collectionId;
  final String title;
  final String? description;
  final String? artworkUrl;

  /// The plugin payload, kept verbatim so the detail can be re-fetched.
  final String rawJson;
  final DateTime addedAt;
  const FavoriteCollection({
    required this.collectionKey,
    required this.pluginId,
    required this.platform,
    required this.kind,
    required this.collectionId,
    required this.title,
    this.description,
    this.artworkUrl,
    required this.rawJson,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_key'] = Variable<String>(collectionKey);
    map['plugin_id'] = Variable<String>(pluginId);
    map['platform'] = Variable<String>(platform);
    map['kind'] = Variable<String>(kind);
    map['collection_id'] = Variable<String>(collectionId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || artworkUrl != null) {
      map['artwork_url'] = Variable<String>(artworkUrl);
    }
    map['raw_json'] = Variable<String>(rawJson);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoriteCollectionsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteCollectionsCompanion(
      collectionKey: Value(collectionKey),
      pluginId: Value(pluginId),
      platform: Value(platform),
      kind: Value(kind),
      collectionId: Value(collectionId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      artworkUrl: artworkUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkUrl),
      rawJson: Value(rawJson),
      addedAt: Value(addedAt),
    );
  }

  factory FavoriteCollection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteCollection(
      collectionKey: serializer.fromJson<String>(json['collectionKey']),
      pluginId: serializer.fromJson<String>(json['pluginId']),
      platform: serializer.fromJson<String>(json['platform']),
      kind: serializer.fromJson<String>(json['kind']),
      collectionId: serializer.fromJson<String>(json['collectionId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      artworkUrl: serializer.fromJson<String?>(json['artworkUrl']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionKey': serializer.toJson<String>(collectionKey),
      'pluginId': serializer.toJson<String>(pluginId),
      'platform': serializer.toJson<String>(platform),
      'kind': serializer.toJson<String>(kind),
      'collectionId': serializer.toJson<String>(collectionId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'artworkUrl': serializer.toJson<String?>(artworkUrl),
      'rawJson': serializer.toJson<String>(rawJson),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  FavoriteCollection copyWith({
    String? collectionKey,
    String? pluginId,
    String? platform,
    String? kind,
    String? collectionId,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> artworkUrl = const Value.absent(),
    String? rawJson,
    DateTime? addedAt,
  }) => FavoriteCollection(
    collectionKey: collectionKey ?? this.collectionKey,
    pluginId: pluginId ?? this.pluginId,
    platform: platform ?? this.platform,
    kind: kind ?? this.kind,
    collectionId: collectionId ?? this.collectionId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    artworkUrl: artworkUrl.present ? artworkUrl.value : this.artworkUrl,
    rawJson: rawJson ?? this.rawJson,
    addedAt: addedAt ?? this.addedAt,
  );
  FavoriteCollection copyWithCompanion(FavoriteCollectionsCompanion data) {
    return FavoriteCollection(
      collectionKey: data.collectionKey.present
          ? data.collectionKey.value
          : this.collectionKey,
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      platform: data.platform.present ? data.platform.value : this.platform,
      kind: data.kind.present ? data.kind.value : this.kind,
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      artworkUrl: data.artworkUrl.present
          ? data.artworkUrl.value
          : this.artworkUrl,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteCollection(')
          ..write('collectionKey: $collectionKey, ')
          ..write('pluginId: $pluginId, ')
          ..write('platform: $platform, ')
          ..write('kind: $kind, ')
          ..write('collectionId: $collectionId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('rawJson: $rawJson, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    collectionKey,
    pluginId,
    platform,
    kind,
    collectionId,
    title,
    description,
    artworkUrl,
    rawJson,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteCollection &&
          other.collectionKey == this.collectionKey &&
          other.pluginId == this.pluginId &&
          other.platform == this.platform &&
          other.kind == this.kind &&
          other.collectionId == this.collectionId &&
          other.title == this.title &&
          other.description == this.description &&
          other.artworkUrl == this.artworkUrl &&
          other.rawJson == this.rawJson &&
          other.addedAt == this.addedAt);
}

class FavoriteCollectionsCompanion extends UpdateCompanion<FavoriteCollection> {
  final Value<String> collectionKey;
  final Value<String> pluginId;
  final Value<String> platform;
  final Value<String> kind;
  final Value<String> collectionId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> artworkUrl;
  final Value<String> rawJson;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoriteCollectionsCompanion({
    this.collectionKey = const Value.absent(),
    this.pluginId = const Value.absent(),
    this.platform = const Value.absent(),
    this.kind = const Value.absent(),
    this.collectionId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteCollectionsCompanion.insert({
    required String collectionKey,
    required String pluginId,
    required String platform,
    required String kind,
    required String collectionId,
    required String title,
    this.description = const Value.absent(),
    this.artworkUrl = const Value.absent(),
    required String rawJson,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : collectionKey = Value(collectionKey),
       pluginId = Value(pluginId),
       platform = Value(platform),
       kind = Value(kind),
       collectionId = Value(collectionId),
       title = Value(title),
       rawJson = Value(rawJson);
  static Insertable<FavoriteCollection> custom({
    Expression<String>? collectionKey,
    Expression<String>? pluginId,
    Expression<String>? platform,
    Expression<String>? kind,
    Expression<String>? collectionId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? artworkUrl,
    Expression<String>? rawJson,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionKey != null) 'collection_key': collectionKey,
      if (pluginId != null) 'plugin_id': pluginId,
      if (platform != null) 'platform': platform,
      if (kind != null) 'kind': kind,
      if (collectionId != null) 'collection_id': collectionId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (artworkUrl != null) 'artwork_url': artworkUrl,
      if (rawJson != null) 'raw_json': rawJson,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteCollectionsCompanion copyWith({
    Value<String>? collectionKey,
    Value<String>? pluginId,
    Value<String>? platform,
    Value<String>? kind,
    Value<String>? collectionId,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? artworkUrl,
    Value<String>? rawJson,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return FavoriteCollectionsCompanion(
      collectionKey: collectionKey ?? this.collectionKey,
      pluginId: pluginId ?? this.pluginId,
      platform: platform ?? this.platform,
      kind: kind ?? this.kind,
      collectionId: collectionId ?? this.collectionId,
      title: title ?? this.title,
      description: description ?? this.description,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      rawJson: rawJson ?? this.rawJson,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionKey.present) {
      map['collection_key'] = Variable<String>(collectionKey.value);
    }
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (artworkUrl.present) {
      map['artwork_url'] = Variable<String>(artworkUrl.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteCollectionsCompanion(')
          ..write('collectionKey: $collectionKey, ')
          ..write('pluginId: $pluginId, ')
          ..write('platform: $platform, ')
          ..write('kind: $kind, ')
          ..write('collectionId: $collectionId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('artworkUrl: $artworkUrl, ')
          ..write('rawJson: $rawJson, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlaybackItemsTable playbackItems = $PlaybackItemsTable(this);
  late final $PlayerStateRowsTable playerStateRows = $PlayerStateRowsTable(
    this,
  );
  late final $QueueEntriesTable queueEntries = $QueueEntriesTable(this);
  late final $PlaybackHistoryRowsTable playbackHistoryRows =
      $PlaybackHistoryRowsTable(this);
  late final $LocalLibraryTracksTable localLibraryTracks =
      $LocalLibraryTracksTable(this);
  late final $PluginDefinitionRowsTable pluginDefinitionRows =
      $PluginDefinitionRowsTable(this);
  late final $AudioCacheEntriesTable audioCacheEntries =
      $AudioCacheEntriesTable(this);
  late final $LyricPreferencesTable lyricPreferences = $LyricPreferencesTable(
    this,
  );
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistItemsTable playlistItems = $PlaylistItemsTable(this);
  late final $DownloadTasksTable downloadTasks = $DownloadTasksTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $FavoriteCollectionsTable favoriteCollections =
      $FavoriteCollectionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    playbackItems,
    playerStateRows,
    queueEntries,
    playbackHistoryRows,
    localLibraryTracks,
    pluginDefinitionRows,
    audioCacheEntries,
    lyricPreferences,
    playlists,
    playlistItems,
    downloadTasks,
    appSettings,
    favoriteCollections,
  ];
}

typedef $$PlaybackItemsTableCreateCompanionBuilder =
    PlaybackItemsCompanion Function({
      required String id,
      required String type,
      required String title,
      Value<String?> platform,
      Value<String?> musicId,
      Value<String?> localPath,
      Value<String?> artist,
      Value<String?> album,
      Value<int?> durationMs,
      Value<String?> artworkUrl,
      Value<String> rawJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PlaybackItemsTableUpdateCompanionBuilder =
    PlaybackItemsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> title,
      Value<String?> platform,
      Value<String?> musicId,
      Value<String?> localPath,
      Value<String?> artist,
      Value<String?> album,
      Value<int?> durationMs,
      Value<String?> artworkUrl,
      Value<String> rawJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PlaybackItemsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaybackItemsTable, PlaybackItem> {
  $$PlaybackItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$PlayerStateRowsTable, List<PlayerStateRow>>
  _playerStateRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playerStateRows,
    aliasName: $_aliasNameGenerator(
      db.playbackItems.id,
      db.playerStateRows.currentItemId,
    ),
  );

  $$PlayerStateRowsTableProcessedTableManager get playerStateRowsRefs {
    final manager = $$PlayerStateRowsTableTableManager(
      $_db,
      $_db.playerStateRows,
    ).filter((f) => f.currentItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playerStateRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$QueueEntriesTable, List<QueueEntry>>
  _queueEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.queueEntries,
    aliasName: $_aliasNameGenerator(
      db.playbackItems.id,
      db.queueEntries.itemId,
    ),
  );

  $$QueueEntriesTableProcessedTableManager get queueEntriesRefs {
    final manager = $$QueueEntriesTableTableManager(
      $_db,
      $_db.queueEntries,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_queueEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PlaybackHistoryRowsTable,
    List<PlaybackHistoryRow>
  >
  _playbackHistoryRowsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playbackHistoryRows,
        aliasName: $_aliasNameGenerator(
          db.playbackItems.id,
          db.playbackHistoryRows.itemId,
        ),
      );

  $$PlaybackHistoryRowsTableProcessedTableManager get playbackHistoryRowsRefs {
    final manager = $$PlaybackHistoryRowsTableTableManager(
      $_db,
      $_db.playbackHistoryRows,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playbackHistoryRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocalLibraryTracksTable, List<LocalLibraryTrack>>
  _localLibraryTracksRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localLibraryTracks,
        aliasName: $_aliasNameGenerator(
          db.playbackItems.id,
          db.localLibraryTracks.itemId,
        ),
      );

  $$LocalLibraryTracksTableProcessedTableManager get localLibraryTracksRefs {
    final manager = $$LocalLibraryTracksTableTableManager(
      $_db,
      $_db.localLibraryTracks,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localLibraryTracksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AudioCacheEntriesTable, List<AudioCacheEntry>>
  _audioCacheEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.audioCacheEntries,
        aliasName: $_aliasNameGenerator(
          db.playbackItems.id,
          db.audioCacheEntries.itemId,
        ),
      );

  $$AudioCacheEntriesTableProcessedTableManager get audioCacheEntriesRefs {
    final manager = $$AudioCacheEntriesTableTableManager(
      $_db,
      $_db.audioCacheEntries,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _audioCacheEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LyricPreferencesTable, List<LyricPreference>>
  _lyricPreferencesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.lyricPreferences,
    aliasName: $_aliasNameGenerator(
      db.playbackItems.id,
      db.lyricPreferences.itemId,
    ),
  );

  $$LyricPreferencesTableProcessedTableManager get lyricPreferencesRefs {
    final manager = $$LyricPreferencesTableTableManager(
      $_db,
      $_db.lyricPreferences,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _lyricPreferencesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlaylistItemsTable, List<PlaylistItem>>
  _playlistItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistItems,
    aliasName: $_aliasNameGenerator(
      db.playbackItems.id,
      db.playlistItems.itemId,
    ),
  );

  $$PlaylistItemsTableProcessedTableManager get playlistItemsRefs {
    final manager = $$PlaylistItemsTableTableManager(
      $_db,
      $_db.playlistItems,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DownloadTasksTable, List<DownloadTask>>
  _downloadTasksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloadTasks,
    aliasName: $_aliasNameGenerator(
      db.playbackItems.id,
      db.downloadTasks.itemId,
    ),
  );

  $$DownloadTasksTableProcessedTableManager get downloadTasksRefs {
    final manager = $$DownloadTasksTableTableManager(
      $_db,
      $_db.downloadTasks,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_downloadTasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaybackItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackItemsTable> {
  $$PlaybackItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get musicId => $composableBuilder(
    column: $table.musicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playerStateRowsRefs(
    Expression<bool> Function($$PlayerStateRowsTableFilterComposer f) f,
  ) {
    final $$PlayerStateRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playerStateRows,
      getReferencedColumn: (t) => t.currentItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayerStateRowsTableFilterComposer(
            $db: $db,
            $table: $db.playerStateRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> queueEntriesRefs(
    Expression<bool> Function($$QueueEntriesTableFilterComposer f) f,
  ) {
    final $$QueueEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.queueEntries,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QueueEntriesTableFilterComposer(
            $db: $db,
            $table: $db.queueEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playbackHistoryRowsRefs(
    Expression<bool> Function($$PlaybackHistoryRowsTableFilterComposer f) f,
  ) {
    final $$PlaybackHistoryRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playbackHistoryRows,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackHistoryRowsTableFilterComposer(
            $db: $db,
            $table: $db.playbackHistoryRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localLibraryTracksRefs(
    Expression<bool> Function($$LocalLibraryTracksTableFilterComposer f) f,
  ) {
    final $$LocalLibraryTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localLibraryTracks,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLibraryTracksTableFilterComposer(
            $db: $db,
            $table: $db.localLibraryTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> audioCacheEntriesRefs(
    Expression<bool> Function($$AudioCacheEntriesTableFilterComposer f) f,
  ) {
    final $$AudioCacheEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioCacheEntries,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioCacheEntriesTableFilterComposer(
            $db: $db,
            $table: $db.audioCacheEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> lyricPreferencesRefs(
    Expression<bool> Function($$LyricPreferencesTableFilterComposer f) f,
  ) {
    final $$LyricPreferencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lyricPreferences,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricPreferencesTableFilterComposer(
            $db: $db,
            $table: $db.lyricPreferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playlistItemsRefs(
    Expression<bool> Function($$PlaylistItemsTableFilterComposer f) f,
  ) {
    final $$PlaylistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistItems,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistItemsTableFilterComposer(
            $db: $db,
            $table: $db.playlistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> downloadTasksRefs(
    Expression<bool> Function($$DownloadTasksTableFilterComposer f) f,
  ) {
    final $$DownloadTasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloadTasks,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadTasksTableFilterComposer(
            $db: $db,
            $table: $db.downloadTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaybackItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackItemsTable> {
  $$PlaybackItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get musicId => $composableBuilder(
    column: $table.musicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaybackItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackItemsTable> {
  $$PlaybackItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get musicId =>
      $composableBuilder(column: $table.musicId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> playerStateRowsRefs<T extends Object>(
    Expression<T> Function($$PlayerStateRowsTableAnnotationComposer a) f,
  ) {
    final $$PlayerStateRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playerStateRows,
      getReferencedColumn: (t) => t.currentItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayerStateRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.playerStateRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> queueEntriesRefs<T extends Object>(
    Expression<T> Function($$QueueEntriesTableAnnotationComposer a) f,
  ) {
    final $$QueueEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.queueEntries,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QueueEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.queueEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playbackHistoryRowsRefs<T extends Object>(
    Expression<T> Function($$PlaybackHistoryRowsTableAnnotationComposer a) f,
  ) {
    final $$PlaybackHistoryRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playbackHistoryRows,
          getReferencedColumn: (t) => t.itemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlaybackHistoryRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.playbackHistoryRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> localLibraryTracksRefs<T extends Object>(
    Expression<T> Function($$LocalLibraryTracksTableAnnotationComposer a) f,
  ) {
    final $$LocalLibraryTracksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.localLibraryTracks,
          getReferencedColumn: (t) => t.itemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalLibraryTracksTableAnnotationComposer(
                $db: $db,
                $table: $db.localLibraryTracks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> audioCacheEntriesRefs<T extends Object>(
    Expression<T> Function($$AudioCacheEntriesTableAnnotationComposer a) f,
  ) {
    final $$AudioCacheEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.audioCacheEntries,
          getReferencedColumn: (t) => t.itemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AudioCacheEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.audioCacheEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> lyricPreferencesRefs<T extends Object>(
    Expression<T> Function($$LyricPreferencesTableAnnotationComposer a) f,
  ) {
    final $$LyricPreferencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lyricPreferences,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricPreferencesTableAnnotationComposer(
            $db: $db,
            $table: $db.lyricPreferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playlistItemsRefs<T extends Object>(
    Expression<T> Function($$PlaylistItemsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistItems,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> downloadTasksRefs<T extends Object>(
    Expression<T> Function($$DownloadTasksTableAnnotationComposer a) f,
  ) {
    final $$DownloadTasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloadTasks,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadTasksTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaybackItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackItemsTable,
          PlaybackItem,
          $$PlaybackItemsTableFilterComposer,
          $$PlaybackItemsTableOrderingComposer,
          $$PlaybackItemsTableAnnotationComposer,
          $$PlaybackItemsTableCreateCompanionBuilder,
          $$PlaybackItemsTableUpdateCompanionBuilder,
          (PlaybackItem, $$PlaybackItemsTableReferences),
          PlaybackItem,
          PrefetchHooks Function({
            bool playerStateRowsRefs,
            bool queueEntriesRefs,
            bool playbackHistoryRowsRefs,
            bool localLibraryTracksRefs,
            bool audioCacheEntriesRefs,
            bool lyricPreferencesRefs,
            bool playlistItemsRefs,
            bool downloadTasksRefs,
          })
        > {
  $$PlaybackItemsTableTableManager(_$AppDatabase db, $PlaybackItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> platform = const Value.absent(),
                Value<String?> musicId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackItemsCompanion(
                id: id,
                type: type,
                title: title,
                platform: platform,
                musicId: musicId,
                localPath: localPath,
                artist: artist,
                album: album,
                durationMs: durationMs,
                artworkUrl: artworkUrl,
                rawJson: rawJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String title,
                Value<String?> platform = const Value.absent(),
                Value<String?> musicId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackItemsCompanion.insert(
                id: id,
                type: type,
                title: title,
                platform: platform,
                musicId: musicId,
                localPath: localPath,
                artist: artist,
                album: album,
                durationMs: durationMs,
                artworkUrl: artworkUrl,
                rawJson: rawJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaybackItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                playerStateRowsRefs = false,
                queueEntriesRefs = false,
                playbackHistoryRowsRefs = false,
                localLibraryTracksRefs = false,
                audioCacheEntriesRefs = false,
                lyricPreferencesRefs = false,
                playlistItemsRefs = false,
                downloadTasksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playerStateRowsRefs) db.playerStateRows,
                    if (queueEntriesRefs) db.queueEntries,
                    if (playbackHistoryRowsRefs) db.playbackHistoryRows,
                    if (localLibraryTracksRefs) db.localLibraryTracks,
                    if (audioCacheEntriesRefs) db.audioCacheEntries,
                    if (lyricPreferencesRefs) db.lyricPreferences,
                    if (playlistItemsRefs) db.playlistItems,
                    if (downloadTasksRefs) db.downloadTasks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playerStateRowsRefs)
                        await $_getPrefetchedData<
                          PlaybackItem,
                          $PlaybackItemsTable,
                          PlayerStateRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaybackItemsTableReferences
                              ._playerStateRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaybackItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).playerStateRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.currentItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (queueEntriesRefs)
                        await $_getPrefetchedData<
                          PlaybackItem,
                          $PlaybackItemsTable,
                          QueueEntry
                        >(
                          currentTable: table,
                          referencedTable: $$PlaybackItemsTableReferences
                              ._queueEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaybackItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).queueEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playbackHistoryRowsRefs)
                        await $_getPrefetchedData<
                          PlaybackItem,
                          $PlaybackItemsTable,
                          PlaybackHistoryRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlaybackItemsTableReferences
                              ._playbackHistoryRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaybackItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).playbackHistoryRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (localLibraryTracksRefs)
                        await $_getPrefetchedData<
                          PlaybackItem,
                          $PlaybackItemsTable,
                          LocalLibraryTrack
                        >(
                          currentTable: table,
                          referencedTable: $$PlaybackItemsTableReferences
                              ._localLibraryTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaybackItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).localLibraryTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (audioCacheEntriesRefs)
                        await $_getPrefetchedData<
                          PlaybackItem,
                          $PlaybackItemsTable,
                          AudioCacheEntry
                        >(
                          currentTable: table,
                          referencedTable: $$PlaybackItemsTableReferences
                              ._audioCacheEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaybackItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).audioCacheEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (lyricPreferencesRefs)
                        await $_getPrefetchedData<
                          PlaybackItem,
                          $PlaybackItemsTable,
                          LyricPreference
                        >(
                          currentTable: table,
                          referencedTable: $$PlaybackItemsTableReferences
                              ._lyricPreferencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaybackItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).lyricPreferencesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playlistItemsRefs)
                        await $_getPrefetchedData<
                          PlaybackItem,
                          $PlaybackItemsTable,
                          PlaylistItem
                        >(
                          currentTable: table,
                          referencedTable: $$PlaybackItemsTableReferences
                              ._playlistItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaybackItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (downloadTasksRefs)
                        await $_getPrefetchedData<
                          PlaybackItem,
                          $PlaybackItemsTable,
                          DownloadTask
                        >(
                          currentTable: table,
                          referencedTable: $$PlaybackItemsTableReferences
                              ._downloadTasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaybackItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadTasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlaybackItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackItemsTable,
      PlaybackItem,
      $$PlaybackItemsTableFilterComposer,
      $$PlaybackItemsTableOrderingComposer,
      $$PlaybackItemsTableAnnotationComposer,
      $$PlaybackItemsTableCreateCompanionBuilder,
      $$PlaybackItemsTableUpdateCompanionBuilder,
      (PlaybackItem, $$PlaybackItemsTableReferences),
      PlaybackItem,
      PrefetchHooks Function({
        bool playerStateRowsRefs,
        bool queueEntriesRefs,
        bool playbackHistoryRowsRefs,
        bool localLibraryTracksRefs,
        bool audioCacheEntriesRefs,
        bool lyricPreferencesRefs,
        bool playlistItemsRefs,
        bool downloadTasksRefs,
      })
    >;
typedef $$PlayerStateRowsTableCreateCompanionBuilder =
    PlayerStateRowsCompanion Function({
      Value<int> id,
      Value<String?> currentItemId,
      Value<String> playbackMode,
      Value<double> volume,
      Value<int> lastPositionMs,
      Value<int> lastDurationMs,
    });
typedef $$PlayerStateRowsTableUpdateCompanionBuilder =
    PlayerStateRowsCompanion Function({
      Value<int> id,
      Value<String?> currentItemId,
      Value<String> playbackMode,
      Value<double> volume,
      Value<int> lastPositionMs,
      Value<int> lastDurationMs,
    });

final class $$PlayerStateRowsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PlayerStateRowsTable, PlayerStateRow> {
  $$PlayerStateRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaybackItemsTable _currentItemIdTable(_$AppDatabase db) =>
      db.playbackItems.createAlias(
        $_aliasNameGenerator(
          db.playerStateRows.currentItemId,
          db.playbackItems.id,
        ),
      );

  $$PlaybackItemsTableProcessedTableManager? get currentItemId {
    final $_column = $_itemColumn<String>('current_item_id');
    if ($_column == null) return null;
    final manager = $$PlaybackItemsTableTableManager(
      $_db,
      $_db.playbackItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_currentItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlayerStateRowsTableFilterComposer
    extends Composer<_$AppDatabase, $PlayerStateRowsTable> {
  $$PlayerStateRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playbackMode => $composableBuilder(
    column: $table.playbackMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPositionMs => $composableBuilder(
    column: $table.lastPositionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastDurationMs => $composableBuilder(
    column: $table.lastDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaybackItemsTableFilterComposer get currentItemId {
    final $$PlaybackItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentItemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableFilterComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayerStateRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayerStateRowsTable> {
  $$PlayerStateRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playbackMode => $composableBuilder(
    column: $table.playbackMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPositionMs => $composableBuilder(
    column: $table.lastPositionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastDurationMs => $composableBuilder(
    column: $table.lastDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaybackItemsTableOrderingComposer get currentItemId {
    final $$PlaybackItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentItemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableOrderingComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayerStateRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayerStateRowsTable> {
  $$PlayerStateRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get playbackMode => $composableBuilder(
    column: $table.playbackMode,
    builder: (column) => column,
  );

  GeneratedColumn<double> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<int> get lastPositionMs => $composableBuilder(
    column: $table.lastPositionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastDurationMs => $composableBuilder(
    column: $table.lastDurationMs,
    builder: (column) => column,
  );

  $$PlaybackItemsTableAnnotationComposer get currentItemId {
    final $$PlaybackItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentItemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayerStateRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayerStateRowsTable,
          PlayerStateRow,
          $$PlayerStateRowsTableFilterComposer,
          $$PlayerStateRowsTableOrderingComposer,
          $$PlayerStateRowsTableAnnotationComposer,
          $$PlayerStateRowsTableCreateCompanionBuilder,
          $$PlayerStateRowsTableUpdateCompanionBuilder,
          (PlayerStateRow, $$PlayerStateRowsTableReferences),
          PlayerStateRow,
          PrefetchHooks Function({bool currentItemId})
        > {
  $$PlayerStateRowsTableTableManager(
    _$AppDatabase db,
    $PlayerStateRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayerStateRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayerStateRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayerStateRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> currentItemId = const Value.absent(),
                Value<String> playbackMode = const Value.absent(),
                Value<double> volume = const Value.absent(),
                Value<int> lastPositionMs = const Value.absent(),
                Value<int> lastDurationMs = const Value.absent(),
              }) => PlayerStateRowsCompanion(
                id: id,
                currentItemId: currentItemId,
                playbackMode: playbackMode,
                volume: volume,
                lastPositionMs: lastPositionMs,
                lastDurationMs: lastDurationMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> currentItemId = const Value.absent(),
                Value<String> playbackMode = const Value.absent(),
                Value<double> volume = const Value.absent(),
                Value<int> lastPositionMs = const Value.absent(),
                Value<int> lastDurationMs = const Value.absent(),
              }) => PlayerStateRowsCompanion.insert(
                id: id,
                currentItemId: currentItemId,
                playbackMode: playbackMode,
                volume: volume,
                lastPositionMs: lastPositionMs,
                lastDurationMs: lastDurationMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlayerStateRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({currentItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (currentItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.currentItemId,
                                referencedTable:
                                    $$PlayerStateRowsTableReferences
                                        ._currentItemIdTable(db),
                                referencedColumn:
                                    $$PlayerStateRowsTableReferences
                                        ._currentItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlayerStateRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayerStateRowsTable,
      PlayerStateRow,
      $$PlayerStateRowsTableFilterComposer,
      $$PlayerStateRowsTableOrderingComposer,
      $$PlayerStateRowsTableAnnotationComposer,
      $$PlayerStateRowsTableCreateCompanionBuilder,
      $$PlayerStateRowsTableUpdateCompanionBuilder,
      (PlayerStateRow, $$PlayerStateRowsTableReferences),
      PlayerStateRow,
      PrefetchHooks Function({bool currentItemId})
    >;
typedef $$QueueEntriesTableCreateCompanionBuilder =
    QueueEntriesCompanion Function({
      required int position,
      required String itemId,
      Value<int> rowid,
    });
typedef $$QueueEntriesTableUpdateCompanionBuilder =
    QueueEntriesCompanion Function({
      Value<int> position,
      Value<String> itemId,
      Value<int> rowid,
    });

final class $$QueueEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $QueueEntriesTable, QueueEntry> {
  $$QueueEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlaybackItemsTable _itemIdTable(_$AppDatabase db) =>
      db.playbackItems.createAlias(
        $_aliasNameGenerator(db.queueEntries.itemId, db.playbackItems.id),
      );

  $$PlaybackItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$PlaybackItemsTableTableManager(
      $_db,
      $_db.playbackItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$QueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaybackItemsTableFilterComposer get itemId {
    final $$PlaybackItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableFilterComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaybackItemsTableOrderingComposer get itemId {
    final $$PlaybackItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableOrderingComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaybackItemsTableAnnotationComposer get itemId {
    final $$PlaybackItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QueueEntriesTable,
          QueueEntry,
          $$QueueEntriesTableFilterComposer,
          $$QueueEntriesTableOrderingComposer,
          $$QueueEntriesTableAnnotationComposer,
          $$QueueEntriesTableCreateCompanionBuilder,
          $$QueueEntriesTableUpdateCompanionBuilder,
          (QueueEntry, $$QueueEntriesTableReferences),
          QueueEntry,
          PrefetchHooks Function({bool itemId})
        > {
  $$QueueEntriesTableTableManager(_$AppDatabase db, $QueueEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueueEntriesCompanion(
                position: position,
                itemId: itemId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int position,
                required String itemId,
                Value<int> rowid = const Value.absent(),
              }) => QueueEntriesCompanion.insert(
                position: position,
                itemId: itemId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$QueueEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$QueueEntriesTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$QueueEntriesTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$QueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QueueEntriesTable,
      QueueEntry,
      $$QueueEntriesTableFilterComposer,
      $$QueueEntriesTableOrderingComposer,
      $$QueueEntriesTableAnnotationComposer,
      $$QueueEntriesTableCreateCompanionBuilder,
      $$QueueEntriesTableUpdateCompanionBuilder,
      (QueueEntry, $$QueueEntriesTableReferences),
      QueueEntry,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$PlaybackHistoryRowsTableCreateCompanionBuilder =
    PlaybackHistoryRowsCompanion Function({
      Value<int> id,
      required String itemId,
      required DateTime playedAt,
    });
typedef $$PlaybackHistoryRowsTableUpdateCompanionBuilder =
    PlaybackHistoryRowsCompanion Function({
      Value<int> id,
      Value<String> itemId,
      Value<DateTime> playedAt,
    });

final class $$PlaybackHistoryRowsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlaybackHistoryRowsTable,
          PlaybackHistoryRow
        > {
  $$PlaybackHistoryRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaybackItemsTable _itemIdTable(_$AppDatabase db) =>
      db.playbackItems.createAlias(
        $_aliasNameGenerator(
          db.playbackHistoryRows.itemId,
          db.playbackItems.id,
        ),
      );

  $$PlaybackItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$PlaybackItemsTableTableManager(
      $_db,
      $_db.playbackItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaybackHistoryRowsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackHistoryRowsTable> {
  $$PlaybackHistoryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaybackItemsTableFilterComposer get itemId {
    final $$PlaybackItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableFilterComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackHistoryRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackHistoryRowsTable> {
  $$PlaybackHistoryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaybackItemsTableOrderingComposer get itemId {
    final $$PlaybackItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableOrderingComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackHistoryRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackHistoryRowsTable> {
  $$PlaybackHistoryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  $$PlaybackItemsTableAnnotationComposer get itemId {
    final $$PlaybackItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackHistoryRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackHistoryRowsTable,
          PlaybackHistoryRow,
          $$PlaybackHistoryRowsTableFilterComposer,
          $$PlaybackHistoryRowsTableOrderingComposer,
          $$PlaybackHistoryRowsTableAnnotationComposer,
          $$PlaybackHistoryRowsTableCreateCompanionBuilder,
          $$PlaybackHistoryRowsTableUpdateCompanionBuilder,
          (PlaybackHistoryRow, $$PlaybackHistoryRowsTableReferences),
          PlaybackHistoryRow,
          PrefetchHooks Function({bool itemId})
        > {
  $$PlaybackHistoryRowsTableTableManager(
    _$AppDatabase db,
    $PlaybackHistoryRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackHistoryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackHistoryRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlaybackHistoryRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<DateTime> playedAt = const Value.absent(),
              }) => PlaybackHistoryRowsCompanion(
                id: id,
                itemId: itemId,
                playedAt: playedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String itemId,
                required DateTime playedAt,
              }) => PlaybackHistoryRowsCompanion.insert(
                id: id,
                itemId: itemId,
                playedAt: playedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaybackHistoryRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable:
                                    $$PlaybackHistoryRowsTableReferences
                                        ._itemIdTable(db),
                                referencedColumn:
                                    $$PlaybackHistoryRowsTableReferences
                                        ._itemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaybackHistoryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackHistoryRowsTable,
      PlaybackHistoryRow,
      $$PlaybackHistoryRowsTableFilterComposer,
      $$PlaybackHistoryRowsTableOrderingComposer,
      $$PlaybackHistoryRowsTableAnnotationComposer,
      $$PlaybackHistoryRowsTableCreateCompanionBuilder,
      $$PlaybackHistoryRowsTableUpdateCompanionBuilder,
      (PlaybackHistoryRow, $$PlaybackHistoryRowsTableReferences),
      PlaybackHistoryRow,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$LocalLibraryTracksTableCreateCompanionBuilder =
    LocalLibraryTracksCompanion Function({
      required String itemId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$LocalLibraryTracksTableUpdateCompanionBuilder =
    LocalLibraryTracksCompanion Function({
      Value<String> itemId,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$LocalLibraryTracksTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalLibraryTracksTable,
          LocalLibraryTrack
        > {
  $$LocalLibraryTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaybackItemsTable _itemIdTable(_$AppDatabase db) =>
      db.playbackItems.createAlias(
        $_aliasNameGenerator(db.localLibraryTracks.itemId, db.playbackItems.id),
      );

  $$PlaybackItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$PlaybackItemsTableTableManager(
      $_db,
      $_db.playbackItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalLibraryTracksTableFilterComposer
    extends Composer<_$AppDatabase, $LocalLibraryTracksTable> {
  $$LocalLibraryTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaybackItemsTableFilterComposer get itemId {
    final $$PlaybackItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableFilterComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalLibraryTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalLibraryTracksTable> {
  $$LocalLibraryTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaybackItemsTableOrderingComposer get itemId {
    final $$PlaybackItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableOrderingComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalLibraryTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalLibraryTracksTable> {
  $$LocalLibraryTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$PlaybackItemsTableAnnotationComposer get itemId {
    final $$PlaybackItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalLibraryTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalLibraryTracksTable,
          LocalLibraryTrack,
          $$LocalLibraryTracksTableFilterComposer,
          $$LocalLibraryTracksTableOrderingComposer,
          $$LocalLibraryTracksTableAnnotationComposer,
          $$LocalLibraryTracksTableCreateCompanionBuilder,
          $$LocalLibraryTracksTableUpdateCompanionBuilder,
          (LocalLibraryTrack, $$LocalLibraryTracksTableReferences),
          LocalLibraryTrack,
          PrefetchHooks Function({bool itemId})
        > {
  $$LocalLibraryTracksTableTableManager(
    _$AppDatabase db,
    $LocalLibraryTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalLibraryTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalLibraryTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalLibraryTracksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalLibraryTracksCompanion(
                itemId: itemId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalLibraryTracksCompanion.insert(
                itemId: itemId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalLibraryTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable:
                                    $$LocalLibraryTracksTableReferences
                                        ._itemIdTable(db),
                                referencedColumn:
                                    $$LocalLibraryTracksTableReferences
                                        ._itemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalLibraryTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalLibraryTracksTable,
      LocalLibraryTrack,
      $$LocalLibraryTracksTableFilterComposer,
      $$LocalLibraryTracksTableOrderingComposer,
      $$LocalLibraryTracksTableAnnotationComposer,
      $$LocalLibraryTracksTableCreateCompanionBuilder,
      $$LocalLibraryTracksTableUpdateCompanionBuilder,
      (LocalLibraryTrack, $$LocalLibraryTracksTableReferences),
      LocalLibraryTrack,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$PluginDefinitionRowsTableCreateCompanionBuilder =
    PluginDefinitionRowsCompanion Function({
      required String id,
      required String platform,
      Value<String?> version,
      Value<String?> author,
      Value<String?> description,
      required String sourcePath,
      Value<bool> enabled,
      required DateTime installedAt,
      required DateTime updatedAt,
      Value<String> supportedSearchTypesJson,
      Value<String> userVariablesJson,
      Value<String> userVariableValuesJson,
      Value<int> sortIndex,
      Value<int> rowid,
    });
typedef $$PluginDefinitionRowsTableUpdateCompanionBuilder =
    PluginDefinitionRowsCompanion Function({
      Value<String> id,
      Value<String> platform,
      Value<String?> version,
      Value<String?> author,
      Value<String?> description,
      Value<String> sourcePath,
      Value<bool> enabled,
      Value<DateTime> installedAt,
      Value<DateTime> updatedAt,
      Value<String> supportedSearchTypesJson,
      Value<String> userVariablesJson,
      Value<String> userVariableValuesJson,
      Value<int> sortIndex,
      Value<int> rowid,
    });

class $$PluginDefinitionRowsTableFilterComposer
    extends Composer<_$AppDatabase, $PluginDefinitionRowsTable> {
  $$PluginDefinitionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supportedSearchTypesJson => $composableBuilder(
    column: $table.supportedSearchTypesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userVariablesJson => $composableBuilder(
    column: $table.userVariablesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userVariableValuesJson => $composableBuilder(
    column: $table.userVariableValuesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PluginDefinitionRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PluginDefinitionRowsTable> {
  $$PluginDefinitionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supportedSearchTypesJson => $composableBuilder(
    column: $table.supportedSearchTypesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userVariablesJson => $composableBuilder(
    column: $table.userVariablesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userVariableValuesJson => $composableBuilder(
    column: $table.userVariableValuesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PluginDefinitionRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PluginDefinitionRowsTable> {
  $$PluginDefinitionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get supportedSearchTypesJson => $composableBuilder(
    column: $table.supportedSearchTypesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userVariablesJson => $composableBuilder(
    column: $table.userVariablesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userVariableValuesJson => $composableBuilder(
    column: $table.userVariableValuesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);
}

class $$PluginDefinitionRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PluginDefinitionRowsTable,
          PluginDefinitionRow,
          $$PluginDefinitionRowsTableFilterComposer,
          $$PluginDefinitionRowsTableOrderingComposer,
          $$PluginDefinitionRowsTableAnnotationComposer,
          $$PluginDefinitionRowsTableCreateCompanionBuilder,
          $$PluginDefinitionRowsTableUpdateCompanionBuilder,
          (
            PluginDefinitionRow,
            BaseReferences<
              _$AppDatabase,
              $PluginDefinitionRowsTable,
              PluginDefinitionRow
            >,
          ),
          PluginDefinitionRow,
          PrefetchHooks Function()
        > {
  $$PluginDefinitionRowsTableTableManager(
    _$AppDatabase db,
    $PluginDefinitionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PluginDefinitionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PluginDefinitionRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PluginDefinitionRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String?> version = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> supportedSearchTypesJson = const Value.absent(),
                Value<String> userVariablesJson = const Value.absent(),
                Value<String> userVariableValuesJson = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PluginDefinitionRowsCompanion(
                id: id,
                platform: platform,
                version: version,
                author: author,
                description: description,
                sourcePath: sourcePath,
                enabled: enabled,
                installedAt: installedAt,
                updatedAt: updatedAt,
                supportedSearchTypesJson: supportedSearchTypesJson,
                userVariablesJson: userVariablesJson,
                userVariableValuesJson: userVariableValuesJson,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String platform,
                Value<String?> version = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> description = const Value.absent(),
                required String sourcePath,
                Value<bool> enabled = const Value.absent(),
                required DateTime installedAt,
                required DateTime updatedAt,
                Value<String> supportedSearchTypesJson = const Value.absent(),
                Value<String> userVariablesJson = const Value.absent(),
                Value<String> userVariableValuesJson = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PluginDefinitionRowsCompanion.insert(
                id: id,
                platform: platform,
                version: version,
                author: author,
                description: description,
                sourcePath: sourcePath,
                enabled: enabled,
                installedAt: installedAt,
                updatedAt: updatedAt,
                supportedSearchTypesJson: supportedSearchTypesJson,
                userVariablesJson: userVariablesJson,
                userVariableValuesJson: userVariableValuesJson,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PluginDefinitionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PluginDefinitionRowsTable,
      PluginDefinitionRow,
      $$PluginDefinitionRowsTableFilterComposer,
      $$PluginDefinitionRowsTableOrderingComposer,
      $$PluginDefinitionRowsTableAnnotationComposer,
      $$PluginDefinitionRowsTableCreateCompanionBuilder,
      $$PluginDefinitionRowsTableUpdateCompanionBuilder,
      (
        PluginDefinitionRow,
        BaseReferences<
          _$AppDatabase,
          $PluginDefinitionRowsTable,
          PluginDefinitionRow
        >,
      ),
      PluginDefinitionRow,
      PrefetchHooks Function()
    >;
typedef $$AudioCacheEntriesTableCreateCompanionBuilder =
    AudioCacheEntriesCompanion Function({
      required String itemId,
      required String sourceUrl,
      required String path,
      required int size,
      required DateTime createdAt,
      required DateTime lastAccessedAt,
      Value<int> rowid,
    });
typedef $$AudioCacheEntriesTableUpdateCompanionBuilder =
    AudioCacheEntriesCompanion Function({
      Value<String> itemId,
      Value<String> sourceUrl,
      Value<String> path,
      Value<int> size,
      Value<DateTime> createdAt,
      Value<DateTime> lastAccessedAt,
      Value<int> rowid,
    });

final class $$AudioCacheEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AudioCacheEntriesTable,
          AudioCacheEntry
        > {
  $$AudioCacheEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaybackItemsTable _itemIdTable(_$AppDatabase db) =>
      db.playbackItems.createAlias(
        $_aliasNameGenerator(db.audioCacheEntries.itemId, db.playbackItems.id),
      );

  $$PlaybackItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$PlaybackItemsTableTableManager(
      $_db,
      $_db.playbackItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AudioCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AudioCacheEntriesTable> {
  $$AudioCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaybackItemsTableFilterComposer get itemId {
    final $$PlaybackItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableFilterComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioCacheEntriesTable> {
  $$AudioCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaybackItemsTableOrderingComposer get itemId {
    final $$PlaybackItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableOrderingComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioCacheEntriesTable> {
  $$AudioCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );

  $$PlaybackItemsTableAnnotationComposer get itemId {
    final $$PlaybackItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioCacheEntriesTable,
          AudioCacheEntry,
          $$AudioCacheEntriesTableFilterComposer,
          $$AudioCacheEntriesTableOrderingComposer,
          $$AudioCacheEntriesTableAnnotationComposer,
          $$AudioCacheEntriesTableCreateCompanionBuilder,
          $$AudioCacheEntriesTableUpdateCompanionBuilder,
          (AudioCacheEntry, $$AudioCacheEntriesTableReferences),
          AudioCacheEntry,
          PrefetchHooks Function({bool itemId})
        > {
  $$AudioCacheEntriesTableTableManager(
    _$AppDatabase db,
    $AudioCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioCacheEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> lastAccessedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioCacheEntriesCompanion(
                itemId: itemId,
                sourceUrl: sourceUrl,
                path: path,
                size: size,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String sourceUrl,
                required String path,
                required int size,
                required DateTime createdAt,
                required DateTime lastAccessedAt,
                Value<int> rowid = const Value.absent(),
              }) => AudioCacheEntriesCompanion.insert(
                itemId: itemId,
                sourceUrl: sourceUrl,
                path: path,
                size: size,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AudioCacheEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable:
                                    $$AudioCacheEntriesTableReferences
                                        ._itemIdTable(db),
                                referencedColumn:
                                    $$AudioCacheEntriesTableReferences
                                        ._itemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AudioCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioCacheEntriesTable,
      AudioCacheEntry,
      $$AudioCacheEntriesTableFilterComposer,
      $$AudioCacheEntriesTableOrderingComposer,
      $$AudioCacheEntriesTableAnnotationComposer,
      $$AudioCacheEntriesTableCreateCompanionBuilder,
      $$AudioCacheEntriesTableUpdateCompanionBuilder,
      (AudioCacheEntry, $$AudioCacheEntriesTableReferences),
      AudioCacheEntry,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$LyricPreferencesTableCreateCompanionBuilder =
    LyricPreferencesCompanion Function({
      required String itemId,
      Value<String?> sourceType,
      Value<String?> associatedPath,
      Value<String?> pluginPlatform,
      Value<String?> pluginItemRawJson,
      Value<String?> rawLyric,
      Value<int> offsetMs,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LyricPreferencesTableUpdateCompanionBuilder =
    LyricPreferencesCompanion Function({
      Value<String> itemId,
      Value<String?> sourceType,
      Value<String?> associatedPath,
      Value<String?> pluginPlatform,
      Value<String?> pluginItemRawJson,
      Value<String?> rawLyric,
      Value<int> offsetMs,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$LyricPreferencesTableReferences
    extends
        BaseReferences<_$AppDatabase, $LyricPreferencesTable, LyricPreference> {
  $$LyricPreferencesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaybackItemsTable _itemIdTable(_$AppDatabase db) =>
      db.playbackItems.createAlias(
        $_aliasNameGenerator(db.lyricPreferences.itemId, db.playbackItems.id),
      );

  $$PlaybackItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$PlaybackItemsTableTableManager(
      $_db,
      $_db.playbackItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LyricPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $LyricPreferencesTable> {
  $$LyricPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get associatedPath => $composableBuilder(
    column: $table.associatedPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pluginPlatform => $composableBuilder(
    column: $table.pluginPlatform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pluginItemRawJson => $composableBuilder(
    column: $table.pluginItemRawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawLyric => $composableBuilder(
    column: $table.rawLyric,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaybackItemsTableFilterComposer get itemId {
    final $$PlaybackItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableFilterComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $LyricPreferencesTable> {
  $$LyricPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get associatedPath => $composableBuilder(
    column: $table.associatedPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pluginPlatform => $composableBuilder(
    column: $table.pluginPlatform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pluginItemRawJson => $composableBuilder(
    column: $table.pluginItemRawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawLyric => $composableBuilder(
    column: $table.rawLyric,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaybackItemsTableOrderingComposer get itemId {
    final $$PlaybackItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableOrderingComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LyricPreferencesTable> {
  $$LyricPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get associatedPath => $composableBuilder(
    column: $table.associatedPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pluginPlatform => $composableBuilder(
    column: $table.pluginPlatform,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pluginItemRawJson => $composableBuilder(
    column: $table.pluginItemRawJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawLyric =>
      $composableBuilder(column: $table.rawLyric, builder: (column) => column);

  GeneratedColumn<int> get offsetMs =>
      $composableBuilder(column: $table.offsetMs, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PlaybackItemsTableAnnotationComposer get itemId {
    final $$PlaybackItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LyricPreferencesTable,
          LyricPreference,
          $$LyricPreferencesTableFilterComposer,
          $$LyricPreferencesTableOrderingComposer,
          $$LyricPreferencesTableAnnotationComposer,
          $$LyricPreferencesTableCreateCompanionBuilder,
          $$LyricPreferencesTableUpdateCompanionBuilder,
          (LyricPreference, $$LyricPreferencesTableReferences),
          LyricPreference,
          PrefetchHooks Function({bool itemId})
        > {
  $$LyricPreferencesTableTableManager(
    _$AppDatabase db,
    $LyricPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String?> sourceType = const Value.absent(),
                Value<String?> associatedPath = const Value.absent(),
                Value<String?> pluginPlatform = const Value.absent(),
                Value<String?> pluginItemRawJson = const Value.absent(),
                Value<String?> rawLyric = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LyricPreferencesCompanion(
                itemId: itemId,
                sourceType: sourceType,
                associatedPath: associatedPath,
                pluginPlatform: pluginPlatform,
                pluginItemRawJson: pluginItemRawJson,
                rawLyric: rawLyric,
                offsetMs: offsetMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                Value<String?> sourceType = const Value.absent(),
                Value<String?> associatedPath = const Value.absent(),
                Value<String?> pluginPlatform = const Value.absent(),
                Value<String?> pluginItemRawJson = const Value.absent(),
                Value<String?> rawLyric = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LyricPreferencesCompanion.insert(
                itemId: itemId,
                sourceType: sourceType,
                associatedPath: associatedPath,
                pluginPlatform: pluginPlatform,
                pluginItemRawJson: pluginItemRawJson,
                rawLyric: rawLyric,
                offsetMs: offsetMs,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LyricPreferencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable:
                                    $$LyricPreferencesTableReferences
                                        ._itemIdTable(db),
                                referencedColumn:
                                    $$LyricPreferencesTableReferences
                                        ._itemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LyricPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LyricPreferencesTable,
      LyricPreference,
      $$LyricPreferencesTableFilterComposer,
      $$LyricPreferencesTableOrderingComposer,
      $$LyricPreferencesTableAnnotationComposer,
      $$LyricPreferencesTableCreateCompanionBuilder,
      $$LyricPreferencesTableUpdateCompanionBuilder,
      (LyricPreference, $$LyricPreferencesTableReferences),
      LyricPreference,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$PlaylistsTableCreateCompanionBuilder =
    PlaylistsCompanion Function({
      required String id,
      required String name,
      Value<bool> isFavorites,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PlaylistsTableUpdateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<bool> isFavorites,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistItemsTable, List<PlaylistItem>>
  _playlistItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistItems,
    aliasName: $_aliasNameGenerator(
      db.playlists.id,
      db.playlistItems.playlistId,
    ),
  );

  $$PlaylistItemsTableProcessedTableManager get playlistItemsRefs {
    final manager = $$PlaylistItemsTableTableManager(
      $_db,
      $_db.playlistItems,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorites => $composableBuilder(
    column: $table.isFavorites,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistItemsRefs(
    Expression<bool> Function($$PlaylistItemsTableFilterComposer f) f,
  ) {
    final $$PlaylistItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistItems,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistItemsTableFilterComposer(
            $db: $db,
            $table: $db.playlistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorites => $composableBuilder(
    column: $table.isFavorites,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isFavorites => $composableBuilder(
    column: $table.isFavorites,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> playlistItemsRefs<T extends Object>(
    Expression<T> Function($$PlaylistItemsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistItems,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, $$PlaylistsTableReferences),
          Playlist,
          PrefetchHooks Function({bool playlistItemsRefs})
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isFavorites = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                isFavorites: isFavorites,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<bool> isFavorites = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                isFavorites: isFavorites,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistItemsRefs) db.playlistItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistItemsRefs)
                    await $_getPrefetchedData<
                      Playlist,
                      $PlaylistsTable,
                      PlaylistItem
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.playlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, $$PlaylistsTableReferences),
      Playlist,
      PrefetchHooks Function({bool playlistItemsRefs})
    >;
typedef $$PlaylistItemsTableCreateCompanionBuilder =
    PlaylistItemsCompanion Function({
      required String playlistId,
      required String itemId,
      Value<int> position,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$PlaylistItemsTableUpdateCompanionBuilder =
    PlaylistItemsCompanion Function({
      Value<String> playlistId,
      Value<String> itemId,
      Value<int> position,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$PlaylistItemsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistItemsTable, PlaylistItem> {
  $$PlaylistItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias(
        $_aliasNameGenerator(db.playlistItems.playlistId, db.playlists.id),
      );

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<String>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlaybackItemsTable _itemIdTable(_$AppDatabase db) =>
      db.playbackItems.createAlias(
        $_aliasNameGenerator(db.playlistItems.itemId, db.playbackItems.id),
      );

  $$PlaybackItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$PlaybackItemsTableTableManager(
      $_db,
      $_db.playbackItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlaybackItemsTableFilterComposer get itemId {
    final $$PlaybackItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableFilterComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlaybackItemsTableOrderingComposer get itemId {
    final $$PlaybackItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableOrderingComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistItemsTable> {
  $$PlaylistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlaybackItemsTableAnnotationComposer get itemId {
    final $$PlaybackItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistItemsTable,
          PlaylistItem,
          $$PlaylistItemsTableFilterComposer,
          $$PlaylistItemsTableOrderingComposer,
          $$PlaylistItemsTableAnnotationComposer,
          $$PlaylistItemsTableCreateCompanionBuilder,
          $$PlaylistItemsTableUpdateCompanionBuilder,
          (PlaylistItem, $$PlaylistItemsTableReferences),
          PlaylistItem,
          PrefetchHooks Function({bool playlistId, bool itemId})
        > {
  $$PlaylistItemsTableTableManager(_$AppDatabase db, $PlaylistItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playlistId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistItemsCompanion(
                playlistId: playlistId,
                itemId: itemId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playlistId,
                required String itemId,
                Value<int> position = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistItemsCompanion.insert(
                playlistId: playlistId,
                itemId: itemId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaylistItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false, itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.playlistId,
                                referencedTable: $$PlaylistItemsTableReferences
                                    ._playlistIdTable(db),
                                referencedColumn: $$PlaylistItemsTableReferences
                                    ._playlistIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$PlaylistItemsTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$PlaylistItemsTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistItemsTable,
      PlaylistItem,
      $$PlaylistItemsTableFilterComposer,
      $$PlaylistItemsTableOrderingComposer,
      $$PlaylistItemsTableAnnotationComposer,
      $$PlaylistItemsTableCreateCompanionBuilder,
      $$PlaylistItemsTableUpdateCompanionBuilder,
      (PlaylistItem, $$PlaylistItemsTableReferences),
      PlaylistItem,
      PrefetchHooks Function({bool playlistId, bool itemId})
    >;
typedef $$DownloadTasksTableCreateCompanionBuilder =
    DownloadTasksCompanion Function({
      required String id,
      required String itemId,
      required String status,
      Value<double> progress,
      Value<String?> sourceUrl,
      Value<String?> filePath,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$DownloadTasksTableUpdateCompanionBuilder =
    DownloadTasksCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String> status,
      Value<double> progress,
      Value<String?> sourceUrl,
      Value<String?> filePath,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$DownloadTasksTableReferences
    extends BaseReferences<_$AppDatabase, $DownloadTasksTable, DownloadTask> {
  $$DownloadTasksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaybackItemsTable _itemIdTable(_$AppDatabase db) =>
      db.playbackItems.createAlias(
        $_aliasNameGenerator(db.downloadTasks.itemId, db.playbackItems.id),
      );

  $$PlaybackItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$PlaybackItemsTableTableManager(
      $_db,
      $_db.playbackItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaybackItemsTableFilterComposer get itemId {
    final $$PlaybackItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableFilterComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaybackItemsTableOrderingComposer get itemId {
    final $$PlaybackItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableOrderingComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadTasksTable> {
  $$DownloadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$PlaybackItemsTableAnnotationComposer get itemId {
    final $$PlaybackItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.playbackItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadTasksTable,
          DownloadTask,
          $$DownloadTasksTableFilterComposer,
          $$DownloadTasksTableOrderingComposer,
          $$DownloadTasksTableAnnotationComposer,
          $$DownloadTasksTableCreateCompanionBuilder,
          $$DownloadTasksTableUpdateCompanionBuilder,
          (DownloadTask, $$DownloadTasksTableReferences),
          DownloadTask,
          PrefetchHooks Function({bool itemId})
        > {
  $$DownloadTasksTableTableManager(_$AppDatabase db, $DownloadTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion(
                id: id,
                itemId: itemId,
                status: status,
                progress: progress,
                sourceUrl: sourceUrl,
                filePath: filePath,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required String status,
                Value<double> progress = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadTasksCompanion.insert(
                id: id,
                itemId: itemId,
                status: status,
                progress: progress,
                sourceUrl: sourceUrl,
                filePath: filePath,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadTasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$DownloadTasksTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$DownloadTasksTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadTasksTable,
      DownloadTask,
      $$DownloadTasksTableFilterComposer,
      $$DownloadTasksTableOrderingComposer,
      $$DownloadTasksTableAnnotationComposer,
      $$DownloadTasksTableCreateCompanionBuilder,
      $$DownloadTasksTableUpdateCompanionBuilder,
      (DownloadTask, $$DownloadTasksTableReferences),
      DownloadTask,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$FavoriteCollectionsTableCreateCompanionBuilder =
    FavoriteCollectionsCompanion Function({
      required String collectionKey,
      required String pluginId,
      required String platform,
      required String kind,
      required String collectionId,
      required String title,
      Value<String?> description,
      Value<String?> artworkUrl,
      required String rawJson,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$FavoriteCollectionsTableUpdateCompanionBuilder =
    FavoriteCollectionsCompanion Function({
      Value<String> collectionKey,
      Value<String> pluginId,
      Value<String> platform,
      Value<String> kind,
      Value<String> collectionId,
      Value<String> title,
      Value<String?> description,
      Value<String?> artworkUrl,
      Value<String> rawJson,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$FavoriteCollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteCollectionsTable> {
  $$FavoriteCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get collectionKey => $composableBuilder(
    column: $table.collectionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoriteCollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteCollectionsTable> {
  $$FavoriteCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get collectionKey => $composableBuilder(
    column: $table.collectionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoriteCollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteCollectionsTable> {
  $$FavoriteCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get collectionKey => $composableBuilder(
    column: $table.collectionKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get collectionId => $composableBuilder(
    column: $table.collectionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artworkUrl => $composableBuilder(
    column: $table.artworkUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavoriteCollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteCollectionsTable,
          FavoriteCollection,
          $$FavoriteCollectionsTableFilterComposer,
          $$FavoriteCollectionsTableOrderingComposer,
          $$FavoriteCollectionsTableAnnotationComposer,
          $$FavoriteCollectionsTableCreateCompanionBuilder,
          $$FavoriteCollectionsTableUpdateCompanionBuilder,
          (
            FavoriteCollection,
            BaseReferences<
              _$AppDatabase,
              $FavoriteCollectionsTable,
              FavoriteCollection
            >,
          ),
          FavoriteCollection,
          PrefetchHooks Function()
        > {
  $$FavoriteCollectionsTableTableManager(
    _$AppDatabase db,
    $FavoriteCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteCollectionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FavoriteCollectionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> collectionKey = const Value.absent(),
                Value<String> pluginId = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> collectionId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteCollectionsCompanion(
                collectionKey: collectionKey,
                pluginId: pluginId,
                platform: platform,
                kind: kind,
                collectionId: collectionId,
                title: title,
                description: description,
                artworkUrl: artworkUrl,
                rawJson: rawJson,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collectionKey,
                required String pluginId,
                required String platform,
                required String kind,
                required String collectionId,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> artworkUrl = const Value.absent(),
                required String rawJson,
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteCollectionsCompanion.insert(
                collectionKey: collectionKey,
                pluginId: pluginId,
                platform: platform,
                kind: kind,
                collectionId: collectionId,
                title: title,
                description: description,
                artworkUrl: artworkUrl,
                rawJson: rawJson,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoriteCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteCollectionsTable,
      FavoriteCollection,
      $$FavoriteCollectionsTableFilterComposer,
      $$FavoriteCollectionsTableOrderingComposer,
      $$FavoriteCollectionsTableAnnotationComposer,
      $$FavoriteCollectionsTableCreateCompanionBuilder,
      $$FavoriteCollectionsTableUpdateCompanionBuilder,
      (
        FavoriteCollection,
        BaseReferences<
          _$AppDatabase,
          $FavoriteCollectionsTable,
          FavoriteCollection
        >,
      ),
      FavoriteCollection,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlaybackItemsTableTableManager get playbackItems =>
      $$PlaybackItemsTableTableManager(_db, _db.playbackItems);
  $$PlayerStateRowsTableTableManager get playerStateRows =>
      $$PlayerStateRowsTableTableManager(_db, _db.playerStateRows);
  $$QueueEntriesTableTableManager get queueEntries =>
      $$QueueEntriesTableTableManager(_db, _db.queueEntries);
  $$PlaybackHistoryRowsTableTableManager get playbackHistoryRows =>
      $$PlaybackHistoryRowsTableTableManager(_db, _db.playbackHistoryRows);
  $$LocalLibraryTracksTableTableManager get localLibraryTracks =>
      $$LocalLibraryTracksTableTableManager(_db, _db.localLibraryTracks);
  $$PluginDefinitionRowsTableTableManager get pluginDefinitionRows =>
      $$PluginDefinitionRowsTableTableManager(_db, _db.pluginDefinitionRows);
  $$AudioCacheEntriesTableTableManager get audioCacheEntries =>
      $$AudioCacheEntriesTableTableManager(_db, _db.audioCacheEntries);
  $$LyricPreferencesTableTableManager get lyricPreferences =>
      $$LyricPreferencesTableTableManager(_db, _db.lyricPreferences);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistItemsTableTableManager get playlistItems =>
      $$PlaylistItemsTableTableManager(_db, _db.playlistItems);
  $$DownloadTasksTableTableManager get downloadTasks =>
      $$DownloadTasksTableTableManager(_db, _db.downloadTasks);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$FavoriteCollectionsTableTableManager get favoriteCollections =>
      $$FavoriteCollectionsTableTableManager(_db, _db.favoriteCollections);
}
