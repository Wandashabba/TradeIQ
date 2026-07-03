// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_db.dart';

// ignore_for_file: type=lint
class $VisitDraftsTable extends VisitDrafts
    with TableInfo<$VisitDraftsTable, VisitDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outletIdMeta = const VerificationMeta(
    'outletId',
  );
  @override
  late final GeneratedColumn<String> outletId = GeneratedColumn<String>(
    'outlet_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('in_progress'),
  );
  static const VerificationMeta _checkinTsMeta = const VerificationMeta(
    'checkinTs',
  );
  @override
  late final GeneratedColumn<DateTime> checkinTs = GeneratedColumn<DateTime>(
    'checkin_ts',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkinLatMeta = const VerificationMeta(
    'checkinLat',
  );
  @override
  late final GeneratedColumn<double> checkinLat = GeneratedColumn<double>(
    'checkin_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkinLngMeta = const VerificationMeta(
    'checkinLng',
  );
  @override
  late final GeneratedColumn<double> checkinLng = GeneratedColumn<double>(
    'checkin_lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geofencePassMeta = const VerificationMeta(
    'geofencePass',
  );
  @override
  late final GeneratedColumn<bool> geofencePass = GeneratedColumn<bool>(
    'geofence_pass',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("geofence_pass" IN (0, 1))',
    ),
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    outletId,
    status,
    checkinTs,
    checkinLat,
    checkinLng,
    geofencePass,
    remoteId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visit_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisitDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('outlet_id')) {
      context.handle(
        _outletIdMeta,
        outletId.isAcceptableOrUnknown(data['outlet_id']!, _outletIdMeta),
      );
    } else if (isInserting) {
      context.missing(_outletIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('checkin_ts')) {
      context.handle(
        _checkinTsMeta,
        checkinTs.isAcceptableOrUnknown(data['checkin_ts']!, _checkinTsMeta),
      );
    } else if (isInserting) {
      context.missing(_checkinTsMeta);
    }
    if (data.containsKey('checkin_lat')) {
      context.handle(
        _checkinLatMeta,
        checkinLat.isAcceptableOrUnknown(data['checkin_lat']!, _checkinLatMeta),
      );
    } else if (isInserting) {
      context.missing(_checkinLatMeta);
    }
    if (data.containsKey('checkin_lng')) {
      context.handle(
        _checkinLngMeta,
        checkinLng.isAcceptableOrUnknown(data['checkin_lng']!, _checkinLngMeta),
      );
    } else if (isInserting) {
      context.missing(_checkinLngMeta);
    }
    if (data.containsKey('geofence_pass')) {
      context.handle(
        _geofencePassMeta,
        geofencePass.isAcceptableOrUnknown(
          data['geofence_pass']!,
          _geofencePassMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_geofencePassMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisitDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisitDraft(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      outletId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outlet_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      checkinTs: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checkin_ts'],
      )!,
      checkinLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}checkin_lat'],
      )!,
      checkinLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}checkin_lng'],
      )!,
      geofencePass: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}geofence_pass'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
    );
  }

  @override
  $VisitDraftsTable createAlias(String alias) {
    return $VisitDraftsTable(attachedDatabase, alias);
  }
}

class VisitDraft extends DataClass implements Insertable<VisitDraft> {
  final String id;
  final String outletId;
  final String status;
  final DateTime checkinTs;
  final double checkinLat;
  final double checkinLng;
  final bool geofencePass;
  final String? remoteId;
  const VisitDraft({
    required this.id,
    required this.outletId,
    required this.status,
    required this.checkinTs,
    required this.checkinLat,
    required this.checkinLng,
    required this.geofencePass,
    this.remoteId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['outlet_id'] = Variable<String>(outletId);
    map['status'] = Variable<String>(status);
    map['checkin_ts'] = Variable<DateTime>(checkinTs);
    map['checkin_lat'] = Variable<double>(checkinLat);
    map['checkin_lng'] = Variable<double>(checkinLng);
    map['geofence_pass'] = Variable<bool>(geofencePass);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    return map;
  }

  VisitDraftsCompanion toCompanion(bool nullToAbsent) {
    return VisitDraftsCompanion(
      id: Value(id),
      outletId: Value(outletId),
      status: Value(status),
      checkinTs: Value(checkinTs),
      checkinLat: Value(checkinLat),
      checkinLng: Value(checkinLng),
      geofencePass: Value(geofencePass),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
    );
  }

  factory VisitDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisitDraft(
      id: serializer.fromJson<String>(json['id']),
      outletId: serializer.fromJson<String>(json['outletId']),
      status: serializer.fromJson<String>(json['status']),
      checkinTs: serializer.fromJson<DateTime>(json['checkinTs']),
      checkinLat: serializer.fromJson<double>(json['checkinLat']),
      checkinLng: serializer.fromJson<double>(json['checkinLng']),
      geofencePass: serializer.fromJson<bool>(json['geofencePass']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'outletId': serializer.toJson<String>(outletId),
      'status': serializer.toJson<String>(status),
      'checkinTs': serializer.toJson<DateTime>(checkinTs),
      'checkinLat': serializer.toJson<double>(checkinLat),
      'checkinLng': serializer.toJson<double>(checkinLng),
      'geofencePass': serializer.toJson<bool>(geofencePass),
      'remoteId': serializer.toJson<String?>(remoteId),
    };
  }

  VisitDraft copyWith({
    String? id,
    String? outletId,
    String? status,
    DateTime? checkinTs,
    double? checkinLat,
    double? checkinLng,
    bool? geofencePass,
    Value<String?> remoteId = const Value.absent(),
  }) => VisitDraft(
    id: id ?? this.id,
    outletId: outletId ?? this.outletId,
    status: status ?? this.status,
    checkinTs: checkinTs ?? this.checkinTs,
    checkinLat: checkinLat ?? this.checkinLat,
    checkinLng: checkinLng ?? this.checkinLng,
    geofencePass: geofencePass ?? this.geofencePass,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
  );
  VisitDraft copyWithCompanion(VisitDraftsCompanion data) {
    return VisitDraft(
      id: data.id.present ? data.id.value : this.id,
      outletId: data.outletId.present ? data.outletId.value : this.outletId,
      status: data.status.present ? data.status.value : this.status,
      checkinTs: data.checkinTs.present ? data.checkinTs.value : this.checkinTs,
      checkinLat: data.checkinLat.present
          ? data.checkinLat.value
          : this.checkinLat,
      checkinLng: data.checkinLng.present
          ? data.checkinLng.value
          : this.checkinLng,
      geofencePass: data.geofencePass.present
          ? data.geofencePass.value
          : this.geofencePass,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisitDraft(')
          ..write('id: $id, ')
          ..write('outletId: $outletId, ')
          ..write('status: $status, ')
          ..write('checkinTs: $checkinTs, ')
          ..write('checkinLat: $checkinLat, ')
          ..write('checkinLng: $checkinLng, ')
          ..write('geofencePass: $geofencePass, ')
          ..write('remoteId: $remoteId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    outletId,
    status,
    checkinTs,
    checkinLat,
    checkinLng,
    geofencePass,
    remoteId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisitDraft &&
          other.id == this.id &&
          other.outletId == this.outletId &&
          other.status == this.status &&
          other.checkinTs == this.checkinTs &&
          other.checkinLat == this.checkinLat &&
          other.checkinLng == this.checkinLng &&
          other.geofencePass == this.geofencePass &&
          other.remoteId == this.remoteId);
}

class VisitDraftsCompanion extends UpdateCompanion<VisitDraft> {
  final Value<String> id;
  final Value<String> outletId;
  final Value<String> status;
  final Value<DateTime> checkinTs;
  final Value<double> checkinLat;
  final Value<double> checkinLng;
  final Value<bool> geofencePass;
  final Value<String?> remoteId;
  final Value<int> rowid;
  const VisitDraftsCompanion({
    this.id = const Value.absent(),
    this.outletId = const Value.absent(),
    this.status = const Value.absent(),
    this.checkinTs = const Value.absent(),
    this.checkinLat = const Value.absent(),
    this.checkinLng = const Value.absent(),
    this.geofencePass = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VisitDraftsCompanion.insert({
    required String id,
    required String outletId,
    this.status = const Value.absent(),
    required DateTime checkinTs,
    required double checkinLat,
    required double checkinLng,
    required bool geofencePass,
    this.remoteId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       outletId = Value(outletId),
       checkinTs = Value(checkinTs),
       checkinLat = Value(checkinLat),
       checkinLng = Value(checkinLng),
       geofencePass = Value(geofencePass);
  static Insertable<VisitDraft> custom({
    Expression<String>? id,
    Expression<String>? outletId,
    Expression<String>? status,
    Expression<DateTime>? checkinTs,
    Expression<double>? checkinLat,
    Expression<double>? checkinLng,
    Expression<bool>? geofencePass,
    Expression<String>? remoteId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (outletId != null) 'outlet_id': outletId,
      if (status != null) 'status': status,
      if (checkinTs != null) 'checkin_ts': checkinTs,
      if (checkinLat != null) 'checkin_lat': checkinLat,
      if (checkinLng != null) 'checkin_lng': checkinLng,
      if (geofencePass != null) 'geofence_pass': geofencePass,
      if (remoteId != null) 'remote_id': remoteId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VisitDraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? outletId,
    Value<String>? status,
    Value<DateTime>? checkinTs,
    Value<double>? checkinLat,
    Value<double>? checkinLng,
    Value<bool>? geofencePass,
    Value<String?>? remoteId,
    Value<int>? rowid,
  }) {
    return VisitDraftsCompanion(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      status: status ?? this.status,
      checkinTs: checkinTs ?? this.checkinTs,
      checkinLat: checkinLat ?? this.checkinLat,
      checkinLng: checkinLng ?? this.checkinLng,
      geofencePass: geofencePass ?? this.geofencePass,
      remoteId: remoteId ?? this.remoteId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (outletId.present) {
      map['outlet_id'] = Variable<String>(outletId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (checkinTs.present) {
      map['checkin_ts'] = Variable<DateTime>(checkinTs.value);
    }
    if (checkinLat.present) {
      map['checkin_lat'] = Variable<double>(checkinLat.value);
    }
    if (checkinLng.present) {
      map['checkin_lng'] = Variable<double>(checkinLng.value);
    }
    if (geofencePass.present) {
      map['geofence_pass'] = Variable<bool>(geofencePass.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitDraftsCompanion(')
          ..write('id: $id, ')
          ..write('outletId: $outletId, ')
          ..write('status: $status, ')
          ..write('checkinTs: $checkinTs, ')
          ..write('checkinLat: $checkinLat, ')
          ..write('checkinLng: $checkinLng, ')
          ..write('geofencePass: $geofencePass, ')
          ..write('remoteId: $remoteId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueItemsTable extends SyncQueueItems
    with TableInfo<$SyncQueueItemsTable, SyncQueueItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    payloadJson,
    queuedAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $SyncQueueItemsTable createAlias(String alias) {
    return $SyncQueueItemsTable(attachedDatabase, alias);
  }
}

class SyncQueueItem extends DataClass implements Insertable<SyncQueueItem> {
  final int id;
  final String entityType;
  final String entityId;
  final String payloadJson;
  final DateTime queuedAt;
  final bool synced;
  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.payloadJson,
    required this.queuedAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  SyncQueueItemsCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueItemsCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      payloadJson: Value(payloadJson),
      queuedAt: Value(queuedAt),
      synced: Value(synced),
    );
  }

  factory SyncQueueItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueItem(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  SyncQueueItem copyWith({
    int? id,
    String? entityType,
    String? entityId,
    String? payloadJson,
    DateTime? queuedAt,
    bool? synced,
  }) => SyncQueueItem(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    payloadJson: payloadJson ?? this.payloadJson,
    queuedAt: queuedAt ?? this.queuedAt,
    synced: synced ?? this.synced,
  );
  SyncQueueItem copyWithCompanion(SyncQueueItemsCompanion data) {
    return SyncQueueItem(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueItem(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entityType, entityId, payloadJson, queuedAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueItem &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.payloadJson == this.payloadJson &&
          other.queuedAt == this.queuedAt &&
          other.synced == this.synced);
}

class SyncQueueItemsCompanion extends UpdateCompanion<SyncQueueItem> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> payloadJson;
  final Value<DateTime> queuedAt;
  final Value<bool> synced;
  const SyncQueueItemsCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  SyncQueueItemsCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String entityId,
    required String payloadJson,
    this.queuedAt = const Value.absent(),
    this.synced = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       payloadJson = Value(payloadJson);
  static Insertable<SyncQueueItem> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? payloadJson,
    Expression<DateTime>? queuedAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (synced != null) 'synced': synced,
    });
  }

  SyncQueueItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? payloadJson,
    Value<DateTime>? queuedAt,
    Value<bool>? synced,
  }) {
    return SyncQueueItemsCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payloadJson: payloadJson ?? this.payloadJson,
      queuedAt: queuedAt ?? this.queuedAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueItemsCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

class $StockDraftsTable extends StockDrafts
    with TableInfo<$StockDraftsTable, StockDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visitIdMeta = const VerificationMeta(
    'visitId',
  );
  @override
  late final GeneratedColumn<String> visitId = GeneratedColumn<String>(
    'visit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skuIdMeta = const VerificationMeta('skuId');
  @override
  late final GeneratedColumn<String> skuId = GeneratedColumn<String>(
    'sku_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitsAvailableMeta = const VerificationMeta(
    'unitsAvailable',
  );
  @override
  late final GeneratedColumn<int> unitsAvailable = GeneratedColumn<int>(
    'units_available',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastStockinDateMeta = const VerificationMeta(
    'lastStockinDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastStockinDate =
      GeneratedColumn<DateTime>(
        'last_stockin_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _daysOutOfStockMeta = const VerificationMeta(
    'daysOutOfStock',
  );
  @override
  late final GeneratedColumn<int> daysOutOfStock = GeneratedColumn<int>(
    'days_out_of_stock',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _velocityAvgMeta = const VerificationMeta(
    'velocityAvg',
  );
  @override
  late final GeneratedColumn<double> velocityAvg = GeneratedColumn<double>(
    'velocity_avg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _salesActualMeta = const VerificationMeta(
    'salesActual',
  );
  @override
  late final GeneratedColumn<double> salesActual = GeneratedColumn<double>(
    'sales_actual',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _salesTargetMeta = const VerificationMeta(
    'salesTarget',
  );
  @override
  late final GeneratedColumn<double> salesTarget = GeneratedColumn<double>(
    'sales_target',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    visitId,
    skuId,
    unitsAvailable,
    lastStockinDate,
    daysOutOfStock,
    velocityAvg,
    salesActual,
    salesTarget,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<StockDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('visit_id')) {
      context.handle(
        _visitIdMeta,
        visitId.isAcceptableOrUnknown(data['visit_id']!, _visitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_visitIdMeta);
    }
    if (data.containsKey('sku_id')) {
      context.handle(
        _skuIdMeta,
        skuId.isAcceptableOrUnknown(data['sku_id']!, _skuIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skuIdMeta);
    }
    if (data.containsKey('units_available')) {
      context.handle(
        _unitsAvailableMeta,
        unitsAvailable.isAcceptableOrUnknown(
          data['units_available']!,
          _unitsAvailableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitsAvailableMeta);
    }
    if (data.containsKey('last_stockin_date')) {
      context.handle(
        _lastStockinDateMeta,
        lastStockinDate.isAcceptableOrUnknown(
          data['last_stockin_date']!,
          _lastStockinDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastStockinDateMeta);
    }
    if (data.containsKey('days_out_of_stock')) {
      context.handle(
        _daysOutOfStockMeta,
        daysOutOfStock.isAcceptableOrUnknown(
          data['days_out_of_stock']!,
          _daysOutOfStockMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_daysOutOfStockMeta);
    }
    if (data.containsKey('velocity_avg')) {
      context.handle(
        _velocityAvgMeta,
        velocityAvg.isAcceptableOrUnknown(
          data['velocity_avg']!,
          _velocityAvgMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_velocityAvgMeta);
    }
    if (data.containsKey('sales_actual')) {
      context.handle(
        _salesActualMeta,
        salesActual.isAcceptableOrUnknown(
          data['sales_actual']!,
          _salesActualMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_salesActualMeta);
    }
    if (data.containsKey('sales_target')) {
      context.handle(
        _salesTargetMeta,
        salesTarget.isAcceptableOrUnknown(
          data['sales_target']!,
          _salesTargetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_salesTargetMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockDraft(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      visitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visit_id'],
      )!,
      skuId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku_id'],
      )!,
      unitsAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}units_available'],
      )!,
      lastStockinDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_stockin_date'],
      )!,
      daysOutOfStock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days_out_of_stock'],
      )!,
      velocityAvg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}velocity_avg'],
      )!,
      salesActual: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sales_actual'],
      )!,
      salesTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sales_target'],
      )!,
    );
  }

  @override
  $StockDraftsTable createAlias(String alias) {
    return $StockDraftsTable(attachedDatabase, alias);
  }
}

class StockDraft extends DataClass implements Insertable<StockDraft> {
  final String id;
  final String visitId;
  final String skuId;
  final int unitsAvailable;
  final DateTime lastStockinDate;
  final int daysOutOfStock;
  final double velocityAvg;
  final double salesActual;
  final double salesTarget;
  const StockDraft({
    required this.id,
    required this.visitId,
    required this.skuId,
    required this.unitsAvailable,
    required this.lastStockinDate,
    required this.daysOutOfStock,
    required this.velocityAvg,
    required this.salesActual,
    required this.salesTarget,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['visit_id'] = Variable<String>(visitId);
    map['sku_id'] = Variable<String>(skuId);
    map['units_available'] = Variable<int>(unitsAvailable);
    map['last_stockin_date'] = Variable<DateTime>(lastStockinDate);
    map['days_out_of_stock'] = Variable<int>(daysOutOfStock);
    map['velocity_avg'] = Variable<double>(velocityAvg);
    map['sales_actual'] = Variable<double>(salesActual);
    map['sales_target'] = Variable<double>(salesTarget);
    return map;
  }

  StockDraftsCompanion toCompanion(bool nullToAbsent) {
    return StockDraftsCompanion(
      id: Value(id),
      visitId: Value(visitId),
      skuId: Value(skuId),
      unitsAvailable: Value(unitsAvailable),
      lastStockinDate: Value(lastStockinDate),
      daysOutOfStock: Value(daysOutOfStock),
      velocityAvg: Value(velocityAvg),
      salesActual: Value(salesActual),
      salesTarget: Value(salesTarget),
    );
  }

  factory StockDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockDraft(
      id: serializer.fromJson<String>(json['id']),
      visitId: serializer.fromJson<String>(json['visitId']),
      skuId: serializer.fromJson<String>(json['skuId']),
      unitsAvailable: serializer.fromJson<int>(json['unitsAvailable']),
      lastStockinDate: serializer.fromJson<DateTime>(json['lastStockinDate']),
      daysOutOfStock: serializer.fromJson<int>(json['daysOutOfStock']),
      velocityAvg: serializer.fromJson<double>(json['velocityAvg']),
      salesActual: serializer.fromJson<double>(json['salesActual']),
      salesTarget: serializer.fromJson<double>(json['salesTarget']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'visitId': serializer.toJson<String>(visitId),
      'skuId': serializer.toJson<String>(skuId),
      'unitsAvailable': serializer.toJson<int>(unitsAvailable),
      'lastStockinDate': serializer.toJson<DateTime>(lastStockinDate),
      'daysOutOfStock': serializer.toJson<int>(daysOutOfStock),
      'velocityAvg': serializer.toJson<double>(velocityAvg),
      'salesActual': serializer.toJson<double>(salesActual),
      'salesTarget': serializer.toJson<double>(salesTarget),
    };
  }

  StockDraft copyWith({
    String? id,
    String? visitId,
    String? skuId,
    int? unitsAvailable,
    DateTime? lastStockinDate,
    int? daysOutOfStock,
    double? velocityAvg,
    double? salesActual,
    double? salesTarget,
  }) => StockDraft(
    id: id ?? this.id,
    visitId: visitId ?? this.visitId,
    skuId: skuId ?? this.skuId,
    unitsAvailable: unitsAvailable ?? this.unitsAvailable,
    lastStockinDate: lastStockinDate ?? this.lastStockinDate,
    daysOutOfStock: daysOutOfStock ?? this.daysOutOfStock,
    velocityAvg: velocityAvg ?? this.velocityAvg,
    salesActual: salesActual ?? this.salesActual,
    salesTarget: salesTarget ?? this.salesTarget,
  );
  StockDraft copyWithCompanion(StockDraftsCompanion data) {
    return StockDraft(
      id: data.id.present ? data.id.value : this.id,
      visitId: data.visitId.present ? data.visitId.value : this.visitId,
      skuId: data.skuId.present ? data.skuId.value : this.skuId,
      unitsAvailable: data.unitsAvailable.present
          ? data.unitsAvailable.value
          : this.unitsAvailable,
      lastStockinDate: data.lastStockinDate.present
          ? data.lastStockinDate.value
          : this.lastStockinDate,
      daysOutOfStock: data.daysOutOfStock.present
          ? data.daysOutOfStock.value
          : this.daysOutOfStock,
      velocityAvg: data.velocityAvg.present
          ? data.velocityAvg.value
          : this.velocityAvg,
      salesActual: data.salesActual.present
          ? data.salesActual.value
          : this.salesActual,
      salesTarget: data.salesTarget.present
          ? data.salesTarget.value
          : this.salesTarget,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockDraft(')
          ..write('id: $id, ')
          ..write('visitId: $visitId, ')
          ..write('skuId: $skuId, ')
          ..write('unitsAvailable: $unitsAvailable, ')
          ..write('lastStockinDate: $lastStockinDate, ')
          ..write('daysOutOfStock: $daysOutOfStock, ')
          ..write('velocityAvg: $velocityAvg, ')
          ..write('salesActual: $salesActual, ')
          ..write('salesTarget: $salesTarget')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    visitId,
    skuId,
    unitsAvailable,
    lastStockinDate,
    daysOutOfStock,
    velocityAvg,
    salesActual,
    salesTarget,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockDraft &&
          other.id == this.id &&
          other.visitId == this.visitId &&
          other.skuId == this.skuId &&
          other.unitsAvailable == this.unitsAvailable &&
          other.lastStockinDate == this.lastStockinDate &&
          other.daysOutOfStock == this.daysOutOfStock &&
          other.velocityAvg == this.velocityAvg &&
          other.salesActual == this.salesActual &&
          other.salesTarget == this.salesTarget);
}

class StockDraftsCompanion extends UpdateCompanion<StockDraft> {
  final Value<String> id;
  final Value<String> visitId;
  final Value<String> skuId;
  final Value<int> unitsAvailable;
  final Value<DateTime> lastStockinDate;
  final Value<int> daysOutOfStock;
  final Value<double> velocityAvg;
  final Value<double> salesActual;
  final Value<double> salesTarget;
  final Value<int> rowid;
  const StockDraftsCompanion({
    this.id = const Value.absent(),
    this.visitId = const Value.absent(),
    this.skuId = const Value.absent(),
    this.unitsAvailable = const Value.absent(),
    this.lastStockinDate = const Value.absent(),
    this.daysOutOfStock = const Value.absent(),
    this.velocityAvg = const Value.absent(),
    this.salesActual = const Value.absent(),
    this.salesTarget = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockDraftsCompanion.insert({
    required String id,
    required String visitId,
    required String skuId,
    required int unitsAvailable,
    required DateTime lastStockinDate,
    required int daysOutOfStock,
    required double velocityAvg,
    required double salesActual,
    required double salesTarget,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       visitId = Value(visitId),
       skuId = Value(skuId),
       unitsAvailable = Value(unitsAvailable),
       lastStockinDate = Value(lastStockinDate),
       daysOutOfStock = Value(daysOutOfStock),
       velocityAvg = Value(velocityAvg),
       salesActual = Value(salesActual),
       salesTarget = Value(salesTarget);
  static Insertable<StockDraft> custom({
    Expression<String>? id,
    Expression<String>? visitId,
    Expression<String>? skuId,
    Expression<int>? unitsAvailable,
    Expression<DateTime>? lastStockinDate,
    Expression<int>? daysOutOfStock,
    Expression<double>? velocityAvg,
    Expression<double>? salesActual,
    Expression<double>? salesTarget,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (visitId != null) 'visit_id': visitId,
      if (skuId != null) 'sku_id': skuId,
      if (unitsAvailable != null) 'units_available': unitsAvailable,
      if (lastStockinDate != null) 'last_stockin_date': lastStockinDate,
      if (daysOutOfStock != null) 'days_out_of_stock': daysOutOfStock,
      if (velocityAvg != null) 'velocity_avg': velocityAvg,
      if (salesActual != null) 'sales_actual': salesActual,
      if (salesTarget != null) 'sales_target': salesTarget,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockDraftsCompanion copyWith({
    Value<String>? id,
    Value<String>? visitId,
    Value<String>? skuId,
    Value<int>? unitsAvailable,
    Value<DateTime>? lastStockinDate,
    Value<int>? daysOutOfStock,
    Value<double>? velocityAvg,
    Value<double>? salesActual,
    Value<double>? salesTarget,
    Value<int>? rowid,
  }) {
    return StockDraftsCompanion(
      id: id ?? this.id,
      visitId: visitId ?? this.visitId,
      skuId: skuId ?? this.skuId,
      unitsAvailable: unitsAvailable ?? this.unitsAvailable,
      lastStockinDate: lastStockinDate ?? this.lastStockinDate,
      daysOutOfStock: daysOutOfStock ?? this.daysOutOfStock,
      velocityAvg: velocityAvg ?? this.velocityAvg,
      salesActual: salesActual ?? this.salesActual,
      salesTarget: salesTarget ?? this.salesTarget,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (visitId.present) {
      map['visit_id'] = Variable<String>(visitId.value);
    }
    if (skuId.present) {
      map['sku_id'] = Variable<String>(skuId.value);
    }
    if (unitsAvailable.present) {
      map['units_available'] = Variable<int>(unitsAvailable.value);
    }
    if (lastStockinDate.present) {
      map['last_stockin_date'] = Variable<DateTime>(lastStockinDate.value);
    }
    if (daysOutOfStock.present) {
      map['days_out_of_stock'] = Variable<int>(daysOutOfStock.value);
    }
    if (velocityAvg.present) {
      map['velocity_avg'] = Variable<double>(velocityAvg.value);
    }
    if (salesActual.present) {
      map['sales_actual'] = Variable<double>(salesActual.value);
    }
    if (salesTarget.present) {
      map['sales_target'] = Variable<double>(salesTarget.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockDraftsCompanion(')
          ..write('id: $id, ')
          ..write('visitId: $visitId, ')
          ..write('skuId: $skuId, ')
          ..write('unitsAvailable: $unitsAvailable, ')
          ..write('lastStockinDate: $lastStockinDate, ')
          ..write('daysOutOfStock: $daysOutOfStock, ')
          ..write('velocityAvg: $velocityAvg, ')
          ..write('salesActual: $salesActual, ')
          ..write('salesTarget: $salesTarget, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDb extends GeneratedDatabase {
  _$LocalDb(QueryExecutor e) : super(e);
  $LocalDbManager get managers => $LocalDbManager(this);
  late final $VisitDraftsTable visitDrafts = $VisitDraftsTable(this);
  late final $SyncQueueItemsTable syncQueueItems = $SyncQueueItemsTable(this);
  late final $StockDraftsTable stockDrafts = $StockDraftsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    visitDrafts,
    syncQueueItems,
    stockDrafts,
  ];
}

typedef $$VisitDraftsTableCreateCompanionBuilder =
    VisitDraftsCompanion Function({
      required String id,
      required String outletId,
      Value<String> status,
      required DateTime checkinTs,
      required double checkinLat,
      required double checkinLng,
      required bool geofencePass,
      Value<String?> remoteId,
      Value<int> rowid,
    });
typedef $$VisitDraftsTableUpdateCompanionBuilder =
    VisitDraftsCompanion Function({
      Value<String> id,
      Value<String> outletId,
      Value<String> status,
      Value<DateTime> checkinTs,
      Value<double> checkinLat,
      Value<double> checkinLng,
      Value<bool> geofencePass,
      Value<String?> remoteId,
      Value<int> rowid,
    });

class $$VisitDraftsTableFilterComposer
    extends Composer<_$LocalDb, $VisitDraftsTable> {
  $$VisitDraftsTableFilterComposer({
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

  ColumnFilters<String> get outletId => $composableBuilder(
    column: $table.outletId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkinTs => $composableBuilder(
    column: $table.checkinTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get checkinLat => $composableBuilder(
    column: $table.checkinLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get checkinLng => $composableBuilder(
    column: $table.checkinLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get geofencePass => $composableBuilder(
    column: $table.geofencePass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VisitDraftsTableOrderingComposer
    extends Composer<_$LocalDb, $VisitDraftsTable> {
  $$VisitDraftsTableOrderingComposer({
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

  ColumnOrderings<String> get outletId => $composableBuilder(
    column: $table.outletId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkinTs => $composableBuilder(
    column: $table.checkinTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get checkinLat => $composableBuilder(
    column: $table.checkinLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get checkinLng => $composableBuilder(
    column: $table.checkinLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get geofencePass => $composableBuilder(
    column: $table.geofencePass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VisitDraftsTableAnnotationComposer
    extends Composer<_$LocalDb, $VisitDraftsTable> {
  $$VisitDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get outletId =>
      $composableBuilder(column: $table.outletId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get checkinTs =>
      $composableBuilder(column: $table.checkinTs, builder: (column) => column);

  GeneratedColumn<double> get checkinLat => $composableBuilder(
    column: $table.checkinLat,
    builder: (column) => column,
  );

  GeneratedColumn<double> get checkinLng => $composableBuilder(
    column: $table.checkinLng,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get geofencePass => $composableBuilder(
    column: $table.geofencePass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);
}

class $$VisitDraftsTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $VisitDraftsTable,
          VisitDraft,
          $$VisitDraftsTableFilterComposer,
          $$VisitDraftsTableOrderingComposer,
          $$VisitDraftsTableAnnotationComposer,
          $$VisitDraftsTableCreateCompanionBuilder,
          $$VisitDraftsTableUpdateCompanionBuilder,
          (
            VisitDraft,
            BaseReferences<_$LocalDb, $VisitDraftsTable, VisitDraft>,
          ),
          VisitDraft,
          PrefetchHooks Function()
        > {
  $$VisitDraftsTableTableManager(_$LocalDb db, $VisitDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> outletId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> checkinTs = const Value.absent(),
                Value<double> checkinLat = const Value.absent(),
                Value<double> checkinLng = const Value.absent(),
                Value<bool> geofencePass = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitDraftsCompanion(
                id: id,
                outletId: outletId,
                status: status,
                checkinTs: checkinTs,
                checkinLat: checkinLat,
                checkinLng: checkinLng,
                geofencePass: geofencePass,
                remoteId: remoteId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String outletId,
                Value<String> status = const Value.absent(),
                required DateTime checkinTs,
                required double checkinLat,
                required double checkinLng,
                required bool geofencePass,
                Value<String?> remoteId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitDraftsCompanion.insert(
                id: id,
                outletId: outletId,
                status: status,
                checkinTs: checkinTs,
                checkinLat: checkinLat,
                checkinLng: checkinLng,
                geofencePass: geofencePass,
                remoteId: remoteId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VisitDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $VisitDraftsTable,
      VisitDraft,
      $$VisitDraftsTableFilterComposer,
      $$VisitDraftsTableOrderingComposer,
      $$VisitDraftsTableAnnotationComposer,
      $$VisitDraftsTableCreateCompanionBuilder,
      $$VisitDraftsTableUpdateCompanionBuilder,
      (VisitDraft, BaseReferences<_$LocalDb, $VisitDraftsTable, VisitDraft>),
      VisitDraft,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueItemsTableCreateCompanionBuilder =
    SyncQueueItemsCompanion Function({
      Value<int> id,
      required String entityType,
      required String entityId,
      required String payloadJson,
      Value<DateTime> queuedAt,
      Value<bool> synced,
    });
typedef $$SyncQueueItemsTableUpdateCompanionBuilder =
    SyncQueueItemsCompanion Function({
      Value<int> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> payloadJson,
      Value<DateTime> queuedAt,
      Value<bool> synced,
    });

class $$SyncQueueItemsTableFilterComposer
    extends Composer<_$LocalDb, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableFilterComposer({
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

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueItemsTableOrderingComposer
    extends Composer<_$LocalDb, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableOrderingComposer({
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

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueItemsTableAnnotationComposer
    extends Composer<_$LocalDb, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$SyncQueueItemsTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $SyncQueueItemsTable,
          SyncQueueItem,
          $$SyncQueueItemsTableFilterComposer,
          $$SyncQueueItemsTableOrderingComposer,
          $$SyncQueueItemsTableAnnotationComposer,
          $$SyncQueueItemsTableCreateCompanionBuilder,
          $$SyncQueueItemsTableUpdateCompanionBuilder,
          (
            SyncQueueItem,
            BaseReferences<_$LocalDb, $SyncQueueItemsTable, SyncQueueItem>,
          ),
          SyncQueueItem,
          PrefetchHooks Function()
        > {
  $$SyncQueueItemsTableTableManager(_$LocalDb db, $SyncQueueItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
              }) => SyncQueueItemsCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                payloadJson: payloadJson,
                queuedAt: queuedAt,
                synced: synced,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityType,
                required String entityId,
                required String payloadJson,
                Value<DateTime> queuedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
              }) => SyncQueueItemsCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                payloadJson: payloadJson,
                queuedAt: queuedAt,
                synced: synced,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $SyncQueueItemsTable,
      SyncQueueItem,
      $$SyncQueueItemsTableFilterComposer,
      $$SyncQueueItemsTableOrderingComposer,
      $$SyncQueueItemsTableAnnotationComposer,
      $$SyncQueueItemsTableCreateCompanionBuilder,
      $$SyncQueueItemsTableUpdateCompanionBuilder,
      (
        SyncQueueItem,
        BaseReferences<_$LocalDb, $SyncQueueItemsTable, SyncQueueItem>,
      ),
      SyncQueueItem,
      PrefetchHooks Function()
    >;
typedef $$StockDraftsTableCreateCompanionBuilder =
    StockDraftsCompanion Function({
      required String id,
      required String visitId,
      required String skuId,
      required int unitsAvailable,
      required DateTime lastStockinDate,
      required int daysOutOfStock,
      required double velocityAvg,
      required double salesActual,
      required double salesTarget,
      Value<int> rowid,
    });
typedef $$StockDraftsTableUpdateCompanionBuilder =
    StockDraftsCompanion Function({
      Value<String> id,
      Value<String> visitId,
      Value<String> skuId,
      Value<int> unitsAvailable,
      Value<DateTime> lastStockinDate,
      Value<int> daysOutOfStock,
      Value<double> velocityAvg,
      Value<double> salesActual,
      Value<double> salesTarget,
      Value<int> rowid,
    });

class $$StockDraftsTableFilterComposer
    extends Composer<_$LocalDb, $StockDraftsTable> {
  $$StockDraftsTableFilterComposer({
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

  ColumnFilters<String> get visitId => $composableBuilder(
    column: $table.visitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skuId => $composableBuilder(
    column: $table.skuId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitsAvailable => $composableBuilder(
    column: $table.unitsAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastStockinDate => $composableBuilder(
    column: $table.lastStockinDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get daysOutOfStock => $composableBuilder(
    column: $table.daysOutOfStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get velocityAvg => $composableBuilder(
    column: $table.velocityAvg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get salesActual => $composableBuilder(
    column: $table.salesActual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get salesTarget => $composableBuilder(
    column: $table.salesTarget,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StockDraftsTableOrderingComposer
    extends Composer<_$LocalDb, $StockDraftsTable> {
  $$StockDraftsTableOrderingComposer({
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

  ColumnOrderings<String> get visitId => $composableBuilder(
    column: $table.visitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skuId => $composableBuilder(
    column: $table.skuId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitsAvailable => $composableBuilder(
    column: $table.unitsAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastStockinDate => $composableBuilder(
    column: $table.lastStockinDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get daysOutOfStock => $composableBuilder(
    column: $table.daysOutOfStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get velocityAvg => $composableBuilder(
    column: $table.velocityAvg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get salesActual => $composableBuilder(
    column: $table.salesActual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get salesTarget => $composableBuilder(
    column: $table.salesTarget,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StockDraftsTableAnnotationComposer
    extends Composer<_$LocalDb, $StockDraftsTable> {
  $$StockDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get visitId =>
      $composableBuilder(column: $table.visitId, builder: (column) => column);

  GeneratedColumn<String> get skuId =>
      $composableBuilder(column: $table.skuId, builder: (column) => column);

  GeneratedColumn<int> get unitsAvailable => $composableBuilder(
    column: $table.unitsAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastStockinDate => $composableBuilder(
    column: $table.lastStockinDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get daysOutOfStock => $composableBuilder(
    column: $table.daysOutOfStock,
    builder: (column) => column,
  );

  GeneratedColumn<double> get velocityAvg => $composableBuilder(
    column: $table.velocityAvg,
    builder: (column) => column,
  );

  GeneratedColumn<double> get salesActual => $composableBuilder(
    column: $table.salesActual,
    builder: (column) => column,
  );

  GeneratedColumn<double> get salesTarget => $composableBuilder(
    column: $table.salesTarget,
    builder: (column) => column,
  );
}

class $$StockDraftsTableTableManager
    extends
        RootTableManager<
          _$LocalDb,
          $StockDraftsTable,
          StockDraft,
          $$StockDraftsTableFilterComposer,
          $$StockDraftsTableOrderingComposer,
          $$StockDraftsTableAnnotationComposer,
          $$StockDraftsTableCreateCompanionBuilder,
          $$StockDraftsTableUpdateCompanionBuilder,
          (
            StockDraft,
            BaseReferences<_$LocalDb, $StockDraftsTable, StockDraft>,
          ),
          StockDraft,
          PrefetchHooks Function()
        > {
  $$StockDraftsTableTableManager(_$LocalDb db, $StockDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> visitId = const Value.absent(),
                Value<String> skuId = const Value.absent(),
                Value<int> unitsAvailable = const Value.absent(),
                Value<DateTime> lastStockinDate = const Value.absent(),
                Value<int> daysOutOfStock = const Value.absent(),
                Value<double> velocityAvg = const Value.absent(),
                Value<double> salesActual = const Value.absent(),
                Value<double> salesTarget = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StockDraftsCompanion(
                id: id,
                visitId: visitId,
                skuId: skuId,
                unitsAvailable: unitsAvailable,
                lastStockinDate: lastStockinDate,
                daysOutOfStock: daysOutOfStock,
                velocityAvg: velocityAvg,
                salesActual: salesActual,
                salesTarget: salesTarget,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String visitId,
                required String skuId,
                required int unitsAvailable,
                required DateTime lastStockinDate,
                required int daysOutOfStock,
                required double velocityAvg,
                required double salesActual,
                required double salesTarget,
                Value<int> rowid = const Value.absent(),
              }) => StockDraftsCompanion.insert(
                id: id,
                visitId: visitId,
                skuId: skuId,
                unitsAvailable: unitsAvailable,
                lastStockinDate: lastStockinDate,
                daysOutOfStock: daysOutOfStock,
                velocityAvg: velocityAvg,
                salesActual: salesActual,
                salesTarget: salesTarget,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StockDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDb,
      $StockDraftsTable,
      StockDraft,
      $$StockDraftsTableFilterComposer,
      $$StockDraftsTableOrderingComposer,
      $$StockDraftsTableAnnotationComposer,
      $$StockDraftsTableCreateCompanionBuilder,
      $$StockDraftsTableUpdateCompanionBuilder,
      (StockDraft, BaseReferences<_$LocalDb, $StockDraftsTable, StockDraft>),
      StockDraft,
      PrefetchHooks Function()
    >;

class $LocalDbManager {
  final _$LocalDb _db;
  $LocalDbManager(this._db);
  $$VisitDraftsTableTableManager get visitDrafts =>
      $$VisitDraftsTableTableManager(_db, _db.visitDrafts);
  $$SyncQueueItemsTableTableManager get syncQueueItems =>
      $$SyncQueueItemsTableTableManager(_db, _db.syncQueueItems);
  $$StockDraftsTableTableManager get stockDrafts =>
      $$StockDraftsTableTableManager(_db, _db.stockDrafts);
}
