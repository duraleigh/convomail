// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
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
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const Setting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Setting copyWith({String? key, String? value, DateTime? updatedAt}) =>
      Setting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
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
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imapHostMeta = const VerificationMeta(
    'imapHost',
  );
  @override
  late final GeneratedColumn<String> imapHost = GeneratedColumn<String>(
    'imap_host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imapPortMeta = const VerificationMeta(
    'imapPort',
  );
  @override
  late final GeneratedColumn<int> imapPort = GeneratedColumn<int>(
    'imap_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imapSecurityMeta = const VerificationMeta(
    'imapSecurity',
  );
  @override
  late final GeneratedColumn<String> imapSecurity = GeneratedColumn<String>(
    'imap_security',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _smtpHostMeta = const VerificationMeta(
    'smtpHost',
  );
  @override
  late final GeneratedColumn<String> smtpHost = GeneratedColumn<String>(
    'smtp_host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _smtpPortMeta = const VerificationMeta(
    'smtpPort',
  );
  @override
  late final GeneratedColumn<int> smtpPort = GeneratedColumn<int>(
    'smtp_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _smtpSecurityMeta = const VerificationMeta(
    'smtpSecurity',
  );
  @override
  late final GeneratedColumn<String> smtpSecurity = GeneratedColumn<String>(
    'smtp_security',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authMethodMeta = const VerificationMeta(
    'authMethod',
  );
  @override
  late final GeneratedColumn<String> authMethod = GeneratedColumn<String>(
    'auth_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('password'),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('custom'),
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
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    displayName,
    imapHost,
    imapPort,
    imapSecurity,
    smtpHost,
    smtpPort,
    smtpSecurity,
    username,
    authMethod,
    providerId,
    enabled,
    sortOrder,
    createdAt,
    lastSyncAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('imap_host')) {
      context.handle(
        _imapHostMeta,
        imapHost.isAcceptableOrUnknown(data['imap_host']!, _imapHostMeta),
      );
    } else if (isInserting) {
      context.missing(_imapHostMeta);
    }
    if (data.containsKey('imap_port')) {
      context.handle(
        _imapPortMeta,
        imapPort.isAcceptableOrUnknown(data['imap_port']!, _imapPortMeta),
      );
    } else if (isInserting) {
      context.missing(_imapPortMeta);
    }
    if (data.containsKey('imap_security')) {
      context.handle(
        _imapSecurityMeta,
        imapSecurity.isAcceptableOrUnknown(
          data['imap_security']!,
          _imapSecurityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_imapSecurityMeta);
    }
    if (data.containsKey('smtp_host')) {
      context.handle(
        _smtpHostMeta,
        smtpHost.isAcceptableOrUnknown(data['smtp_host']!, _smtpHostMeta),
      );
    } else if (isInserting) {
      context.missing(_smtpHostMeta);
    }
    if (data.containsKey('smtp_port')) {
      context.handle(
        _smtpPortMeta,
        smtpPort.isAcceptableOrUnknown(data['smtp_port']!, _smtpPortMeta),
      );
    } else if (isInserting) {
      context.missing(_smtpPortMeta);
    }
    if (data.containsKey('smtp_security')) {
      context.handle(
        _smtpSecurityMeta,
        smtpSecurity.isAcceptableOrUnknown(
          data['smtp_security']!,
          _smtpSecurityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_smtpSecurityMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('auth_method')) {
      context.handle(
        _authMethodMeta,
        authMethod.isAcceptableOrUnknown(data['auth_method']!, _authMethodMeta),
      );
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      imapHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imap_host'],
      )!,
      imapPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imap_port'],
      )!,
      imapSecurity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}imap_security'],
      )!,
      smtpHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_host'],
      )!,
      smtpPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}smtp_port'],
      )!,
      smtpSecurity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_security'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      authMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_method'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final int id;
  final String email;
  final String displayName;
  final String imapHost;
  final int imapPort;

  /// 'ssl' | 'starttls' | 'none'
  final String imapSecurity;
  final String smtpHost;
  final int smtpPort;
  final String smtpSecurity;
  final String username;

  /// 'password' | 'oauth2'
  final String authMethod;
  final String providerId;
  final bool enabled;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? lastSyncAt;
  final String? lastError;
  const Account({
    required this.id,
    required this.email,
    required this.displayName,
    required this.imapHost,
    required this.imapPort,
    required this.imapSecurity,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpSecurity,
    required this.username,
    required this.authMethod,
    required this.providerId,
    required this.enabled,
    required this.sortOrder,
    required this.createdAt,
    this.lastSyncAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['email'] = Variable<String>(email);
    map['display_name'] = Variable<String>(displayName);
    map['imap_host'] = Variable<String>(imapHost);
    map['imap_port'] = Variable<int>(imapPort);
    map['imap_security'] = Variable<String>(imapSecurity);
    map['smtp_host'] = Variable<String>(smtpHost);
    map['smtp_port'] = Variable<int>(smtpPort);
    map['smtp_security'] = Variable<String>(smtpSecurity);
    map['username'] = Variable<String>(username);
    map['auth_method'] = Variable<String>(authMethod);
    map['provider_id'] = Variable<String>(providerId);
    map['enabled'] = Variable<bool>(enabled);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      email: Value(email),
      displayName: Value(displayName),
      imapHost: Value(imapHost),
      imapPort: Value(imapPort),
      imapSecurity: Value(imapSecurity),
      smtpHost: Value(smtpHost),
      smtpPort: Value(smtpPort),
      smtpSecurity: Value(smtpSecurity),
      username: Value(username),
      authMethod: Value(authMethod),
      providerId: Value(providerId),
      enabled: Value(enabled),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<int>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      displayName: serializer.fromJson<String>(json['displayName']),
      imapHost: serializer.fromJson<String>(json['imapHost']),
      imapPort: serializer.fromJson<int>(json['imapPort']),
      imapSecurity: serializer.fromJson<String>(json['imapSecurity']),
      smtpHost: serializer.fromJson<String>(json['smtpHost']),
      smtpPort: serializer.fromJson<int>(json['smtpPort']),
      smtpSecurity: serializer.fromJson<String>(json['smtpSecurity']),
      username: serializer.fromJson<String>(json['username']),
      authMethod: serializer.fromJson<String>(json['authMethod']),
      providerId: serializer.fromJson<String>(json['providerId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'email': serializer.toJson<String>(email),
      'displayName': serializer.toJson<String>(displayName),
      'imapHost': serializer.toJson<String>(imapHost),
      'imapPort': serializer.toJson<int>(imapPort),
      'imapSecurity': serializer.toJson<String>(imapSecurity),
      'smtpHost': serializer.toJson<String>(smtpHost),
      'smtpPort': serializer.toJson<int>(smtpPort),
      'smtpSecurity': serializer.toJson<String>(smtpSecurity),
      'username': serializer.toJson<String>(username),
      'authMethod': serializer.toJson<String>(authMethod),
      'providerId': serializer.toJson<String>(providerId),
      'enabled': serializer.toJson<bool>(enabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  Account copyWith({
    int? id,
    String? email,
    String? displayName,
    String? imapHost,
    int? imapPort,
    String? imapSecurity,
    String? smtpHost,
    int? smtpPort,
    String? smtpSecurity,
    String? username,
    String? authMethod,
    String? providerId,
    bool? enabled,
    int? sortOrder,
    DateTime? createdAt,
    Value<DateTime?> lastSyncAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => Account(
    id: id ?? this.id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    imapHost: imapHost ?? this.imapHost,
    imapPort: imapPort ?? this.imapPort,
    imapSecurity: imapSecurity ?? this.imapSecurity,
    smtpHost: smtpHost ?? this.smtpHost,
    smtpPort: smtpPort ?? this.smtpPort,
    smtpSecurity: smtpSecurity ?? this.smtpSecurity,
    username: username ?? this.username,
    authMethod: authMethod ?? this.authMethod,
    providerId: providerId ?? this.providerId,
    enabled: enabled ?? this.enabled,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      imapHost: data.imapHost.present ? data.imapHost.value : this.imapHost,
      imapPort: data.imapPort.present ? data.imapPort.value : this.imapPort,
      imapSecurity: data.imapSecurity.present
          ? data.imapSecurity.value
          : this.imapSecurity,
      smtpHost: data.smtpHost.present ? data.smtpHost.value : this.smtpHost,
      smtpPort: data.smtpPort.present ? data.smtpPort.value : this.smtpPort,
      smtpSecurity: data.smtpSecurity.present
          ? data.smtpSecurity.value
          : this.smtpSecurity,
      username: data.username.present ? data.username.value : this.username,
      authMethod: data.authMethod.present
          ? data.authMethod.value
          : this.authMethod,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('imapHost: $imapHost, ')
          ..write('imapPort: $imapPort, ')
          ..write('imapSecurity: $imapSecurity, ')
          ..write('smtpHost: $smtpHost, ')
          ..write('smtpPort: $smtpPort, ')
          ..write('smtpSecurity: $smtpSecurity, ')
          ..write('username: $username, ')
          ..write('authMethod: $authMethod, ')
          ..write('providerId: $providerId, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    email,
    displayName,
    imapHost,
    imapPort,
    imapSecurity,
    smtpHost,
    smtpPort,
    smtpSecurity,
    username,
    authMethod,
    providerId,
    enabled,
    sortOrder,
    createdAt,
    lastSyncAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.imapHost == this.imapHost &&
          other.imapPort == this.imapPort &&
          other.imapSecurity == this.imapSecurity &&
          other.smtpHost == this.smtpHost &&
          other.smtpPort == this.smtpPort &&
          other.smtpSecurity == this.smtpSecurity &&
          other.username == this.username &&
          other.authMethod == this.authMethod &&
          other.providerId == this.providerId &&
          other.enabled == this.enabled &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastError == this.lastError);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> id;
  final Value<String> email;
  final Value<String> displayName;
  final Value<String> imapHost;
  final Value<int> imapPort;
  final Value<String> imapSecurity;
  final Value<String> smtpHost;
  final Value<int> smtpPort;
  final Value<String> smtpSecurity;
  final Value<String> username;
  final Value<String> authMethod;
  final Value<String> providerId;
  final Value<bool> enabled;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastSyncAt;
  final Value<String?> lastError;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.imapHost = const Value.absent(),
    this.imapPort = const Value.absent(),
    this.imapSecurity = const Value.absent(),
    this.smtpHost = const Value.absent(),
    this.smtpPort = const Value.absent(),
    this.smtpSecurity = const Value.absent(),
    this.username = const Value.absent(),
    this.authMethod = const Value.absent(),
    this.providerId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required String email,
    this.displayName = const Value.absent(),
    required String imapHost,
    required int imapPort,
    required String imapSecurity,
    required String smtpHost,
    required int smtpPort,
    required String smtpSecurity,
    required String username,
    this.authMethod = const Value.absent(),
    this.providerId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : email = Value(email),
       imapHost = Value(imapHost),
       imapPort = Value(imapPort),
       imapSecurity = Value(imapSecurity),
       smtpHost = Value(smtpHost),
       smtpPort = Value(smtpPort),
       smtpSecurity = Value(smtpSecurity),
       username = Value(username);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<String>? imapHost,
    Expression<int>? imapPort,
    Expression<String>? imapSecurity,
    Expression<String>? smtpHost,
    Expression<int>? smtpPort,
    Expression<String>? smtpSecurity,
    Expression<String>? username,
    Expression<String>? authMethod,
    Expression<String>? providerId,
    Expression<bool>? enabled,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastSyncAt,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (imapHost != null) 'imap_host': imapHost,
      if (imapPort != null) 'imap_port': imapPort,
      if (imapSecurity != null) 'imap_security': imapSecurity,
      if (smtpHost != null) 'smtp_host': smtpHost,
      if (smtpPort != null) 'smtp_port': smtpPort,
      if (smtpSecurity != null) 'smtp_security': smtpSecurity,
      if (username != null) 'username': username,
      if (authMethod != null) 'auth_method': authMethod,
      if (providerId != null) 'provider_id': providerId,
      if (enabled != null) 'enabled': enabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastError != null) 'last_error': lastError,
    });
  }

  AccountsCompanion copyWith({
    Value<int>? id,
    Value<String>? email,
    Value<String>? displayName,
    Value<String>? imapHost,
    Value<int>? imapPort,
    Value<String>? imapSecurity,
    Value<String>? smtpHost,
    Value<int>? smtpPort,
    Value<String>? smtpSecurity,
    Value<String>? username,
    Value<String>? authMethod,
    Value<String>? providerId,
    Value<bool>? enabled,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastSyncAt,
    Value<String?>? lastError,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      imapHost: imapHost ?? this.imapHost,
      imapPort: imapPort ?? this.imapPort,
      imapSecurity: imapSecurity ?? this.imapSecurity,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpSecurity: smtpSecurity ?? this.smtpSecurity,
      username: username ?? this.username,
      authMethod: authMethod ?? this.authMethod,
      providerId: providerId ?? this.providerId,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (imapHost.present) {
      map['imap_host'] = Variable<String>(imapHost.value);
    }
    if (imapPort.present) {
      map['imap_port'] = Variable<int>(imapPort.value);
    }
    if (imapSecurity.present) {
      map['imap_security'] = Variable<String>(imapSecurity.value);
    }
    if (smtpHost.present) {
      map['smtp_host'] = Variable<String>(smtpHost.value);
    }
    if (smtpPort.present) {
      map['smtp_port'] = Variable<int>(smtpPort.value);
    }
    if (smtpSecurity.present) {
      map['smtp_security'] = Variable<String>(smtpSecurity.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (authMethod.present) {
      map['auth_method'] = Variable<String>(authMethod.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('imapHost: $imapHost, ')
          ..write('imapPort: $imapPort, ')
          ..write('imapSecurity: $imapSecurity, ')
          ..write('smtpHost: $smtpHost, ')
          ..write('smtpPort: $smtpPort, ')
          ..write('smtpSecurity: $smtpSecurity, ')
          ..write('username: $username, ')
          ..write('authMethod: $authMethod, ')
          ..write('providerId: $providerId, ')
          ..write('enabled: $enabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $IdentitiesTable extends Identities
    with TableInfo<$IdentitiesTable, Identity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdentitiesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _smtpHostMeta = const VerificationMeta(
    'smtpHost',
  );
  @override
  late final GeneratedColumn<String> smtpHost = GeneratedColumn<String>(
    'smtp_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _smtpPortMeta = const VerificationMeta(
    'smtpPort',
  );
  @override
  late final GeneratedColumn<int> smtpPort = GeneratedColumn<int>(
    'smtp_port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _smtpSecurityMeta = const VerificationMeta(
    'smtpSecurity',
  );
  @override
  late final GeneratedColumn<String> smtpSecurity = GeneratedColumn<String>(
    'smtp_security',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    email,
    name,
    signature,
    smtpHost,
    smtpPort,
    smtpSecurity,
    isDefault,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Identity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    }
    if (data.containsKey('smtp_host')) {
      context.handle(
        _smtpHostMeta,
        smtpHost.isAcceptableOrUnknown(data['smtp_host']!, _smtpHostMeta),
      );
    }
    if (data.containsKey('smtp_port')) {
      context.handle(
        _smtpPortMeta,
        smtpPort.isAcceptableOrUnknown(data['smtp_port']!, _smtpPortMeta),
      );
    }
    if (data.containsKey('smtp_security')) {
      context.handle(
        _smtpSecurityMeta,
        smtpSecurity.isAcceptableOrUnknown(
          data['smtp_security']!,
          _smtpSecurityMeta,
        ),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Identity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Identity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      smtpHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_host'],
      ),
      smtpPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}smtp_port'],
      ),
      smtpSecurity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_security'],
      ),
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $IdentitiesTable createAlias(String alias) {
    return $IdentitiesTable(attachedDatabase, alias);
  }
}

class Identity extends DataClass implements Insertable<Identity> {
  final int id;
  final int accountId;
  final String email;
  final String name;
  final String signature;
  final String? smtpHost;
  final int? smtpPort;
  final String? smtpSecurity;
  final bool isDefault;
  const Identity({
    required this.id,
    required this.accountId,
    required this.email,
    required this.name,
    required this.signature,
    this.smtpHost,
    this.smtpPort,
    this.smtpSecurity,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['email'] = Variable<String>(email);
    map['name'] = Variable<String>(name);
    map['signature'] = Variable<String>(signature);
    if (!nullToAbsent || smtpHost != null) {
      map['smtp_host'] = Variable<String>(smtpHost);
    }
    if (!nullToAbsent || smtpPort != null) {
      map['smtp_port'] = Variable<int>(smtpPort);
    }
    if (!nullToAbsent || smtpSecurity != null) {
      map['smtp_security'] = Variable<String>(smtpSecurity);
    }
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  IdentitiesCompanion toCompanion(bool nullToAbsent) {
    return IdentitiesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      email: Value(email),
      name: Value(name),
      signature: Value(signature),
      smtpHost: smtpHost == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpHost),
      smtpPort: smtpPort == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpPort),
      smtpSecurity: smtpSecurity == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpSecurity),
      isDefault: Value(isDefault),
    );
  }

  factory Identity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Identity(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      email: serializer.fromJson<String>(json['email']),
      name: serializer.fromJson<String>(json['name']),
      signature: serializer.fromJson<String>(json['signature']),
      smtpHost: serializer.fromJson<String?>(json['smtpHost']),
      smtpPort: serializer.fromJson<int?>(json['smtpPort']),
      smtpSecurity: serializer.fromJson<String?>(json['smtpSecurity']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'email': serializer.toJson<String>(email),
      'name': serializer.toJson<String>(name),
      'signature': serializer.toJson<String>(signature),
      'smtpHost': serializer.toJson<String?>(smtpHost),
      'smtpPort': serializer.toJson<int?>(smtpPort),
      'smtpSecurity': serializer.toJson<String?>(smtpSecurity),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  Identity copyWith({
    int? id,
    int? accountId,
    String? email,
    String? name,
    String? signature,
    Value<String?> smtpHost = const Value.absent(),
    Value<int?> smtpPort = const Value.absent(),
    Value<String?> smtpSecurity = const Value.absent(),
    bool? isDefault,
  }) => Identity(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    email: email ?? this.email,
    name: name ?? this.name,
    signature: signature ?? this.signature,
    smtpHost: smtpHost.present ? smtpHost.value : this.smtpHost,
    smtpPort: smtpPort.present ? smtpPort.value : this.smtpPort,
    smtpSecurity: smtpSecurity.present ? smtpSecurity.value : this.smtpSecurity,
    isDefault: isDefault ?? this.isDefault,
  );
  Identity copyWithCompanion(IdentitiesCompanion data) {
    return Identity(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      email: data.email.present ? data.email.value : this.email,
      name: data.name.present ? data.name.value : this.name,
      signature: data.signature.present ? data.signature.value : this.signature,
      smtpHost: data.smtpHost.present ? data.smtpHost.value : this.smtpHost,
      smtpPort: data.smtpPort.present ? data.smtpPort.value : this.smtpPort,
      smtpSecurity: data.smtpSecurity.present
          ? data.smtpSecurity.value
          : this.smtpSecurity,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Identity(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('email: $email, ')
          ..write('name: $name, ')
          ..write('signature: $signature, ')
          ..write('smtpHost: $smtpHost, ')
          ..write('smtpPort: $smtpPort, ')
          ..write('smtpSecurity: $smtpSecurity, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    email,
    name,
    signature,
    smtpHost,
    smtpPort,
    smtpSecurity,
    isDefault,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Identity &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.email == this.email &&
          other.name == this.name &&
          other.signature == this.signature &&
          other.smtpHost == this.smtpHost &&
          other.smtpPort == this.smtpPort &&
          other.smtpSecurity == this.smtpSecurity &&
          other.isDefault == this.isDefault);
}

class IdentitiesCompanion extends UpdateCompanion<Identity> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<String> email;
  final Value<String> name;
  final Value<String> signature;
  final Value<String?> smtpHost;
  final Value<int?> smtpPort;
  final Value<String?> smtpSecurity;
  final Value<bool> isDefault;
  const IdentitiesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.email = const Value.absent(),
    this.name = const Value.absent(),
    this.signature = const Value.absent(),
    this.smtpHost = const Value.absent(),
    this.smtpPort = const Value.absent(),
    this.smtpSecurity = const Value.absent(),
    this.isDefault = const Value.absent(),
  });
  IdentitiesCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required String email,
    this.name = const Value.absent(),
    this.signature = const Value.absent(),
    this.smtpHost = const Value.absent(),
    this.smtpPort = const Value.absent(),
    this.smtpSecurity = const Value.absent(),
    this.isDefault = const Value.absent(),
  }) : accountId = Value(accountId),
       email = Value(email);
  static Insertable<Identity> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<String>? email,
    Expression<String>? name,
    Expression<String>? signature,
    Expression<String>? smtpHost,
    Expression<int>? smtpPort,
    Expression<String>? smtpSecurity,
    Expression<bool>? isDefault,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
      if (signature != null) 'signature': signature,
      if (smtpHost != null) 'smtp_host': smtpHost,
      if (smtpPort != null) 'smtp_port': smtpPort,
      if (smtpSecurity != null) 'smtp_security': smtpSecurity,
      if (isDefault != null) 'is_default': isDefault,
    });
  }

  IdentitiesCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<String>? email,
    Value<String>? name,
    Value<String>? signature,
    Value<String?>? smtpHost,
    Value<int?>? smtpPort,
    Value<String?>? smtpSecurity,
    Value<bool>? isDefault,
  }) {
    return IdentitiesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      email: email ?? this.email,
      name: name ?? this.name,
      signature: signature ?? this.signature,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpSecurity: smtpSecurity ?? this.smtpSecurity,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (smtpHost.present) {
      map['smtp_host'] = Variable<String>(smtpHost.value);
    }
    if (smtpPort.present) {
      map['smtp_port'] = Variable<int>(smtpPort.value);
    }
    if (smtpSecurity.present) {
      map['smtp_security'] = Variable<String>(smtpSecurity.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdentitiesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('email: $email, ')
          ..write('name: $name, ')
          ..write('signature: $signature, ')
          ..write('smtpHost: $smtpHost, ')
          ..write('smtpPort: $smtpPort, ')
          ..write('smtpSecurity: $smtpSecurity, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _selectableMeta = const VerificationMeta(
    'selectable',
  );
  @override
  late final GeneratedColumn<bool> selectable = GeneratedColumn<bool>(
    'selectable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("selectable" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _uidValidityMeta = const VerificationMeta(
    'uidValidity',
  );
  @override
  late final GeneratedColumn<int> uidValidity = GeneratedColumn<int>(
    'uid_validity',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uidNextMeta = const VerificationMeta(
    'uidNext',
  );
  @override
  late final GeneratedColumn<int> uidNext = GeneratedColumn<int>(
    'uid_next',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highestModSeqMeta = const VerificationMeta(
    'highestModSeq',
  );
  @override
  late final GeneratedColumn<int> highestModSeq = GeneratedColumn<int>(
    'highest_mod_seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedUidMeta = const VerificationMeta(
    'lastSyncedUid',
  );
  @override
  late final GeneratedColumn<int> lastSyncedUid = GeneratedColumn<int>(
    'last_synced_uid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _messagesExistsMeta = const VerificationMeta(
    'messagesExists',
  );
  @override
  late final GeneratedColumn<int> messagesExists = GeneratedColumn<int>(
    'messages_exists',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    path,
    name,
    role,
    selectable,
    uidValidity,
    uidNext,
    highestModSeq,
    lastSyncedUid,
    messagesExists,
    lastSyncAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('selectable')) {
      context.handle(
        _selectableMeta,
        selectable.isAcceptableOrUnknown(data['selectable']!, _selectableMeta),
      );
    }
    if (data.containsKey('uid_validity')) {
      context.handle(
        _uidValidityMeta,
        uidValidity.isAcceptableOrUnknown(
          data['uid_validity']!,
          _uidValidityMeta,
        ),
      );
    }
    if (data.containsKey('uid_next')) {
      context.handle(
        _uidNextMeta,
        uidNext.isAcceptableOrUnknown(data['uid_next']!, _uidNextMeta),
      );
    }
    if (data.containsKey('highest_mod_seq')) {
      context.handle(
        _highestModSeqMeta,
        highestModSeq.isAcceptableOrUnknown(
          data['highest_mod_seq']!,
          _highestModSeqMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_uid')) {
      context.handle(
        _lastSyncedUidMeta,
        lastSyncedUid.isAcceptableOrUnknown(
          data['last_synced_uid']!,
          _lastSyncedUidMeta,
        ),
      );
    }
    if (data.containsKey('messages_exists')) {
      context.handle(
        _messagesExistsMeta,
        messagesExists.isAcceptableOrUnknown(
          data['messages_exists']!,
          _messagesExistsMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountId, path},
  ];
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      selectable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}selectable'],
      )!,
      uidValidity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uid_validity'],
      ),
      uidNext: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uid_next'],
      ),
      highestModSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}highest_mod_seq'],
      ),
      lastSyncedUid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_uid'],
      )!,
      messagesExists: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}messages_exists'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      ),
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final int id;
  final int accountId;
  final String path;
  final String name;

  /// 'inbox' | 'sent' | 'drafts' | 'trash' | 'junk' | 'archive' | 'other'
  final String role;
  final bool selectable;
  final int? uidValidity;
  final int? uidNext;
  final int? highestModSeq;

  /// Highest UID whose headers we have stored; incremental sync fetches above it.
  final int lastSyncedUid;
  final int messagesExists;
  final DateTime? lastSyncAt;
  const Folder({
    required this.id,
    required this.accountId,
    required this.path,
    required this.name,
    required this.role,
    required this.selectable,
    this.uidValidity,
    this.uidNext,
    this.highestModSeq,
    required this.lastSyncedUid,
    required this.messagesExists,
    this.lastSyncAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['path'] = Variable<String>(path);
    map['name'] = Variable<String>(name);
    map['role'] = Variable<String>(role);
    map['selectable'] = Variable<bool>(selectable);
    if (!nullToAbsent || uidValidity != null) {
      map['uid_validity'] = Variable<int>(uidValidity);
    }
    if (!nullToAbsent || uidNext != null) {
      map['uid_next'] = Variable<int>(uidNext);
    }
    if (!nullToAbsent || highestModSeq != null) {
      map['highest_mod_seq'] = Variable<int>(highestModSeq);
    }
    map['last_synced_uid'] = Variable<int>(lastSyncedUid);
    map['messages_exists'] = Variable<int>(messagesExists);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      accountId: Value(accountId),
      path: Value(path),
      name: Value(name),
      role: Value(role),
      selectable: Value(selectable),
      uidValidity: uidValidity == null && nullToAbsent
          ? const Value.absent()
          : Value(uidValidity),
      uidNext: uidNext == null && nullToAbsent
          ? const Value.absent()
          : Value(uidNext),
      highestModSeq: highestModSeq == null && nullToAbsent
          ? const Value.absent()
          : Value(highestModSeq),
      lastSyncedUid: Value(lastSyncedUid),
      messagesExists: Value(messagesExists),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      path: serializer.fromJson<String>(json['path']),
      name: serializer.fromJson<String>(json['name']),
      role: serializer.fromJson<String>(json['role']),
      selectable: serializer.fromJson<bool>(json['selectable']),
      uidValidity: serializer.fromJson<int?>(json['uidValidity']),
      uidNext: serializer.fromJson<int?>(json['uidNext']),
      highestModSeq: serializer.fromJson<int?>(json['highestModSeq']),
      lastSyncedUid: serializer.fromJson<int>(json['lastSyncedUid']),
      messagesExists: serializer.fromJson<int>(json['messagesExists']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'path': serializer.toJson<String>(path),
      'name': serializer.toJson<String>(name),
      'role': serializer.toJson<String>(role),
      'selectable': serializer.toJson<bool>(selectable),
      'uidValidity': serializer.toJson<int?>(uidValidity),
      'uidNext': serializer.toJson<int?>(uidNext),
      'highestModSeq': serializer.toJson<int?>(highestModSeq),
      'lastSyncedUid': serializer.toJson<int>(lastSyncedUid),
      'messagesExists': serializer.toJson<int>(messagesExists),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
    };
  }

  Folder copyWith({
    int? id,
    int? accountId,
    String? path,
    String? name,
    String? role,
    bool? selectable,
    Value<int?> uidValidity = const Value.absent(),
    Value<int?> uidNext = const Value.absent(),
    Value<int?> highestModSeq = const Value.absent(),
    int? lastSyncedUid,
    int? messagesExists,
    Value<DateTime?> lastSyncAt = const Value.absent(),
  }) => Folder(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    path: path ?? this.path,
    name: name ?? this.name,
    role: role ?? this.role,
    selectable: selectable ?? this.selectable,
    uidValidity: uidValidity.present ? uidValidity.value : this.uidValidity,
    uidNext: uidNext.present ? uidNext.value : this.uidNext,
    highestModSeq: highestModSeq.present
        ? highestModSeq.value
        : this.highestModSeq,
    lastSyncedUid: lastSyncedUid ?? this.lastSyncedUid,
    messagesExists: messagesExists ?? this.messagesExists,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      path: data.path.present ? data.path.value : this.path,
      name: data.name.present ? data.name.value : this.name,
      role: data.role.present ? data.role.value : this.role,
      selectable: data.selectable.present
          ? data.selectable.value
          : this.selectable,
      uidValidity: data.uidValidity.present
          ? data.uidValidity.value
          : this.uidValidity,
      uidNext: data.uidNext.present ? data.uidNext.value : this.uidNext,
      highestModSeq: data.highestModSeq.present
          ? data.highestModSeq.value
          : this.highestModSeq,
      lastSyncedUid: data.lastSyncedUid.present
          ? data.lastSyncedUid.value
          : this.lastSyncedUid,
      messagesExists: data.messagesExists.present
          ? data.messagesExists.value
          : this.messagesExists,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('role: $role, ')
          ..write('selectable: $selectable, ')
          ..write('uidValidity: $uidValidity, ')
          ..write('uidNext: $uidNext, ')
          ..write('highestModSeq: $highestModSeq, ')
          ..write('lastSyncedUid: $lastSyncedUid, ')
          ..write('messagesExists: $messagesExists, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    path,
    name,
    role,
    selectable,
    uidValidity,
    uidNext,
    highestModSeq,
    lastSyncedUid,
    messagesExists,
    lastSyncAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.path == this.path &&
          other.name == this.name &&
          other.role == this.role &&
          other.selectable == this.selectable &&
          other.uidValidity == this.uidValidity &&
          other.uidNext == this.uidNext &&
          other.highestModSeq == this.highestModSeq &&
          other.lastSyncedUid == this.lastSyncedUid &&
          other.messagesExists == this.messagesExists &&
          other.lastSyncAt == this.lastSyncAt);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<String> path;
  final Value<String> name;
  final Value<String> role;
  final Value<bool> selectable;
  final Value<int?> uidValidity;
  final Value<int?> uidNext;
  final Value<int?> highestModSeq;
  final Value<int> lastSyncedUid;
  final Value<int> messagesExists;
  final Value<DateTime?> lastSyncAt;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.role = const Value.absent(),
    this.selectable = const Value.absent(),
    this.uidValidity = const Value.absent(),
    this.uidNext = const Value.absent(),
    this.highestModSeq = const Value.absent(),
    this.lastSyncedUid = const Value.absent(),
    this.messagesExists = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
  });
  FoldersCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required String path,
    required String name,
    this.role = const Value.absent(),
    this.selectable = const Value.absent(),
    this.uidValidity = const Value.absent(),
    this.uidNext = const Value.absent(),
    this.highestModSeq = const Value.absent(),
    this.lastSyncedUid = const Value.absent(),
    this.messagesExists = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
  }) : accountId = Value(accountId),
       path = Value(path),
       name = Value(name);
  static Insertable<Folder> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<String>? path,
    Expression<String>? name,
    Expression<String>? role,
    Expression<bool>? selectable,
    Expression<int>? uidValidity,
    Expression<int>? uidNext,
    Expression<int>? highestModSeq,
    Expression<int>? lastSyncedUid,
    Expression<int>? messagesExists,
    Expression<DateTime>? lastSyncAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (path != null) 'path': path,
      if (name != null) 'name': name,
      if (role != null) 'role': role,
      if (selectable != null) 'selectable': selectable,
      if (uidValidity != null) 'uid_validity': uidValidity,
      if (uidNext != null) 'uid_next': uidNext,
      if (highestModSeq != null) 'highest_mod_seq': highestModSeq,
      if (lastSyncedUid != null) 'last_synced_uid': lastSyncedUid,
      if (messagesExists != null) 'messages_exists': messagesExists,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
    });
  }

  FoldersCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<String>? path,
    Value<String>? name,
    Value<String>? role,
    Value<bool>? selectable,
    Value<int?>? uidValidity,
    Value<int?>? uidNext,
    Value<int?>? highestModSeq,
    Value<int>? lastSyncedUid,
    Value<int>? messagesExists,
    Value<DateTime?>? lastSyncAt,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      path: path ?? this.path,
      name: name ?? this.name,
      role: role ?? this.role,
      selectable: selectable ?? this.selectable,
      uidValidity: uidValidity ?? this.uidValidity,
      uidNext: uidNext ?? this.uidNext,
      highestModSeq: highestModSeq ?? this.highestModSeq,
      lastSyncedUid: lastSyncedUid ?? this.lastSyncedUid,
      messagesExists: messagesExists ?? this.messagesExists,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (selectable.present) {
      map['selectable'] = Variable<bool>(selectable.value);
    }
    if (uidValidity.present) {
      map['uid_validity'] = Variable<int>(uidValidity.value);
    }
    if (uidNext.present) {
      map['uid_next'] = Variable<int>(uidNext.value);
    }
    if (highestModSeq.present) {
      map['highest_mod_seq'] = Variable<int>(highestModSeq.value);
    }
    if (lastSyncedUid.present) {
      map['last_synced_uid'] = Variable<int>(lastSyncedUid.value);
    }
    if (messagesExists.present) {
      map['messages_exists'] = Variable<int>(messagesExists.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('role: $role, ')
          ..write('selectable: $selectable, ')
          ..write('uidValidity: $uidValidity, ')
          ..write('uidNext: $uidNext, ')
          ..write('highestModSeq: $highestModSeq, ')
          ..write('lastSyncedUid: $lastSyncedUid, ')
          ..write('messagesExists: $messagesExists, ')
          ..write('lastSyncAt: $lastSyncAt')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<int> uid = GeneratedColumn<int>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inReplyToMeta = const VerificationMeta(
    'inReplyTo',
  );
  @override
  late final GeneratedColumn<String> inReplyTo = GeneratedColumn<String>(
    'in_reply_to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referencesHeaderMeta = const VerificationMeta(
    'referencesHeader',
  );
  @override
  late final GeneratedColumn<String> referencesHeader = GeneratedColumn<String>(
    'references_header',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fromAddressMeta = const VerificationMeta(
    'fromAddress',
  );
  @override
  late final GeneratedColumn<String> fromAddress = GeneratedColumn<String>(
    'from_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fromNameMeta = const VerificationMeta(
    'fromName',
  );
  @override
  late final GeneratedColumn<String> fromName = GeneratedColumn<String>(
    'from_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fromContactKeyMeta = const VerificationMeta(
    'fromContactKey',
  );
  @override
  late final GeneratedColumn<String> fromContactKey = GeneratedColumn<String>(
    'from_contact_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isFromMeMeta = const VerificationMeta(
    'isFromMe',
  );
  @override
  late final GeneratedColumn<bool> isFromMe = GeneratedColumn<bool>(
    'is_from_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_from_me" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _internalDateMeta = const VerificationMeta(
    'internalDate',
  );
  @override
  late final GeneratedColumn<DateTime> internalDate = GeneratedColumn<DateTime>(
    'internal_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSeenMeta = const VerificationMeta('isSeen');
  @override
  late final GeneratedColumn<bool> isSeen = GeneratedColumn<bool>(
    'is_seen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_seen" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isFlaggedMeta = const VerificationMeta(
    'isFlagged',
  );
  @override
  late final GeneratedColumn<bool> isFlagged = GeneratedColumn<bool>(
    'is_flagged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_flagged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isAnsweredMeta = const VerificationMeta(
    'isAnswered',
  );
  @override
  late final GeneratedColumn<bool> isAnswered = GeneratedColumn<bool>(
    'is_answered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_answered" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDraftMeta = const VerificationMeta(
    'isDraft',
  );
  @override
  late final GeneratedColumn<bool> isDraft = GeneratedColumn<bool>(
    'is_draft',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_draft" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hasAttachmentsMeta = const VerificationMeta(
    'hasAttachments',
  );
  @override
  late final GeneratedColumn<bool> hasAttachments = GeneratedColumn<bool>(
    'has_attachments',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_attachments" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _snippetMeta = const VerificationMeta(
    'snippet',
  );
  @override
  late final GeneratedColumn<String> snippet = GeneratedColumn<String>(
    'snippet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyTextMeta = const VerificationMeta(
    'bodyText',
  );
  @override
  late final GeneratedColumn<String> bodyText = GeneratedColumn<String>(
    'body_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyHtmlMeta = const VerificationMeta(
    'bodyHtml',
  );
  @override
  late final GeneratedColumn<String> bodyHtml = GeneratedColumn<String>(
    'body_html',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyFetchedAtMeta = const VerificationMeta(
    'bodyFetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> bodyFetchedAt =
      GeneratedColumn<DateTime>(
        'body_fetched_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _providerThreadIdMeta = const VerificationMeta(
    'providerThreadId',
  );
  @override
  late final GeneratedColumn<String> providerThreadId = GeneratedColumn<String>(
    'provider_thread_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    folderId,
    uid,
    messageId,
    inReplyTo,
    referencesHeader,
    subject,
    fromAddress,
    fromName,
    fromContactKey,
    isFromMe,
    date,
    internalDate,
    isSeen,
    isFlagged,
    isAnswered,
    isDraft,
    isDeleted,
    size,
    hasAttachments,
    snippet,
    bodyText,
    bodyHtml,
    bodyFetchedAt,
    providerThreadId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    }
    if (data.containsKey('in_reply_to')) {
      context.handle(
        _inReplyToMeta,
        inReplyTo.isAcceptableOrUnknown(data['in_reply_to']!, _inReplyToMeta),
      );
    }
    if (data.containsKey('references_header')) {
      context.handle(
        _referencesHeaderMeta,
        referencesHeader.isAcceptableOrUnknown(
          data['references_header']!,
          _referencesHeaderMeta,
        ),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('from_address')) {
      context.handle(
        _fromAddressMeta,
        fromAddress.isAcceptableOrUnknown(
          data['from_address']!,
          _fromAddressMeta,
        ),
      );
    }
    if (data.containsKey('from_name')) {
      context.handle(
        _fromNameMeta,
        fromName.isAcceptableOrUnknown(data['from_name']!, _fromNameMeta),
      );
    }
    if (data.containsKey('from_contact_key')) {
      context.handle(
        _fromContactKeyMeta,
        fromContactKey.isAcceptableOrUnknown(
          data['from_contact_key']!,
          _fromContactKeyMeta,
        ),
      );
    }
    if (data.containsKey('is_from_me')) {
      context.handle(
        _isFromMeMeta,
        isFromMe.isAcceptableOrUnknown(data['is_from_me']!, _isFromMeMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('internal_date')) {
      context.handle(
        _internalDateMeta,
        internalDate.isAcceptableOrUnknown(
          data['internal_date']!,
          _internalDateMeta,
        ),
      );
    }
    if (data.containsKey('is_seen')) {
      context.handle(
        _isSeenMeta,
        isSeen.isAcceptableOrUnknown(data['is_seen']!, _isSeenMeta),
      );
    }
    if (data.containsKey('is_flagged')) {
      context.handle(
        _isFlaggedMeta,
        isFlagged.isAcceptableOrUnknown(data['is_flagged']!, _isFlaggedMeta),
      );
    }
    if (data.containsKey('is_answered')) {
      context.handle(
        _isAnsweredMeta,
        isAnswered.isAcceptableOrUnknown(data['is_answered']!, _isAnsweredMeta),
      );
    }
    if (data.containsKey('is_draft')) {
      context.handle(
        _isDraftMeta,
        isDraft.isAcceptableOrUnknown(data['is_draft']!, _isDraftMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('has_attachments')) {
      context.handle(
        _hasAttachmentsMeta,
        hasAttachments.isAcceptableOrUnknown(
          data['has_attachments']!,
          _hasAttachmentsMeta,
        ),
      );
    }
    if (data.containsKey('snippet')) {
      context.handle(
        _snippetMeta,
        snippet.isAcceptableOrUnknown(data['snippet']!, _snippetMeta),
      );
    }
    if (data.containsKey('body_text')) {
      context.handle(
        _bodyTextMeta,
        bodyText.isAcceptableOrUnknown(data['body_text']!, _bodyTextMeta),
      );
    }
    if (data.containsKey('body_html')) {
      context.handle(
        _bodyHtmlMeta,
        bodyHtml.isAcceptableOrUnknown(data['body_html']!, _bodyHtmlMeta),
      );
    }
    if (data.containsKey('body_fetched_at')) {
      context.handle(
        _bodyFetchedAtMeta,
        bodyFetchedAt.isAcceptableOrUnknown(
          data['body_fetched_at']!,
          _bodyFetchedAtMeta,
        ),
      );
    }
    if (data.containsKey('provider_thread_id')) {
      context.handle(
        _providerThreadIdMeta,
        providerThreadId.isAcceptableOrUnknown(
          data['provider_thread_id']!,
          _providerThreadIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {folderId, uid},
  ];
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uid'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      ),
      inReplyTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}in_reply_to'],
      ),
      referencesHeader: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}references_header'],
      ),
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      fromAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_address'],
      )!,
      fromName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_name'],
      )!,
      fromContactKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_contact_key'],
      )!,
      isFromMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_from_me'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      ),
      internalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}internal_date'],
      ),
      isSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_seen'],
      )!,
      isFlagged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_flagged'],
      )!,
      isAnswered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_answered'],
      )!,
      isDraft: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_draft'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      hasAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_attachments'],
      )!,
      snippet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snippet'],
      )!,
      bodyText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_text'],
      ),
      bodyHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_html'],
      ),
      bodyFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}body_fetched_at'],
      ),
      providerThreadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_thread_id'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final int accountId;
  final int folderId;
  final int uid;
  final String? messageId;
  final String? inReplyTo;

  /// Space-separated Message-IDs from the References header.
  final String? referencesHeader;
  final String subject;

  /// Normalized sender address (see IdentityResolver.normalize).
  final String fromAddress;
  final String fromName;

  /// Canonical contact key of the sender after identity resolution.
  final String fromContactKey;
  final bool isFromMe;
  final DateTime? date;
  final DateTime? internalDate;
  final bool isSeen;
  final bool isFlagged;
  final bool isAnswered;
  final bool isDraft;
  final bool isDeleted;
  final int size;
  final bool hasAttachments;
  final String snippet;
  final String? bodyText;
  final String? bodyHtml;
  final DateTime? bodyFetchedAt;

  /// Provider thread id (Gmail X-GM-THRID) when available (spec 4.20).
  final String? providerThreadId;
  const Message({
    required this.id,
    required this.accountId,
    required this.folderId,
    required this.uid,
    this.messageId,
    this.inReplyTo,
    this.referencesHeader,
    required this.subject,
    required this.fromAddress,
    required this.fromName,
    required this.fromContactKey,
    required this.isFromMe,
    this.date,
    this.internalDate,
    required this.isSeen,
    required this.isFlagged,
    required this.isAnswered,
    required this.isDraft,
    required this.isDeleted,
    required this.size,
    required this.hasAttachments,
    required this.snippet,
    this.bodyText,
    this.bodyHtml,
    this.bodyFetchedAt,
    this.providerThreadId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['folder_id'] = Variable<int>(folderId);
    map['uid'] = Variable<int>(uid);
    if (!nullToAbsent || messageId != null) {
      map['message_id'] = Variable<String>(messageId);
    }
    if (!nullToAbsent || inReplyTo != null) {
      map['in_reply_to'] = Variable<String>(inReplyTo);
    }
    if (!nullToAbsent || referencesHeader != null) {
      map['references_header'] = Variable<String>(referencesHeader);
    }
    map['subject'] = Variable<String>(subject);
    map['from_address'] = Variable<String>(fromAddress);
    map['from_name'] = Variable<String>(fromName);
    map['from_contact_key'] = Variable<String>(fromContactKey);
    map['is_from_me'] = Variable<bool>(isFromMe);
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<DateTime>(date);
    }
    if (!nullToAbsent || internalDate != null) {
      map['internal_date'] = Variable<DateTime>(internalDate);
    }
    map['is_seen'] = Variable<bool>(isSeen);
    map['is_flagged'] = Variable<bool>(isFlagged);
    map['is_answered'] = Variable<bool>(isAnswered);
    map['is_draft'] = Variable<bool>(isDraft);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['size'] = Variable<int>(size);
    map['has_attachments'] = Variable<bool>(hasAttachments);
    map['snippet'] = Variable<String>(snippet);
    if (!nullToAbsent || bodyText != null) {
      map['body_text'] = Variable<String>(bodyText);
    }
    if (!nullToAbsent || bodyHtml != null) {
      map['body_html'] = Variable<String>(bodyHtml);
    }
    if (!nullToAbsent || bodyFetchedAt != null) {
      map['body_fetched_at'] = Variable<DateTime>(bodyFetchedAt);
    }
    if (!nullToAbsent || providerThreadId != null) {
      map['provider_thread_id'] = Variable<String>(providerThreadId);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      folderId: Value(folderId),
      uid: Value(uid),
      messageId: messageId == null && nullToAbsent
          ? const Value.absent()
          : Value(messageId),
      inReplyTo: inReplyTo == null && nullToAbsent
          ? const Value.absent()
          : Value(inReplyTo),
      referencesHeader: referencesHeader == null && nullToAbsent
          ? const Value.absent()
          : Value(referencesHeader),
      subject: Value(subject),
      fromAddress: Value(fromAddress),
      fromName: Value(fromName),
      fromContactKey: Value(fromContactKey),
      isFromMe: Value(isFromMe),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      internalDate: internalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(internalDate),
      isSeen: Value(isSeen),
      isFlagged: Value(isFlagged),
      isAnswered: Value(isAnswered),
      isDraft: Value(isDraft),
      isDeleted: Value(isDeleted),
      size: Value(size),
      hasAttachments: Value(hasAttachments),
      snippet: Value(snippet),
      bodyText: bodyText == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyText),
      bodyHtml: bodyHtml == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyHtml),
      bodyFetchedAt: bodyFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyFetchedAt),
      providerThreadId: providerThreadId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerThreadId),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      folderId: serializer.fromJson<int>(json['folderId']),
      uid: serializer.fromJson<int>(json['uid']),
      messageId: serializer.fromJson<String?>(json['messageId']),
      inReplyTo: serializer.fromJson<String?>(json['inReplyTo']),
      referencesHeader: serializer.fromJson<String?>(json['referencesHeader']),
      subject: serializer.fromJson<String>(json['subject']),
      fromAddress: serializer.fromJson<String>(json['fromAddress']),
      fromName: serializer.fromJson<String>(json['fromName']),
      fromContactKey: serializer.fromJson<String>(json['fromContactKey']),
      isFromMe: serializer.fromJson<bool>(json['isFromMe']),
      date: serializer.fromJson<DateTime?>(json['date']),
      internalDate: serializer.fromJson<DateTime?>(json['internalDate']),
      isSeen: serializer.fromJson<bool>(json['isSeen']),
      isFlagged: serializer.fromJson<bool>(json['isFlagged']),
      isAnswered: serializer.fromJson<bool>(json['isAnswered']),
      isDraft: serializer.fromJson<bool>(json['isDraft']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      size: serializer.fromJson<int>(json['size']),
      hasAttachments: serializer.fromJson<bool>(json['hasAttachments']),
      snippet: serializer.fromJson<String>(json['snippet']),
      bodyText: serializer.fromJson<String?>(json['bodyText']),
      bodyHtml: serializer.fromJson<String?>(json['bodyHtml']),
      bodyFetchedAt: serializer.fromJson<DateTime?>(json['bodyFetchedAt']),
      providerThreadId: serializer.fromJson<String?>(json['providerThreadId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'folderId': serializer.toJson<int>(folderId),
      'uid': serializer.toJson<int>(uid),
      'messageId': serializer.toJson<String?>(messageId),
      'inReplyTo': serializer.toJson<String?>(inReplyTo),
      'referencesHeader': serializer.toJson<String?>(referencesHeader),
      'subject': serializer.toJson<String>(subject),
      'fromAddress': serializer.toJson<String>(fromAddress),
      'fromName': serializer.toJson<String>(fromName),
      'fromContactKey': serializer.toJson<String>(fromContactKey),
      'isFromMe': serializer.toJson<bool>(isFromMe),
      'date': serializer.toJson<DateTime?>(date),
      'internalDate': serializer.toJson<DateTime?>(internalDate),
      'isSeen': serializer.toJson<bool>(isSeen),
      'isFlagged': serializer.toJson<bool>(isFlagged),
      'isAnswered': serializer.toJson<bool>(isAnswered),
      'isDraft': serializer.toJson<bool>(isDraft),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'size': serializer.toJson<int>(size),
      'hasAttachments': serializer.toJson<bool>(hasAttachments),
      'snippet': serializer.toJson<String>(snippet),
      'bodyText': serializer.toJson<String?>(bodyText),
      'bodyHtml': serializer.toJson<String?>(bodyHtml),
      'bodyFetchedAt': serializer.toJson<DateTime?>(bodyFetchedAt),
      'providerThreadId': serializer.toJson<String?>(providerThreadId),
    };
  }

  Message copyWith({
    int? id,
    int? accountId,
    int? folderId,
    int? uid,
    Value<String?> messageId = const Value.absent(),
    Value<String?> inReplyTo = const Value.absent(),
    Value<String?> referencesHeader = const Value.absent(),
    String? subject,
    String? fromAddress,
    String? fromName,
    String? fromContactKey,
    bool? isFromMe,
    Value<DateTime?> date = const Value.absent(),
    Value<DateTime?> internalDate = const Value.absent(),
    bool? isSeen,
    bool? isFlagged,
    bool? isAnswered,
    bool? isDraft,
    bool? isDeleted,
    int? size,
    bool? hasAttachments,
    String? snippet,
    Value<String?> bodyText = const Value.absent(),
    Value<String?> bodyHtml = const Value.absent(),
    Value<DateTime?> bodyFetchedAt = const Value.absent(),
    Value<String?> providerThreadId = const Value.absent(),
  }) => Message(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    folderId: folderId ?? this.folderId,
    uid: uid ?? this.uid,
    messageId: messageId.present ? messageId.value : this.messageId,
    inReplyTo: inReplyTo.present ? inReplyTo.value : this.inReplyTo,
    referencesHeader: referencesHeader.present
        ? referencesHeader.value
        : this.referencesHeader,
    subject: subject ?? this.subject,
    fromAddress: fromAddress ?? this.fromAddress,
    fromName: fromName ?? this.fromName,
    fromContactKey: fromContactKey ?? this.fromContactKey,
    isFromMe: isFromMe ?? this.isFromMe,
    date: date.present ? date.value : this.date,
    internalDate: internalDate.present ? internalDate.value : this.internalDate,
    isSeen: isSeen ?? this.isSeen,
    isFlagged: isFlagged ?? this.isFlagged,
    isAnswered: isAnswered ?? this.isAnswered,
    isDraft: isDraft ?? this.isDraft,
    isDeleted: isDeleted ?? this.isDeleted,
    size: size ?? this.size,
    hasAttachments: hasAttachments ?? this.hasAttachments,
    snippet: snippet ?? this.snippet,
    bodyText: bodyText.present ? bodyText.value : this.bodyText,
    bodyHtml: bodyHtml.present ? bodyHtml.value : this.bodyHtml,
    bodyFetchedAt: bodyFetchedAt.present
        ? bodyFetchedAt.value
        : this.bodyFetchedAt,
    providerThreadId: providerThreadId.present
        ? providerThreadId.value
        : this.providerThreadId,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      uid: data.uid.present ? data.uid.value : this.uid,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      inReplyTo: data.inReplyTo.present ? data.inReplyTo.value : this.inReplyTo,
      referencesHeader: data.referencesHeader.present
          ? data.referencesHeader.value
          : this.referencesHeader,
      subject: data.subject.present ? data.subject.value : this.subject,
      fromAddress: data.fromAddress.present
          ? data.fromAddress.value
          : this.fromAddress,
      fromName: data.fromName.present ? data.fromName.value : this.fromName,
      fromContactKey: data.fromContactKey.present
          ? data.fromContactKey.value
          : this.fromContactKey,
      isFromMe: data.isFromMe.present ? data.isFromMe.value : this.isFromMe,
      date: data.date.present ? data.date.value : this.date,
      internalDate: data.internalDate.present
          ? data.internalDate.value
          : this.internalDate,
      isSeen: data.isSeen.present ? data.isSeen.value : this.isSeen,
      isFlagged: data.isFlagged.present ? data.isFlagged.value : this.isFlagged,
      isAnswered: data.isAnswered.present
          ? data.isAnswered.value
          : this.isAnswered,
      isDraft: data.isDraft.present ? data.isDraft.value : this.isDraft,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      size: data.size.present ? data.size.value : this.size,
      hasAttachments: data.hasAttachments.present
          ? data.hasAttachments.value
          : this.hasAttachments,
      snippet: data.snippet.present ? data.snippet.value : this.snippet,
      bodyText: data.bodyText.present ? data.bodyText.value : this.bodyText,
      bodyHtml: data.bodyHtml.present ? data.bodyHtml.value : this.bodyHtml,
      bodyFetchedAt: data.bodyFetchedAt.present
          ? data.bodyFetchedAt.value
          : this.bodyFetchedAt,
      providerThreadId: data.providerThreadId.present
          ? data.providerThreadId.value
          : this.providerThreadId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('folderId: $folderId, ')
          ..write('uid: $uid, ')
          ..write('messageId: $messageId, ')
          ..write('inReplyTo: $inReplyTo, ')
          ..write('referencesHeader: $referencesHeader, ')
          ..write('subject: $subject, ')
          ..write('fromAddress: $fromAddress, ')
          ..write('fromName: $fromName, ')
          ..write('fromContactKey: $fromContactKey, ')
          ..write('isFromMe: $isFromMe, ')
          ..write('date: $date, ')
          ..write('internalDate: $internalDate, ')
          ..write('isSeen: $isSeen, ')
          ..write('isFlagged: $isFlagged, ')
          ..write('isAnswered: $isAnswered, ')
          ..write('isDraft: $isDraft, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('size: $size, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('snippet: $snippet, ')
          ..write('bodyText: $bodyText, ')
          ..write('bodyHtml: $bodyHtml, ')
          ..write('bodyFetchedAt: $bodyFetchedAt, ')
          ..write('providerThreadId: $providerThreadId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    accountId,
    folderId,
    uid,
    messageId,
    inReplyTo,
    referencesHeader,
    subject,
    fromAddress,
    fromName,
    fromContactKey,
    isFromMe,
    date,
    internalDate,
    isSeen,
    isFlagged,
    isAnswered,
    isDraft,
    isDeleted,
    size,
    hasAttachments,
    snippet,
    bodyText,
    bodyHtml,
    bodyFetchedAt,
    providerThreadId,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.folderId == this.folderId &&
          other.uid == this.uid &&
          other.messageId == this.messageId &&
          other.inReplyTo == this.inReplyTo &&
          other.referencesHeader == this.referencesHeader &&
          other.subject == this.subject &&
          other.fromAddress == this.fromAddress &&
          other.fromName == this.fromName &&
          other.fromContactKey == this.fromContactKey &&
          other.isFromMe == this.isFromMe &&
          other.date == this.date &&
          other.internalDate == this.internalDate &&
          other.isSeen == this.isSeen &&
          other.isFlagged == this.isFlagged &&
          other.isAnswered == this.isAnswered &&
          other.isDraft == this.isDraft &&
          other.isDeleted == this.isDeleted &&
          other.size == this.size &&
          other.hasAttachments == this.hasAttachments &&
          other.snippet == this.snippet &&
          other.bodyText == this.bodyText &&
          other.bodyHtml == this.bodyHtml &&
          other.bodyFetchedAt == this.bodyFetchedAt &&
          other.providerThreadId == this.providerThreadId);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<int> folderId;
  final Value<int> uid;
  final Value<String?> messageId;
  final Value<String?> inReplyTo;
  final Value<String?> referencesHeader;
  final Value<String> subject;
  final Value<String> fromAddress;
  final Value<String> fromName;
  final Value<String> fromContactKey;
  final Value<bool> isFromMe;
  final Value<DateTime?> date;
  final Value<DateTime?> internalDate;
  final Value<bool> isSeen;
  final Value<bool> isFlagged;
  final Value<bool> isAnswered;
  final Value<bool> isDraft;
  final Value<bool> isDeleted;
  final Value<int> size;
  final Value<bool> hasAttachments;
  final Value<String> snippet;
  final Value<String?> bodyText;
  final Value<String?> bodyHtml;
  final Value<DateTime?> bodyFetchedAt;
  final Value<String?> providerThreadId;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.uid = const Value.absent(),
    this.messageId = const Value.absent(),
    this.inReplyTo = const Value.absent(),
    this.referencesHeader = const Value.absent(),
    this.subject = const Value.absent(),
    this.fromAddress = const Value.absent(),
    this.fromName = const Value.absent(),
    this.fromContactKey = const Value.absent(),
    this.isFromMe = const Value.absent(),
    this.date = const Value.absent(),
    this.internalDate = const Value.absent(),
    this.isSeen = const Value.absent(),
    this.isFlagged = const Value.absent(),
    this.isAnswered = const Value.absent(),
    this.isDraft = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.size = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.snippet = const Value.absent(),
    this.bodyText = const Value.absent(),
    this.bodyHtml = const Value.absent(),
    this.bodyFetchedAt = const Value.absent(),
    this.providerThreadId = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required int folderId,
    required int uid,
    this.messageId = const Value.absent(),
    this.inReplyTo = const Value.absent(),
    this.referencesHeader = const Value.absent(),
    this.subject = const Value.absent(),
    this.fromAddress = const Value.absent(),
    this.fromName = const Value.absent(),
    this.fromContactKey = const Value.absent(),
    this.isFromMe = const Value.absent(),
    this.date = const Value.absent(),
    this.internalDate = const Value.absent(),
    this.isSeen = const Value.absent(),
    this.isFlagged = const Value.absent(),
    this.isAnswered = const Value.absent(),
    this.isDraft = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.size = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.snippet = const Value.absent(),
    this.bodyText = const Value.absent(),
    this.bodyHtml = const Value.absent(),
    this.bodyFetchedAt = const Value.absent(),
    this.providerThreadId = const Value.absent(),
  }) : accountId = Value(accountId),
       folderId = Value(folderId),
       uid = Value(uid);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<int>? folderId,
    Expression<int>? uid,
    Expression<String>? messageId,
    Expression<String>? inReplyTo,
    Expression<String>? referencesHeader,
    Expression<String>? subject,
    Expression<String>? fromAddress,
    Expression<String>? fromName,
    Expression<String>? fromContactKey,
    Expression<bool>? isFromMe,
    Expression<DateTime>? date,
    Expression<DateTime>? internalDate,
    Expression<bool>? isSeen,
    Expression<bool>? isFlagged,
    Expression<bool>? isAnswered,
    Expression<bool>? isDraft,
    Expression<bool>? isDeleted,
    Expression<int>? size,
    Expression<bool>? hasAttachments,
    Expression<String>? snippet,
    Expression<String>? bodyText,
    Expression<String>? bodyHtml,
    Expression<DateTime>? bodyFetchedAt,
    Expression<String>? providerThreadId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (folderId != null) 'folder_id': folderId,
      if (uid != null) 'uid': uid,
      if (messageId != null) 'message_id': messageId,
      if (inReplyTo != null) 'in_reply_to': inReplyTo,
      if (referencesHeader != null) 'references_header': referencesHeader,
      if (subject != null) 'subject': subject,
      if (fromAddress != null) 'from_address': fromAddress,
      if (fromName != null) 'from_name': fromName,
      if (fromContactKey != null) 'from_contact_key': fromContactKey,
      if (isFromMe != null) 'is_from_me': isFromMe,
      if (date != null) 'date': date,
      if (internalDate != null) 'internal_date': internalDate,
      if (isSeen != null) 'is_seen': isSeen,
      if (isFlagged != null) 'is_flagged': isFlagged,
      if (isAnswered != null) 'is_answered': isAnswered,
      if (isDraft != null) 'is_draft': isDraft,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (size != null) 'size': size,
      if (hasAttachments != null) 'has_attachments': hasAttachments,
      if (snippet != null) 'snippet': snippet,
      if (bodyText != null) 'body_text': bodyText,
      if (bodyHtml != null) 'body_html': bodyHtml,
      if (bodyFetchedAt != null) 'body_fetched_at': bodyFetchedAt,
      if (providerThreadId != null) 'provider_thread_id': providerThreadId,
    });
  }

  MessagesCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<int>? folderId,
    Value<int>? uid,
    Value<String?>? messageId,
    Value<String?>? inReplyTo,
    Value<String?>? referencesHeader,
    Value<String>? subject,
    Value<String>? fromAddress,
    Value<String>? fromName,
    Value<String>? fromContactKey,
    Value<bool>? isFromMe,
    Value<DateTime?>? date,
    Value<DateTime?>? internalDate,
    Value<bool>? isSeen,
    Value<bool>? isFlagged,
    Value<bool>? isAnswered,
    Value<bool>? isDraft,
    Value<bool>? isDeleted,
    Value<int>? size,
    Value<bool>? hasAttachments,
    Value<String>? snippet,
    Value<String?>? bodyText,
    Value<String?>? bodyHtml,
    Value<DateTime?>? bodyFetchedAt,
    Value<String?>? providerThreadId,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      folderId: folderId ?? this.folderId,
      uid: uid ?? this.uid,
      messageId: messageId ?? this.messageId,
      inReplyTo: inReplyTo ?? this.inReplyTo,
      referencesHeader: referencesHeader ?? this.referencesHeader,
      subject: subject ?? this.subject,
      fromAddress: fromAddress ?? this.fromAddress,
      fromName: fromName ?? this.fromName,
      fromContactKey: fromContactKey ?? this.fromContactKey,
      isFromMe: isFromMe ?? this.isFromMe,
      date: date ?? this.date,
      internalDate: internalDate ?? this.internalDate,
      isSeen: isSeen ?? this.isSeen,
      isFlagged: isFlagged ?? this.isFlagged,
      isAnswered: isAnswered ?? this.isAnswered,
      isDraft: isDraft ?? this.isDraft,
      isDeleted: isDeleted ?? this.isDeleted,
      size: size ?? this.size,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      snippet: snippet ?? this.snippet,
      bodyText: bodyText ?? this.bodyText,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      bodyFetchedAt: bodyFetchedAt ?? this.bodyFetchedAt,
      providerThreadId: providerThreadId ?? this.providerThreadId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (uid.present) {
      map['uid'] = Variable<int>(uid.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (inReplyTo.present) {
      map['in_reply_to'] = Variable<String>(inReplyTo.value);
    }
    if (referencesHeader.present) {
      map['references_header'] = Variable<String>(referencesHeader.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (fromAddress.present) {
      map['from_address'] = Variable<String>(fromAddress.value);
    }
    if (fromName.present) {
      map['from_name'] = Variable<String>(fromName.value);
    }
    if (fromContactKey.present) {
      map['from_contact_key'] = Variable<String>(fromContactKey.value);
    }
    if (isFromMe.present) {
      map['is_from_me'] = Variable<bool>(isFromMe.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (internalDate.present) {
      map['internal_date'] = Variable<DateTime>(internalDate.value);
    }
    if (isSeen.present) {
      map['is_seen'] = Variable<bool>(isSeen.value);
    }
    if (isFlagged.present) {
      map['is_flagged'] = Variable<bool>(isFlagged.value);
    }
    if (isAnswered.present) {
      map['is_answered'] = Variable<bool>(isAnswered.value);
    }
    if (isDraft.present) {
      map['is_draft'] = Variable<bool>(isDraft.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (hasAttachments.present) {
      map['has_attachments'] = Variable<bool>(hasAttachments.value);
    }
    if (snippet.present) {
      map['snippet'] = Variable<String>(snippet.value);
    }
    if (bodyText.present) {
      map['body_text'] = Variable<String>(bodyText.value);
    }
    if (bodyHtml.present) {
      map['body_html'] = Variable<String>(bodyHtml.value);
    }
    if (bodyFetchedAt.present) {
      map['body_fetched_at'] = Variable<DateTime>(bodyFetchedAt.value);
    }
    if (providerThreadId.present) {
      map['provider_thread_id'] = Variable<String>(providerThreadId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('folderId: $folderId, ')
          ..write('uid: $uid, ')
          ..write('messageId: $messageId, ')
          ..write('inReplyTo: $inReplyTo, ')
          ..write('referencesHeader: $referencesHeader, ')
          ..write('subject: $subject, ')
          ..write('fromAddress: $fromAddress, ')
          ..write('fromName: $fromName, ')
          ..write('fromContactKey: $fromContactKey, ')
          ..write('isFromMe: $isFromMe, ')
          ..write('date: $date, ')
          ..write('internalDate: $internalDate, ')
          ..write('isSeen: $isSeen, ')
          ..write('isFlagged: $isFlagged, ')
          ..write('isAnswered: $isAnswered, ')
          ..write('isDraft: $isDraft, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('size: $size, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('snippet: $snippet, ')
          ..write('bodyText: $bodyText, ')
          ..write('bodyHtml: $bodyHtml, ')
          ..write('bodyFetchedAt: $bodyFetchedAt, ')
          ..write('providerThreadId: $providerThreadId')
          ..write(')'))
        .toString();
  }
}

class $MessageParticipantsTable extends MessageParticipants
    with TableInfo<$MessageParticipantsTable, MessageParticipant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageParticipantsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
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
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contactKeyMeta = const VerificationMeta(
    'contactKey',
  );
  @override
  late final GeneratedColumn<String> contactKey = GeneratedColumn<String>(
    'contact_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isMeMeta = const VerificationMeta('isMe');
  @override
  late final GeneratedColumn<bool> isMe = GeneratedColumn<bool>(
    'is_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_me" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messageId,
    role,
    address,
    name,
    contactKey,
    isMe,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_participants';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageParticipant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('contact_key')) {
      context.handle(
        _contactKeyMeta,
        contactKey.isAcceptableOrUnknown(data['contact_key']!, _contactKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contactKeyMeta);
    }
    if (data.containsKey('is_me')) {
      context.handle(
        _isMeMeta,
        isMe.isAcceptableOrUnknown(data['is_me']!, _isMeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageParticipant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageParticipant(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      contactKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_key'],
      )!,
      isMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_me'],
      )!,
    );
  }

  @override
  $MessageParticipantsTable createAlias(String alias) {
    return $MessageParticipantsTable(attachedDatabase, alias);
  }
}

class MessageParticipant extends DataClass
    implements Insertable<MessageParticipant> {
  final int id;
  final int messageId;

  /// 'from' | 'to' | 'cc' | 'bcc' | 'replyTo'
  final String role;
  final String address;
  final String name;
  final String contactKey;
  final bool isMe;
  const MessageParticipant({
    required this.id,
    required this.messageId,
    required this.role,
    required this.address,
    required this.name,
    required this.contactKey,
    required this.isMe,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['message_id'] = Variable<int>(messageId);
    map['role'] = Variable<String>(role);
    map['address'] = Variable<String>(address);
    map['name'] = Variable<String>(name);
    map['contact_key'] = Variable<String>(contactKey);
    map['is_me'] = Variable<bool>(isMe);
    return map;
  }

  MessageParticipantsCompanion toCompanion(bool nullToAbsent) {
    return MessageParticipantsCompanion(
      id: Value(id),
      messageId: Value(messageId),
      role: Value(role),
      address: Value(address),
      name: Value(name),
      contactKey: Value(contactKey),
      isMe: Value(isMe),
    );
  }

  factory MessageParticipant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageParticipant(
      id: serializer.fromJson<int>(json['id']),
      messageId: serializer.fromJson<int>(json['messageId']),
      role: serializer.fromJson<String>(json['role']),
      address: serializer.fromJson<String>(json['address']),
      name: serializer.fromJson<String>(json['name']),
      contactKey: serializer.fromJson<String>(json['contactKey']),
      isMe: serializer.fromJson<bool>(json['isMe']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'messageId': serializer.toJson<int>(messageId),
      'role': serializer.toJson<String>(role),
      'address': serializer.toJson<String>(address),
      'name': serializer.toJson<String>(name),
      'contactKey': serializer.toJson<String>(contactKey),
      'isMe': serializer.toJson<bool>(isMe),
    };
  }

  MessageParticipant copyWith({
    int? id,
    int? messageId,
    String? role,
    String? address,
    String? name,
    String? contactKey,
    bool? isMe,
  }) => MessageParticipant(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    role: role ?? this.role,
    address: address ?? this.address,
    name: name ?? this.name,
    contactKey: contactKey ?? this.contactKey,
    isMe: isMe ?? this.isMe,
  );
  MessageParticipant copyWithCompanion(MessageParticipantsCompanion data) {
    return MessageParticipant(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      role: data.role.present ? data.role.value : this.role,
      address: data.address.present ? data.address.value : this.address,
      name: data.name.present ? data.name.value : this.name,
      contactKey: data.contactKey.present
          ? data.contactKey.value
          : this.contactKey,
      isMe: data.isMe.present ? data.isMe.value : this.isMe,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageParticipant(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('role: $role, ')
          ..write('address: $address, ')
          ..write('name: $name, ')
          ..write('contactKey: $contactKey, ')
          ..write('isMe: $isMe')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, messageId, role, address, name, contactKey, isMe);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageParticipant &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.role == this.role &&
          other.address == this.address &&
          other.name == this.name &&
          other.contactKey == this.contactKey &&
          other.isMe == this.isMe);
}

class MessageParticipantsCompanion extends UpdateCompanion<MessageParticipant> {
  final Value<int> id;
  final Value<int> messageId;
  final Value<String> role;
  final Value<String> address;
  final Value<String> name;
  final Value<String> contactKey;
  final Value<bool> isMe;
  const MessageParticipantsCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.role = const Value.absent(),
    this.address = const Value.absent(),
    this.name = const Value.absent(),
    this.contactKey = const Value.absent(),
    this.isMe = const Value.absent(),
  });
  MessageParticipantsCompanion.insert({
    this.id = const Value.absent(),
    required int messageId,
    required String role,
    required String address,
    this.name = const Value.absent(),
    required String contactKey,
    this.isMe = const Value.absent(),
  }) : messageId = Value(messageId),
       role = Value(role),
       address = Value(address),
       contactKey = Value(contactKey);
  static Insertable<MessageParticipant> custom({
    Expression<int>? id,
    Expression<int>? messageId,
    Expression<String>? role,
    Expression<String>? address,
    Expression<String>? name,
    Expression<String>? contactKey,
    Expression<bool>? isMe,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (role != null) 'role': role,
      if (address != null) 'address': address,
      if (name != null) 'name': name,
      if (contactKey != null) 'contact_key': contactKey,
      if (isMe != null) 'is_me': isMe,
    });
  }

  MessageParticipantsCompanion copyWith({
    Value<int>? id,
    Value<int>? messageId,
    Value<String>? role,
    Value<String>? address,
    Value<String>? name,
    Value<String>? contactKey,
    Value<bool>? isMe,
  }) {
    return MessageParticipantsCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      role: role ?? this.role,
      address: address ?? this.address,
      name: name ?? this.name,
      contactKey: contactKey ?? this.contactKey,
      isMe: isMe ?? this.isMe,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (contactKey.present) {
      map['contact_key'] = Variable<String>(contactKey.value);
    }
    if (isMe.present) {
      map['is_me'] = Variable<bool>(isMe.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageParticipantsCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('role: $role, ')
          ..write('address: $address, ')
          ..write('name: $name, ')
          ..write('contactKey: $contactKey, ')
          ..write('isMe: $isMe')
          ..write(')'))
        .toString();
  }
}

class $ContactsTable extends Contacts with TableInfo<$ContactsTable, Contact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isMeMeta = const VerificationMeta('isMe');
  @override
  late final GeneratedColumn<bool> isMe = GeneratedColumn<bool>(
    'is_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_me" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _inAddressBookMeta = const VerificationMeta(
    'inAddressBook',
  );
  @override
  late final GeneratedColumn<bool> inAddressBook = GeneratedColumn<bool>(
    'in_address_book',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_address_book" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    displayName,
    photoPath,
    isMe,
    inAddressBook,
    firstSeenAt,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Contact> instance, {
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
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('is_me')) {
      context.handle(
        _isMeMeta,
        isMe.isAcceptableOrUnknown(data['is_me']!, _isMeMeta),
      );
    }
    if (data.containsKey('in_address_book')) {
      context.handle(
        _inAddressBookMeta,
        inAddressBook.isAcceptableOrUnknown(
          data['in_address_book']!,
          _inAddressBookMeta,
        ),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Contact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Contact(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      isMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_me'],
      )!,
      inAddressBook: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_address_book'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class Contact extends DataClass implements Insertable<Contact> {
  final String key;
  final String displayName;
  final String? photoPath;
  final bool isMe;
  final bool inAddressBook;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  const Contact({
    required this.key,
    required this.displayName,
    this.photoPath,
    required this.isMe,
    required this.inAddressBook,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    map['is_me'] = Variable<bool>(isMe);
    map['in_address_book'] = Variable<bool>(inAddressBook);
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      key: Value(key),
      displayName: Value(displayName),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      isMe: Value(isMe),
      inAddressBook: Value(inAddressBook),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory Contact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Contact(
      key: serializer.fromJson<String>(json['key']),
      displayName: serializer.fromJson<String>(json['displayName']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      isMe: serializer.fromJson<bool>(json['isMe']),
      inAddressBook: serializer.fromJson<bool>(json['inAddressBook']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'displayName': serializer.toJson<String>(displayName),
      'photoPath': serializer.toJson<String?>(photoPath),
      'isMe': serializer.toJson<bool>(isMe),
      'inAddressBook': serializer.toJson<bool>(inAddressBook),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  Contact copyWith({
    String? key,
    String? displayName,
    Value<String?> photoPath = const Value.absent(),
    bool? isMe,
    bool? inAddressBook,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
  }) => Contact(
    key: key ?? this.key,
    displayName: displayName ?? this.displayName,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    isMe: isMe ?? this.isMe,
    inAddressBook: inAddressBook ?? this.inAddressBook,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  Contact copyWithCompanion(ContactsCompanion data) {
    return Contact(
      key: data.key.present ? data.key.value : this.key,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      isMe: data.isMe.present ? data.isMe.value : this.isMe,
      inAddressBook: data.inAddressBook.present
          ? data.inAddressBook.value
          : this.inAddressBook,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Contact(')
          ..write('key: $key, ')
          ..write('displayName: $displayName, ')
          ..write('photoPath: $photoPath, ')
          ..write('isMe: $isMe, ')
          ..write('inAddressBook: $inAddressBook, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    key,
    displayName,
    photoPath,
    isMe,
    inAddressBook,
    firstSeenAt,
    lastSeenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contact &&
          other.key == this.key &&
          other.displayName == this.displayName &&
          other.photoPath == this.photoPath &&
          other.isMe == this.isMe &&
          other.inAddressBook == this.inAddressBook &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class ContactsCompanion extends UpdateCompanion<Contact> {
  final Value<String> key;
  final Value<String> displayName;
  final Value<String?> photoPath;
  final Value<bool> isMe;
  final Value<bool> inAddressBook;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const ContactsCompanion({
    this.key = const Value.absent(),
    this.displayName = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.isMe = const Value.absent(),
    this.inAddressBook = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String key,
    this.displayName = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.isMe = const Value.absent(),
    this.inAddressBook = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<Contact> custom({
    Expression<String>? key,
    Expression<String>? displayName,
    Expression<String>? photoPath,
    Expression<bool>? isMe,
    Expression<bool>? inAddressBook,
    Expression<DateTime>? firstSeenAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (displayName != null) 'display_name': displayName,
      if (photoPath != null) 'photo_path': photoPath,
      if (isMe != null) 'is_me': isMe,
      if (inAddressBook != null) 'in_address_book': inAddressBook,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith({
    Value<String>? key,
    Value<String>? displayName,
    Value<String?>? photoPath,
    Value<bool>? isMe,
    Value<bool>? inAddressBook,
    Value<DateTime>? firstSeenAt,
    Value<DateTime>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return ContactsCompanion(
      key: key ?? this.key,
      displayName: displayName ?? this.displayName,
      photoPath: photoPath ?? this.photoPath,
      isMe: isMe ?? this.isMe,
      inAddressBook: inAddressBook ?? this.inAddressBook,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (isMe.present) {
      map['is_me'] = Variable<bool>(isMe.value);
    }
    if (inAddressBook.present) {
      map['in_address_book'] = Variable<bool>(inAddressBook.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('key: $key, ')
          ..write('displayName: $displayName, ')
          ..write('photoPath: $photoPath, ')
          ..write('isMe: $isMe, ')
          ..write('inAddressBook: $inAddressBook, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactAddressesTable extends ContactAddresses
    with TableInfo<$ContactAddressesTable, ContactAddressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactAddressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactKeyMeta = const VerificationMeta(
    'contactKey',
  );
  @override
  late final GeneratedColumn<String> contactKey = GeneratedColumn<String>(
    'contact_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES contacts ("key") ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('observed'),
  );
  @override
  List<GeneratedColumn> get $columns => [address, contactKey, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contact_addresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContactAddressesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('contact_key')) {
      context.handle(
        _contactKeyMeta,
        contactKey.isAcceptableOrUnknown(data['contact_key']!, _contactKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contactKeyMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {address};
  @override
  ContactAddressesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactAddressesData(
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      contactKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_key'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $ContactAddressesTable createAlias(String alias) {
    return $ContactAddressesTable(attachedDatabase, alias);
  }
}

class ContactAddressesData extends DataClass
    implements Insertable<ContactAddressesData> {
  final String address;
  final String contactKey;

  /// 'observed' | 'user' | 'addressbook'
  final String source;
  const ContactAddressesData({
    required this.address,
    required this.contactKey,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['address'] = Variable<String>(address);
    map['contact_key'] = Variable<String>(contactKey);
    map['source'] = Variable<String>(source);
    return map;
  }

  ContactAddressesCompanion toCompanion(bool nullToAbsent) {
    return ContactAddressesCompanion(
      address: Value(address),
      contactKey: Value(contactKey),
      source: Value(source),
    );
  }

  factory ContactAddressesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactAddressesData(
      address: serializer.fromJson<String>(json['address']),
      contactKey: serializer.fromJson<String>(json['contactKey']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'address': serializer.toJson<String>(address),
      'contactKey': serializer.toJson<String>(contactKey),
      'source': serializer.toJson<String>(source),
    };
  }

  ContactAddressesData copyWith({
    String? address,
    String? contactKey,
    String? source,
  }) => ContactAddressesData(
    address: address ?? this.address,
    contactKey: contactKey ?? this.contactKey,
    source: source ?? this.source,
  );
  ContactAddressesData copyWithCompanion(ContactAddressesCompanion data) {
    return ContactAddressesData(
      address: data.address.present ? data.address.value : this.address,
      contactKey: data.contactKey.present
          ? data.contactKey.value
          : this.contactKey,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactAddressesData(')
          ..write('address: $address, ')
          ..write('contactKey: $contactKey, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(address, contactKey, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactAddressesData &&
          other.address == this.address &&
          other.contactKey == this.contactKey &&
          other.source == this.source);
}

class ContactAddressesCompanion extends UpdateCompanion<ContactAddressesData> {
  final Value<String> address;
  final Value<String> contactKey;
  final Value<String> source;
  final Value<int> rowid;
  const ContactAddressesCompanion({
    this.address = const Value.absent(),
    this.contactKey = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactAddressesCompanion.insert({
    required String address,
    required String contactKey,
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : address = Value(address),
       contactKey = Value(contactKey);
  static Insertable<ContactAddressesData> custom({
    Expression<String>? address,
    Expression<String>? contactKey,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (address != null) 'address': address,
      if (contactKey != null) 'contact_key': contactKey,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactAddressesCompanion copyWith({
    Value<String>? address,
    Value<String>? contactKey,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return ContactAddressesCompanion(
      address: address ?? this.address,
      contactKey: contactKey ?? this.contactKey,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (contactKey.present) {
      map['contact_key'] = Variable<String>(contactKey.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactAddressesCompanion(')
          ..write('address: $address, ')
          ..write('contactKey: $contactKey, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('application/octet-stream'),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contentIdMeta = const VerificationMeta(
    'contentId',
  );
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
    'content_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isInlineMeta = const VerificationMeta(
    'isInline',
  );
  @override
  late final GeneratedColumn<bool> isInline = GeneratedColumn<bool>(
    'is_inline',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_inline" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messageId,
    partId,
    fileName,
    mimeType,
    size,
    contentId,
    isInline,
    localPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('content_id')) {
      context.handle(
        _contentIdMeta,
        contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta),
      );
    }
    if (data.containsKey('is_inline')) {
      context.handle(
        _isInlineMeta,
        isInline.isAcceptableOrUnknown(data['is_inline']!, _isInlineMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      contentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_id'],
      ),
      isInline: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_inline'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final int id;
  final int messageId;
  final String partId;
  final String fileName;
  final String mimeType;
  final int size;
  final String? contentId;
  final bool isInline;
  final String? localPath;
  const Attachment({
    required this.id,
    required this.messageId,
    required this.partId,
    required this.fileName,
    required this.mimeType,
    required this.size,
    this.contentId,
    required this.isInline,
    this.localPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['message_id'] = Variable<int>(messageId);
    map['part_id'] = Variable<String>(partId);
    map['file_name'] = Variable<String>(fileName);
    map['mime_type'] = Variable<String>(mimeType);
    map['size'] = Variable<int>(size);
    if (!nullToAbsent || contentId != null) {
      map['content_id'] = Variable<String>(contentId);
    }
    map['is_inline'] = Variable<bool>(isInline);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      messageId: Value(messageId),
      partId: Value(partId),
      fileName: Value(fileName),
      mimeType: Value(mimeType),
      size: Value(size),
      contentId: contentId == null && nullToAbsent
          ? const Value.absent()
          : Value(contentId),
      isInline: Value(isInline),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<int>(json['id']),
      messageId: serializer.fromJson<int>(json['messageId']),
      partId: serializer.fromJson<String>(json['partId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      size: serializer.fromJson<int>(json['size']),
      contentId: serializer.fromJson<String?>(json['contentId']),
      isInline: serializer.fromJson<bool>(json['isInline']),
      localPath: serializer.fromJson<String?>(json['localPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'messageId': serializer.toJson<int>(messageId),
      'partId': serializer.toJson<String>(partId),
      'fileName': serializer.toJson<String>(fileName),
      'mimeType': serializer.toJson<String>(mimeType),
      'size': serializer.toJson<int>(size),
      'contentId': serializer.toJson<String?>(contentId),
      'isInline': serializer.toJson<bool>(isInline),
      'localPath': serializer.toJson<String?>(localPath),
    };
  }

  Attachment copyWith({
    int? id,
    int? messageId,
    String? partId,
    String? fileName,
    String? mimeType,
    int? size,
    Value<String?> contentId = const Value.absent(),
    bool? isInline,
    Value<String?> localPath = const Value.absent(),
  }) => Attachment(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    partId: partId ?? this.partId,
    fileName: fileName ?? this.fileName,
    mimeType: mimeType ?? this.mimeType,
    size: size ?? this.size,
    contentId: contentId.present ? contentId.value : this.contentId,
    isInline: isInline ?? this.isInline,
    localPath: localPath.present ? localPath.value : this.localPath,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      partId: data.partId.present ? data.partId.value : this.partId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      size: data.size.present ? data.size.value : this.size,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      isInline: data.isInline.present ? data.isInline.value : this.isInline,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('partId: $partId, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('contentId: $contentId, ')
          ..write('isInline: $isInline, ')
          ..write('localPath: $localPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    messageId,
    partId,
    fileName,
    mimeType,
    size,
    contentId,
    isInline,
    localPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.partId == this.partId &&
          other.fileName == this.fileName &&
          other.mimeType == this.mimeType &&
          other.size == this.size &&
          other.contentId == this.contentId &&
          other.isInline == this.isInline &&
          other.localPath == this.localPath);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<int> id;
  final Value<int> messageId;
  final Value<String> partId;
  final Value<String> fileName;
  final Value<String> mimeType;
  final Value<int> size;
  final Value<String?> contentId;
  final Value<bool> isInline;
  final Value<String?> localPath;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.partId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.contentId = const Value.absent(),
    this.isInline = const Value.absent(),
    this.localPath = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    this.id = const Value.absent(),
    required int messageId,
    required String partId,
    this.fileName = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.contentId = const Value.absent(),
    this.isInline = const Value.absent(),
    this.localPath = const Value.absent(),
  }) : messageId = Value(messageId),
       partId = Value(partId);
  static Insertable<Attachment> custom({
    Expression<int>? id,
    Expression<int>? messageId,
    Expression<String>? partId,
    Expression<String>? fileName,
    Expression<String>? mimeType,
    Expression<int>? size,
    Expression<String>? contentId,
    Expression<bool>? isInline,
    Expression<String>? localPath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (partId != null) 'part_id': partId,
      if (fileName != null) 'file_name': fileName,
      if (mimeType != null) 'mime_type': mimeType,
      if (size != null) 'size': size,
      if (contentId != null) 'content_id': contentId,
      if (isInline != null) 'is_inline': isInline,
      if (localPath != null) 'local_path': localPath,
    });
  }

  AttachmentsCompanion copyWith({
    Value<int>? id,
    Value<int>? messageId,
    Value<String>? partId,
    Value<String>? fileName,
    Value<String>? mimeType,
    Value<int>? size,
    Value<String?>? contentId,
    Value<bool>? isInline,
    Value<String?>? localPath,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      partId: partId ?? this.partId,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      contentId: contentId ?? this.contentId,
      isInline: isInline ?? this.isInline,
      localPath: localPath ?? this.localPath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (isInline.present) {
      map['is_inline'] = Variable<bool>(isInline.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('partId: $partId, ')
          ..write('fileName: $fileName, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('contentId: $contentId, ')
          ..write('isInline: $isInline, ')
          ..write('localPath: $localPath')
          ..write(')'))
        .toString();
  }
}

class $PeopleGroupsTable extends PeopleGroups
    with TableInfo<$PeopleGroupsTable, PeopleGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleGroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeopleGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PeopleGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeopleGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PeopleGroupsTable createAlias(String alias) {
    return $PeopleGroupsTable(attachedDatabase, alias);
  }
}

class PeopleGroup extends DataClass implements Insertable<PeopleGroup> {
  final int id;
  final String name;
  final DateTime createdAt;
  const PeopleGroup({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PeopleGroupsCompanion toCompanion(bool nullToAbsent) {
    return PeopleGroupsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory PeopleGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeopleGroup(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PeopleGroup copyWith({int? id, String? name, DateTime? createdAt}) =>
      PeopleGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  PeopleGroup copyWithCompanion(PeopleGroupsCompanion data) {
    return PeopleGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeopleGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeopleGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class PeopleGroupsCompanion extends UpdateCompanion<PeopleGroup> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const PeopleGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PeopleGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<PeopleGroup> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PeopleGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return PeopleGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GroupMembersTable extends GroupMembers
    with TableInfo<$GroupMembersTable, GroupMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people_groups (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _contactKeyMeta = const VerificationMeta(
    'contactKey',
  );
  @override
  late final GeneratedColumn<String> contactKey = GeneratedColumn<String>(
    'contact_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [groupId, contactKey];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('contact_key')) {
      context.handle(
        _contactKeyMeta,
        contactKey.isAcceptableOrUnknown(data['contact_key']!, _contactKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contactKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, contactKey};
  @override
  GroupMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMember(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      contactKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_key'],
      )!,
    );
  }

  @override
  $GroupMembersTable createAlias(String alias) {
    return $GroupMembersTable(attachedDatabase, alias);
  }
}

class GroupMember extends DataClass implements Insertable<GroupMember> {
  final int groupId;
  final String contactKey;
  const GroupMember({required this.groupId, required this.contactKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<int>(groupId);
    map['contact_key'] = Variable<String>(contactKey);
    return map;
  }

  GroupMembersCompanion toCompanion(bool nullToAbsent) {
    return GroupMembersCompanion(
      groupId: Value(groupId),
      contactKey: Value(contactKey),
    );
  }

  factory GroupMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMember(
      groupId: serializer.fromJson<int>(json['groupId']),
      contactKey: serializer.fromJson<String>(json['contactKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<int>(groupId),
      'contactKey': serializer.toJson<String>(contactKey),
    };
  }

  GroupMember copyWith({int? groupId, String? contactKey}) => GroupMember(
    groupId: groupId ?? this.groupId,
    contactKey: contactKey ?? this.contactKey,
  );
  GroupMember copyWithCompanion(GroupMembersCompanion data) {
    return GroupMember(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      contactKey: data.contactKey.present
          ? data.contactKey.value
          : this.contactKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMember(')
          ..write('groupId: $groupId, ')
          ..write('contactKey: $contactKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupId, contactKey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMember &&
          other.groupId == this.groupId &&
          other.contactKey == this.contactKey);
}

class GroupMembersCompanion extends UpdateCompanion<GroupMember> {
  final Value<int> groupId;
  final Value<String> contactKey;
  final Value<int> rowid;
  const GroupMembersCompanion({
    this.groupId = const Value.absent(),
    this.contactKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMembersCompanion.insert({
    required int groupId,
    required String contactKey,
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       contactKey = Value(contactKey);
  static Insertable<GroupMember> custom({
    Expression<int>? groupId,
    Expression<String>? contactKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (contactKey != null) 'contact_key': contactKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMembersCompanion copyWith({
    Value<int>? groupId,
    Value<String>? contactKey,
    Value<int>? rowid,
  }) {
    return GroupMembersCompanion(
      groupId: groupId ?? this.groupId,
      contactKey: contactKey ?? this.contactKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (contactKey.present) {
      map['contact_key'] = Variable<String>(contactKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMembersCompanion(')
          ..write('groupId: $groupId, ')
          ..write('contactKey: $contactKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageRowAssignmentsTable extends MessageRowAssignments
    with TableInfo<$MessageRowAssignmentsTable, MessageRowAssignment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageRowAssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _rowKeyMeta = const VerificationMeta('rowKey');
  @override
  late final GeneratedColumn<String> rowKey = GeneratedColumn<String>(
    'row_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [messageId, rowKey];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_row_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRowAssignment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('row_key')) {
      context.handle(
        _rowKeyMeta,
        rowKey.isAcceptableOrUnknown(data['row_key']!, _rowKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_rowKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, rowKey};
  @override
  MessageRowAssignment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRowAssignment(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      rowKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_key'],
      )!,
    );
  }

  @override
  $MessageRowAssignmentsTable createAlias(String alias) {
    return $MessageRowAssignmentsTable(attachedDatabase, alias);
  }
}

class MessageRowAssignment extends DataClass
    implements Insertable<MessageRowAssignment> {
  final int messageId;
  final String rowKey;
  const MessageRowAssignment({required this.messageId, required this.rowKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<int>(messageId);
    map['row_key'] = Variable<String>(rowKey);
    return map;
  }

  MessageRowAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return MessageRowAssignmentsCompanion(
      messageId: Value(messageId),
      rowKey: Value(rowKey),
    );
  }

  factory MessageRowAssignment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRowAssignment(
      messageId: serializer.fromJson<int>(json['messageId']),
      rowKey: serializer.fromJson<String>(json['rowKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<int>(messageId),
      'rowKey': serializer.toJson<String>(rowKey),
    };
  }

  MessageRowAssignment copyWith({int? messageId, String? rowKey}) =>
      MessageRowAssignment(
        messageId: messageId ?? this.messageId,
        rowKey: rowKey ?? this.rowKey,
      );
  MessageRowAssignment copyWithCompanion(MessageRowAssignmentsCompanion data) {
    return MessageRowAssignment(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      rowKey: data.rowKey.present ? data.rowKey.value : this.rowKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRowAssignment(')
          ..write('messageId: $messageId, ')
          ..write('rowKey: $rowKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, rowKey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRowAssignment &&
          other.messageId == this.messageId &&
          other.rowKey == this.rowKey);
}

class MessageRowAssignmentsCompanion
    extends UpdateCompanion<MessageRowAssignment> {
  final Value<int> messageId;
  final Value<String> rowKey;
  final Value<int> rowid;
  const MessageRowAssignmentsCompanion({
    this.messageId = const Value.absent(),
    this.rowKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageRowAssignmentsCompanion.insert({
    required int messageId,
    required String rowKey,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       rowKey = Value(rowKey);
  static Insertable<MessageRowAssignment> custom({
    Expression<int>? messageId,
    Expression<String>? rowKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (rowKey != null) 'row_key': rowKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageRowAssignmentsCompanion copyWith({
    Value<int>? messageId,
    Value<String>? rowKey,
    Value<int>? rowid,
  }) {
    return MessageRowAssignmentsCompanion(
      messageId: messageId ?? this.messageId,
      rowKey: rowKey ?? this.rowKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (rowKey.present) {
      map['row_key'] = Variable<String>(rowKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageRowAssignmentsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('rowKey: $rowKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $IdentitiesTable identities = $IdentitiesTable(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $MessageParticipantsTable messageParticipants =
      $MessageParticipantsTable(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  late final $ContactAddressesTable contactAddresses = $ContactAddressesTable(
    this,
  );
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $PeopleGroupsTable peopleGroups = $PeopleGroupsTable(this);
  late final $GroupMembersTable groupMembers = $GroupMembersTable(this);
  late final $MessageRowAssignmentsTable messageRowAssignments =
      $MessageRowAssignmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    accounts,
    identities,
    folders,
    messages,
    messageParticipants,
    contacts,
    contactAddresses,
    attachments,
    peopleGroups,
    groupMembers,
    messageRowAssignments,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('identities', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('folders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('message_participants', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'contacts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('contact_addresses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'people_groups',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('group_members', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('message_row_assignments', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  required String email,
  Value<String> displayName,
  required String imapHost,
  required int imapPort,
  required String imapSecurity,
  required String smtpHost,
  required int smtpPort,
  required String smtpSecurity,
  required String username,
  Value<String> authMethod,
  Value<String> providerId,
  Value<bool> enabled,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime?> lastSyncAt,
  Value<String?> lastError,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  Value<String> email,
  Value<String> displayName,
  Value<String> imapHost,
  Value<int> imapPort,
  Value<String> imapSecurity,
  Value<String> smtpHost,
  Value<int> smtpPort,
  Value<String> smtpSecurity,
  Value<String> username,
  Value<String> authMethod,
  Value<String> providerId,
  Value<bool> enabled,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime?> lastSyncAt,
  Value<String?> lastError,
});

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$IdentitiesTable, List<Identity>>
  _identitiesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.identities,
    aliasName: 'accounts__id__identities__account_id',
  );

  $$IdentitiesTableProcessedTableManager get identitiesRefs {
    final manager = $$IdentitiesTableTableManager(
      $_db,
      $_db.identities,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_identitiesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FoldersTable, List<Folder>> _foldersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.folders,
    aliasName: 'accounts__id__folders__account_id',
  );

  $$FoldersTableProcessedTableManager get foldersRefs {
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_foldersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'accounts__id__messages__account_id',
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imapHost => $composableBuilder(
    column: $table.imapHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imapPort => $composableBuilder(
    column: $table.imapPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imapSecurity => $composableBuilder(
    column: $table.imapSecurity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpHost => $composableBuilder(
    column: $table.smtpHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get smtpPort => $composableBuilder(
    column: $table.smtpPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpSecurity => $composableBuilder(
    column: $table.smtpSecurity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> identitiesRefs(
    Expression<bool> Function($$IdentitiesTableFilterComposer f) f,
  ) {
    final $$IdentitiesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.identities,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IdentitiesTableFilterComposer(
            $db: $db,
            $table: $db.identities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> foldersRefs(
    Expression<bool> Function($$FoldersTableFilterComposer f) f,
  ) {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imapHost => $composableBuilder(
    column: $table.imapHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imapPort => $composableBuilder(
    column: $table.imapPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imapSecurity => $composableBuilder(
    column: $table.imapSecurity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpHost => $composableBuilder(
    column: $table.smtpHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get smtpPort => $composableBuilder(
    column: $table.smtpPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpSecurity => $composableBuilder(
    column: $table.smtpSecurity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imapHost =>
      $composableBuilder(column: $table.imapHost, builder: (column) => column);

  GeneratedColumn<int> get imapPort =>
      $composableBuilder(column: $table.imapPort, builder: (column) => column);

  GeneratedColumn<String> get imapSecurity => $composableBuilder(
    column: $table.imapSecurity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smtpHost =>
      $composableBuilder(column: $table.smtpHost, builder: (column) => column);

  GeneratedColumn<int> get smtpPort =>
      $composableBuilder(column: $table.smtpPort, builder: (column) => column);

  GeneratedColumn<String> get smtpSecurity => $composableBuilder(
    column: $table.smtpSecurity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  Expression<T> identitiesRefs<T extends Object>(
    Expression<T> Function($$IdentitiesTableAnnotationComposer a) f,
  ) {
    final $$IdentitiesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.identities,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IdentitiesTableAnnotationComposer(
            $db: $db,
            $table: $db.identities,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> foldersRefs<T extends Object>(
    Expression<T> Function($$FoldersTableAnnotationComposer a) f,
  ) {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({
            bool identitiesRefs,
            bool foldersRefs,
            bool messagesRefs,
          })
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> imapHost = const Value.absent(),
                Value<int> imapPort = const Value.absent(),
                Value<String> imapSecurity = const Value.absent(),
                Value<String> smtpHost = const Value.absent(),
                Value<int> smtpPort = const Value.absent(),
                Value<String> smtpSecurity = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> authMethod = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                email: email,
                displayName: displayName,
                imapHost: imapHost,
                imapPort: imapPort,
                imapSecurity: imapSecurity,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpSecurity: smtpSecurity,
                username: username,
                authMethod: authMethod,
                providerId: providerId,
                enabled: enabled,
                sortOrder: sortOrder,
                createdAt: createdAt,
                lastSyncAt: lastSyncAt,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String email,
                Value<String> displayName = const Value.absent(),
                required String imapHost,
                required int imapPort,
                required String imapSecurity,
                required String smtpHost,
                required int smtpPort,
                required String smtpSecurity,
                required String username,
                Value<String> authMethod = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                email: email,
                displayName: displayName,
                imapHost: imapHost,
                imapPort: imapPort,
                imapSecurity: imapSecurity,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpSecurity: smtpSecurity,
                username: username,
                authMethod: authMethod,
                providerId: providerId,
                enabled: enabled,
                sortOrder: sortOrder,
                createdAt: createdAt,
                lastSyncAt: lastSyncAt,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, Account>(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                identitiesRefs = false,
                foldersRefs = false,
                messagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (identitiesRefs) db.identities,
                    if (foldersRefs) db.folders,
                    if (messagesRefs) db.messages,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (identitiesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Identity
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._identitiesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).identitiesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (foldersRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Folder
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._foldersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).foldersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (messagesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Message
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).messagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
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

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({
        bool identitiesRefs,
        bool foldersRefs,
        bool messagesRefs,
      })
    >;
typedef $$IdentitiesTableCreateCompanionBuilder = IdentitiesCompanion Function({
  Value<int> id,
  required int accountId,
  required String email,
  Value<String> name,
  Value<String> signature,
  Value<String?> smtpHost,
  Value<int?> smtpPort,
  Value<String?> smtpSecurity,
  Value<bool> isDefault,
});
typedef $$IdentitiesTableUpdateCompanionBuilder = IdentitiesCompanion Function({
  Value<int> id,
  Value<int> accountId,
  Value<String> email,
  Value<String> name,
  Value<String> signature,
  Value<String?> smtpHost,
  Value<int?> smtpPort,
  Value<String?> smtpSecurity,
  Value<bool> isDefault,
});

final class $$IdentitiesTableReferences
    extends BaseReferences<_$AppDatabase, $IdentitiesTable, Identity> {
  $$IdentitiesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('identities__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$IdentitiesTableFilterComposer
    extends Composer<_$AppDatabase, $IdentitiesTable> {
  $$IdentitiesTableFilterComposer({
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

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpHost => $composableBuilder(
    column: $table.smtpHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get smtpPort => $composableBuilder(
    column: $table.smtpPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpSecurity => $composableBuilder(
    column: $table.smtpSecurity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IdentitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $IdentitiesTable> {
  $$IdentitiesTableOrderingComposer({
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

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpHost => $composableBuilder(
    column: $table.smtpHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get smtpPort => $composableBuilder(
    column: $table.smtpPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpSecurity => $composableBuilder(
    column: $table.smtpSecurity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IdentitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdentitiesTable> {
  $$IdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<String> get smtpHost =>
      $composableBuilder(column: $table.smtpHost, builder: (column) => column);

  GeneratedColumn<int> get smtpPort =>
      $composableBuilder(column: $table.smtpPort, builder: (column) => column);

  GeneratedColumn<String> get smtpSecurity => $composableBuilder(
    column: $table.smtpSecurity,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IdentitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdentitiesTable,
          Identity,
          $$IdentitiesTableFilterComposer,
          $$IdentitiesTableOrderingComposer,
          $$IdentitiesTableAnnotationComposer,
          $$IdentitiesTableCreateCompanionBuilder,
          $$IdentitiesTableUpdateCompanionBuilder,
          (Identity, $$IdentitiesTableReferences),
          Identity,
          PrefetchHooks Function({bool accountId})
        > {
  $$IdentitiesTableTableManager(_$AppDatabase db, $IdentitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdentitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdentitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdentitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<String?> smtpHost = const Value.absent(),
                Value<int?> smtpPort = const Value.absent(),
                Value<String?> smtpSecurity = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
              }) => IdentitiesCompanion(
                id: id,
                accountId: accountId,
                email: email,
                name: name,
                signature: signature,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpSecurity: smtpSecurity,
                isDefault: isDefault,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required String email,
                Value<String> name = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<String?> smtpHost = const Value.absent(),
                Value<int?> smtpPort = const Value.absent(),
                Value<String?> smtpSecurity = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
              }) => IdentitiesCompanion.insert(
                id: id,
                accountId: accountId,
                email: email,
                name: name,
                signature: signature,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpSecurity: smtpSecurity,
                isDefault: isDefault,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IdentitiesTable, Identity>(table),
                  $$IdentitiesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
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
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$IdentitiesTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$IdentitiesTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
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

typedef $$IdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdentitiesTable,
      Identity,
      $$IdentitiesTableFilterComposer,
      $$IdentitiesTableOrderingComposer,
      $$IdentitiesTableAnnotationComposer,
      $$IdentitiesTableCreateCompanionBuilder,
      $$IdentitiesTableUpdateCompanionBuilder,
      (Identity, $$IdentitiesTableReferences),
      Identity,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  required int accountId,
  required String path,
  required String name,
  Value<String> role,
  Value<bool> selectable,
  Value<int?> uidValidity,
  Value<int?> uidNext,
  Value<int?> highestModSeq,
  Value<int> lastSyncedUid,
  Value<int> messagesExists,
  Value<DateTime?> lastSyncAt,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  Value<int> accountId,
  Value<String> path,
  Value<String> name,
  Value<String> role,
  Value<bool> selectable,
  Value<int?> uidValidity,
  Value<int?> uidNext,
  Value<int?> highestModSeq,
  Value<int> lastSyncedUid,
  Value<int> messagesExists,
  Value<DateTime?> lastSyncAt,
});

final class $$FoldersTableReferences
    extends BaseReferences<_$AppDatabase, $FoldersTable, Folder> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('folders__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: 'folders__id__messages__folder_id',
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get selectable => $composableBuilder(
    column: $table.selectable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uidNext => $composableBuilder(
    column: $table.uidNext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highestModSeq => $composableBuilder(
    column: $table.highestModSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedUid => $composableBuilder(
    column: $table.lastSyncedUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messagesExists => $composableBuilder(
    column: $table.messagesExists,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get selectable => $composableBuilder(
    column: $table.selectable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uidNext => $composableBuilder(
    column: $table.uidNext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highestModSeq => $composableBuilder(
    column: $table.highestModSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedUid => $composableBuilder(
    column: $table.lastSyncedUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messagesExists => $composableBuilder(
    column: $table.messagesExists,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get selectable => $composableBuilder(
    column: $table.selectable,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uidValidity => $composableBuilder(
    column: $table.uidValidity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uidNext =>
      $composableBuilder(column: $table.uidNext, builder: (column) => column);

  GeneratedColumn<int> get highestModSeq => $composableBuilder(
    column: $table.highestModSeq,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedUid => $composableBuilder(
    column: $table.lastSyncedUid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get messagesExists => $composableBuilder(
    column: $table.messagesExists,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, $$FoldersTableReferences),
          Folder,
          PrefetchHooks Function({bool accountId, bool messagesRefs})
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> selectable = const Value.absent(),
                Value<int?> uidValidity = const Value.absent(),
                Value<int?> uidNext = const Value.absent(),
                Value<int?> highestModSeq = const Value.absent(),
                Value<int> lastSyncedUid = const Value.absent(),
                Value<int> messagesExists = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                accountId: accountId,
                path: path,
                name: name,
                role: role,
                selectable: selectable,
                uidValidity: uidValidity,
                uidNext: uidNext,
                highestModSeq: highestModSeq,
                lastSyncedUid: lastSyncedUid,
                messagesExists: messagesExists,
                lastSyncAt: lastSyncAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required String path,
                required String name,
                Value<String> role = const Value.absent(),
                Value<bool> selectable = const Value.absent(),
                Value<int?> uidValidity = const Value.absent(),
                Value<int?> uidNext = const Value.absent(),
                Value<int?> highestModSeq = const Value.absent(),
                Value<int> lastSyncedUid = const Value.absent(),
                Value<int> messagesExists = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                accountId: accountId,
                path: path,
                name: name,
                role: role,
                selectable: selectable,
                uidValidity: uidValidity,
                uidNext: uidNext,
                highestModSeq: highestModSeq,
                lastSyncedUid: lastSyncedUid,
                messagesExists: messagesExists,
                lastSyncAt: lastSyncAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoldersTable, Folder>(table),
                  $$FoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false, messagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (messagesRefs) db.messages],
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
                    if (accountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.accountId,
                        referencedTable: $$FoldersTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$FoldersTableReferences
                            ._accountIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messagesRefs)
                    await $_getPrefetchedData<Folder, $FoldersTable, Message>(
                      currentTable: table,
                      referencedTable: $$FoldersTableReferences
                          ._messagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FoldersTableReferences(db, table, p0).messagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, $$FoldersTableReferences),
      Folder,
      PrefetchHooks Function({bool accountId, bool messagesRefs})
    >;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  required int accountId,
  required int folderId,
  required int uid,
  Value<String?> messageId,
  Value<String?> inReplyTo,
  Value<String?> referencesHeader,
  Value<String> subject,
  Value<String> fromAddress,
  Value<String> fromName,
  Value<String> fromContactKey,
  Value<bool> isFromMe,
  Value<DateTime?> date,
  Value<DateTime?> internalDate,
  Value<bool> isSeen,
  Value<bool> isFlagged,
  Value<bool> isAnswered,
  Value<bool> isDraft,
  Value<bool> isDeleted,
  Value<int> size,
  Value<bool> hasAttachments,
  Value<String> snippet,
  Value<String?> bodyText,
  Value<String?> bodyHtml,
  Value<DateTime?> bodyFetchedAt,
  Value<String?> providerThreadId,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<int> accountId,
  Value<int> folderId,
  Value<int> uid,
  Value<String?> messageId,
  Value<String?> inReplyTo,
  Value<String?> referencesHeader,
  Value<String> subject,
  Value<String> fromAddress,
  Value<String> fromName,
  Value<String> fromContactKey,
  Value<bool> isFromMe,
  Value<DateTime?> date,
  Value<DateTime?> internalDate,
  Value<bool> isSeen,
  Value<bool> isFlagged,
  Value<bool> isAnswered,
  Value<bool> isDraft,
  Value<bool> isDeleted,
  Value<int> size,
  Value<bool> hasAttachments,
  Value<String> snippet,
  Value<String?> bodyText,
  Value<String?> bodyHtml,
  Value<DateTime?> bodyFetchedAt,
  Value<String?> providerThreadId,
});

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('messages__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FoldersTable _folderIdTable(_$AppDatabase db) =>
      db.folders.createAlias('messages__folder_id__folders__id');

  $$FoldersTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<int>('folder_id')!;

    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $MessageParticipantsTable,
    List<MessageParticipant>
  >
  _messageParticipantsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.messageParticipants,
        aliasName: 'messages__id__message_participants__message_id',
      );

  $$MessageParticipantsTableProcessedTableManager get messageParticipantsRefs {
    final manager = $$MessageParticipantsTableTableManager(
      $_db,
      $_db.messageParticipants,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _messageParticipantsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'messages__id__attachments__message_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MessageRowAssignmentsTable,
    List<MessageRowAssignment>
  >
  _messageRowAssignmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.messageRowAssignments,
        aliasName: 'messages__id__message_row_assignments__message_id',
      );

  $$MessageRowAssignmentsTableProcessedTableManager
  get messageRowAssignmentsRefs {
    final manager = $$MessageRowAssignmentsTableTableManager(
      $_db,
      $_db.messageRowAssignments,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _messageRowAssignmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
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

  ColumnFilters<int> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inReplyTo => $composableBuilder(
    column: $table.inReplyTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referencesHeader => $composableBuilder(
    column: $table.referencesHeader,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromName => $composableBuilder(
    column: $table.fromName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromContactKey => $composableBuilder(
    column: $table.fromContactKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFromMe => $composableBuilder(
    column: $table.isFromMe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get internalDate => $composableBuilder(
    column: $table.internalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSeen => $composableBuilder(
    column: $table.isSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFlagged => $composableBuilder(
    column: $table.isFlagged,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAnswered => $composableBuilder(
    column: $table.isAnswered,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDraft => $composableBuilder(
    column: $table.isDraft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyText => $composableBuilder(
    column: $table.bodyText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyHtml => $composableBuilder(
    column: $table.bodyHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get bodyFetchedAt => $composableBuilder(
    column: $table.bodyFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerThreadId => $composableBuilder(
    column: $table.providerThreadId,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> messageParticipantsRefs(
    Expression<bool> Function($$MessageParticipantsTableFilterComposer f) f,
  ) {
    final $$MessageParticipantsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messageParticipants,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessageParticipantsTableFilterComposer(
            $db: $db,
            $table: $db.messageParticipants,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> messageRowAssignmentsRefs(
    Expression<bool> Function($$MessageRowAssignmentsTableFilterComposer f) f,
  ) {
    final $$MessageRowAssignmentsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.messageRowAssignments,
          getReferencedColumn: (t) => t.messageId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MessageRowAssignmentsTableFilterComposer(
                $db: $db,
                $table: $db.messageRowAssignments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
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

  ColumnOrderings<int> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inReplyTo => $composableBuilder(
    column: $table.inReplyTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referencesHeader => $composableBuilder(
    column: $table.referencesHeader,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromName => $composableBuilder(
    column: $table.fromName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromContactKey => $composableBuilder(
    column: $table.fromContactKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFromMe => $composableBuilder(
    column: $table.isFromMe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get internalDate => $composableBuilder(
    column: $table.internalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSeen => $composableBuilder(
    column: $table.isSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFlagged => $composableBuilder(
    column: $table.isFlagged,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAnswered => $composableBuilder(
    column: $table.isAnswered,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDraft => $composableBuilder(
    column: $table.isDraft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyText => $composableBuilder(
    column: $table.bodyText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyHtml => $composableBuilder(
    column: $table.bodyHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get bodyFetchedAt => $composableBuilder(
    column: $table.bodyFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerThreadId => $composableBuilder(
    column: $table.providerThreadId,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get inReplyTo =>
      $composableBuilder(column: $table.inReplyTo, builder: (column) => column);

  GeneratedColumn<String> get referencesHeader => $composableBuilder(
    column: $table.referencesHeader,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get fromAddress => $composableBuilder(
    column: $table.fromAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fromName =>
      $composableBuilder(column: $table.fromName, builder: (column) => column);

  GeneratedColumn<String> get fromContactKey => $composableBuilder(
    column: $table.fromContactKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFromMe =>
      $composableBuilder(column: $table.isFromMe, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get internalDate => $composableBuilder(
    column: $table.internalDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSeen =>
      $composableBuilder(column: $table.isSeen, builder: (column) => column);

  GeneratedColumn<bool> get isFlagged =>
      $composableBuilder(column: $table.isFlagged, builder: (column) => column);

  GeneratedColumn<bool> get isAnswered => $composableBuilder(
    column: $table.isAnswered,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDraft =>
      $composableBuilder(column: $table.isDraft, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snippet =>
      $composableBuilder(column: $table.snippet, builder: (column) => column);

  GeneratedColumn<String> get bodyText =>
      $composableBuilder(column: $table.bodyText, builder: (column) => column);

  GeneratedColumn<String> get bodyHtml =>
      $composableBuilder(column: $table.bodyHtml, builder: (column) => column);

  GeneratedColumn<DateTime> get bodyFetchedAt => $composableBuilder(
    column: $table.bodyFetchedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerThreadId => $composableBuilder(
    column: $table.providerThreadId,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> messageParticipantsRefs<T extends Object>(
    Expression<T> Function($$MessageParticipantsTableAnnotationComposer a) f,
  ) {
    final $$MessageParticipantsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.messageParticipants,
          getReferencedColumn: (t) => t.messageId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MessageParticipantsTableAnnotationComposer(
                $db: $db,
                $table: $db.messageParticipants,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> messageRowAssignmentsRefs<T extends Object>(
    Expression<T> Function($$MessageRowAssignmentsTableAnnotationComposer a) f,
  ) {
    final $$MessageRowAssignmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.messageRowAssignments,
          getReferencedColumn: (t) => t.messageId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MessageRowAssignmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.messageRowAssignments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, $$MessagesTableReferences),
          Message,
          PrefetchHooks Function({
            bool accountId,
            bool folderId,
            bool messageParticipantsRefs,
            bool attachmentsRefs,
            bool messageRowAssignmentsRefs,
          })
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int> folderId = const Value.absent(),
                Value<int> uid = const Value.absent(),
                Value<String?> messageId = const Value.absent(),
                Value<String?> inReplyTo = const Value.absent(),
                Value<String?> referencesHeader = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> fromAddress = const Value.absent(),
                Value<String> fromName = const Value.absent(),
                Value<String> fromContactKey = const Value.absent(),
                Value<bool> isFromMe = const Value.absent(),
                Value<DateTime?> date = const Value.absent(),
                Value<DateTime?> internalDate = const Value.absent(),
                Value<bool> isSeen = const Value.absent(),
                Value<bool> isFlagged = const Value.absent(),
                Value<bool> isAnswered = const Value.absent(),
                Value<bool> isDraft = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<bool> hasAttachments = const Value.absent(),
                Value<String> snippet = const Value.absent(),
                Value<String?> bodyText = const Value.absent(),
                Value<String?> bodyHtml = const Value.absent(),
                Value<DateTime?> bodyFetchedAt = const Value.absent(),
                Value<String?> providerThreadId = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                accountId: accountId,
                folderId: folderId,
                uid: uid,
                messageId: messageId,
                inReplyTo: inReplyTo,
                referencesHeader: referencesHeader,
                subject: subject,
                fromAddress: fromAddress,
                fromName: fromName,
                fromContactKey: fromContactKey,
                isFromMe: isFromMe,
                date: date,
                internalDate: internalDate,
                isSeen: isSeen,
                isFlagged: isFlagged,
                isAnswered: isAnswered,
                isDraft: isDraft,
                isDeleted: isDeleted,
                size: size,
                hasAttachments: hasAttachments,
                snippet: snippet,
                bodyText: bodyText,
                bodyHtml: bodyHtml,
                bodyFetchedAt: bodyFetchedAt,
                providerThreadId: providerThreadId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                required int folderId,
                required int uid,
                Value<String?> messageId = const Value.absent(),
                Value<String?> inReplyTo = const Value.absent(),
                Value<String?> referencesHeader = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> fromAddress = const Value.absent(),
                Value<String> fromName = const Value.absent(),
                Value<String> fromContactKey = const Value.absent(),
                Value<bool> isFromMe = const Value.absent(),
                Value<DateTime?> date = const Value.absent(),
                Value<DateTime?> internalDate = const Value.absent(),
                Value<bool> isSeen = const Value.absent(),
                Value<bool> isFlagged = const Value.absent(),
                Value<bool> isAnswered = const Value.absent(),
                Value<bool> isDraft = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<bool> hasAttachments = const Value.absent(),
                Value<String> snippet = const Value.absent(),
                Value<String?> bodyText = const Value.absent(),
                Value<String?> bodyHtml = const Value.absent(),
                Value<DateTime?> bodyFetchedAt = const Value.absent(),
                Value<String?> providerThreadId = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                accountId: accountId,
                folderId: folderId,
                uid: uid,
                messageId: messageId,
                inReplyTo: inReplyTo,
                referencesHeader: referencesHeader,
                subject: subject,
                fromAddress: fromAddress,
                fromName: fromName,
                fromContactKey: fromContactKey,
                isFromMe: isFromMe,
                date: date,
                internalDate: internalDate,
                isSeen: isSeen,
                isFlagged: isFlagged,
                isAnswered: isAnswered,
                isDraft: isDraft,
                isDeleted: isDeleted,
                size: size,
                hasAttachments: hasAttachments,
                snippet: snippet,
                bodyText: bodyText,
                bodyHtml: bodyHtml,
                bodyFetchedAt: bodyFetchedAt,
                providerThreadId: providerThreadId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTable, Message>(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                accountId = false,
                folderId = false,
                messageParticipantsRefs = false,
                attachmentsRefs = false,
                messageRowAssignmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messageParticipantsRefs) db.messageParticipants,
                    if (attachmentsRefs) db.attachments,
                    if (messageRowAssignmentsRefs) db.messageRowAssignments,
                  ],
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
                        if (accountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.accountId,
                            referencedTable: $$MessagesTableReferences
                                ._accountIdTable(db),
                            referencedColumn: $$MessagesTableReferences
                                ._accountIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (folderId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.folderId,
                            referencedTable: $$MessagesTableReferences
                                ._folderIdTable(db),
                            referencedColumn: $$MessagesTableReferences
                                ._folderIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (messageParticipantsRefs)
                        await $_getPrefetchedData<
                          Message,
                          $MessagesTable,
                          MessageParticipant
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._messageParticipantsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).messageParticipantsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedData<
                          Message,
                          $MessagesTable,
                          Attachment
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (messageRowAssignmentsRefs)
                        await $_getPrefetchedData<
                          Message,
                          $MessagesTable,
                          MessageRowAssignment
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._messageRowAssignmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).messageRowAssignmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.id,
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

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, $$MessagesTableReferences),
      Message,
      PrefetchHooks Function({
        bool accountId,
        bool folderId,
        bool messageParticipantsRefs,
        bool attachmentsRefs,
        bool messageRowAssignmentsRefs,
      })
    >;
typedef $$MessageParticipantsTableCreateCompanionBuilder =
    MessageParticipantsCompanion Function({
      Value<int> id,
      required int messageId,
      required String role,
      required String address,
      Value<String> name,
      required String contactKey,
      Value<bool> isMe,
    });
typedef $$MessageParticipantsTableUpdateCompanionBuilder =
    MessageParticipantsCompanion Function({
      Value<int> id,
      Value<int> messageId,
      Value<String> role,
      Value<String> address,
      Value<String> name,
      Value<String> contactKey,
      Value<bool> isMe,
    });

final class $$MessageParticipantsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MessageParticipantsTable,
          MessageParticipant
        > {
  $$MessageParticipantsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MessagesTable _messageIdTable(_$AppDatabase db) =>
      db.messages.createAlias('message_participants__message_id__messages__id');

  $$MessagesTableProcessedTableManager get messageId {
    final $_column = $_itemColumn<int>('message_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessageParticipantsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageParticipantsTable> {
  $$MessageParticipantsTableFilterComposer({
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

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactKey => $composableBuilder(
    column: $table.contactKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnFilters(column),
  );

  $$MessagesTableFilterComposer get messageId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageParticipantsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageParticipantsTable> {
  $$MessageParticipantsTableOrderingComposer({
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

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactKey => $composableBuilder(
    column: $table.contactKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessagesTableOrderingComposer get messageId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageParticipantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageParticipantsTable> {
  $$MessageParticipantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get contactKey => $composableBuilder(
    column: $table.contactKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMe =>
      $composableBuilder(column: $table.isMe, builder: (column) => column);

  $$MessagesTableAnnotationComposer get messageId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageParticipantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageParticipantsTable,
          MessageParticipant,
          $$MessageParticipantsTableFilterComposer,
          $$MessageParticipantsTableOrderingComposer,
          $$MessageParticipantsTableAnnotationComposer,
          $$MessageParticipantsTableCreateCompanionBuilder,
          $$MessageParticipantsTableUpdateCompanionBuilder,
          (MessageParticipant, $$MessageParticipantsTableReferences),
          MessageParticipant,
          PrefetchHooks Function({bool messageId})
        > {
  $$MessageParticipantsTableTableManager(
    _$AppDatabase db,
    $MessageParticipantsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageParticipantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageParticipantsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MessageParticipantsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> contactKey = const Value.absent(),
                Value<bool> isMe = const Value.absent(),
              }) => MessageParticipantsCompanion(
                id: id,
                messageId: messageId,
                role: role,
                address: address,
                name: name,
                contactKey: contactKey,
                isMe: isMe,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int messageId,
                required String role,
                required String address,
                Value<String> name = const Value.absent(),
                required String contactKey,
                Value<bool> isMe = const Value.absent(),
              }) => MessageParticipantsCompanion.insert(
                id: id,
                messageId: messageId,
                role: role,
                address: address,
                name: name,
                contactKey: contactKey,
                isMe: isMe,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessageParticipantsTable, MessageParticipant>(
                    table,
                  ),
                  $$MessageParticipantsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
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
                    if (messageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.messageId,
                        referencedTable: $$MessageParticipantsTableReferences
                            ._messageIdTable(db),
                        referencedColumn: $$MessageParticipantsTableReferences
                            ._messageIdTable(db)
                            .id,
                      ) as T;
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

typedef $$MessageParticipantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageParticipantsTable,
      MessageParticipant,
      $$MessageParticipantsTableFilterComposer,
      $$MessageParticipantsTableOrderingComposer,
      $$MessageParticipantsTableAnnotationComposer,
      $$MessageParticipantsTableCreateCompanionBuilder,
      $$MessageParticipantsTableUpdateCompanionBuilder,
      (MessageParticipant, $$MessageParticipantsTableReferences),
      MessageParticipant,
      PrefetchHooks Function({bool messageId})
    >;
typedef $$ContactsTableCreateCompanionBuilder = ContactsCompanion Function({
  required String key,
  Value<String> displayName,
  Value<String?> photoPath,
  Value<bool> isMe,
  Value<bool> inAddressBook,
  Value<DateTime> firstSeenAt,
  Value<DateTime> lastSeenAt,
  Value<int> rowid,
});
typedef $$ContactsTableUpdateCompanionBuilder = ContactsCompanion Function({
  Value<String> key,
  Value<String> displayName,
  Value<String?> photoPath,
  Value<bool> isMe,
  Value<bool> inAddressBook,
  Value<DateTime> firstSeenAt,
  Value<DateTime> lastSeenAt,
  Value<int> rowid,
});

final class $$ContactsTableReferences
    extends BaseReferences<_$AppDatabase, $ContactsTable, Contact> {
  $$ContactsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ContactAddressesTable, List<ContactAddressesData>>
  _contactAddressesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.contactAddresses,
    aliasName: 'contacts__key__contact_addresses__contact_key',
  );

  $$ContactAddressesTableProcessedTableManager get contactAddressesRefs {
    final manager = $$ContactAddressesTableTableManager(
      $_db,
      $_db.contactAddresses,
    ).filter((f) => f.contactKey.key.sqlEquals($_itemColumn<String>('key')!));

    final cache = $_typedResult.readTableOrNull(
      _contactAddressesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ContactsTableFilterComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableFilterComposer({
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

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inAddressBook => $composableBuilder(
    column: $table.inAddressBook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> contactAddressesRefs(
    Expression<bool> Function($$ContactAddressesTableFilterComposer f) f,
  ) {
    final $$ContactAddressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.contactAddresses,
      getReferencedColumn: (t) => t.contactKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContactAddressesTableFilterComposer(
            $db: $db,
            $table: $db.contactAddresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableOrderingComposer({
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

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inAddressBook => $composableBuilder(
    column: $table.inAddressBook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<bool> get isMe =>
      $composableBuilder(column: $table.isMe, builder: (column) => column);

  GeneratedColumn<bool> get inAddressBook => $composableBuilder(
    column: $table.inAddressBook,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  Expression<T> contactAddressesRefs<T extends Object>(
    Expression<T> Function($$ContactAddressesTableAnnotationComposer a) f,
  ) {
    final $$ContactAddressesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.key,
      referencedTable: $db.contactAddresses,
      getReferencedColumn: (t) => t.contactKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContactAddressesTableAnnotationComposer(
            $db: $db,
            $table: $db.contactAddresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactsTable,
          Contact,
          $$ContactsTableFilterComposer,
          $$ContactsTableOrderingComposer,
          $$ContactsTableAnnotationComposer,
          $$ContactsTableCreateCompanionBuilder,
          $$ContactsTableUpdateCompanionBuilder,
          (Contact, $$ContactsTableReferences),
          Contact,
          PrefetchHooks Function({bool contactAddressesRefs})
        > {
  $$ContactsTableTableManager(_$AppDatabase db, $ContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<bool> isMe = const Value.absent(),
                Value<bool> inAddressBook = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                key: key,
                displayName: displayName,
                photoPath: photoPath,
                isMe: isMe,
                inAddressBook: inAddressBook,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String> displayName = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<bool> isMe = const Value.absent(),
                Value<bool> inAddressBook = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                key: key,
                displayName: displayName,
                photoPath: photoPath,
                isMe: isMe,
                inAddressBook: inAddressBook,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContactsTable, Contact>(table),
                  $$ContactsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({contactAddressesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (contactAddressesRefs) db.contactAddresses,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (contactAddressesRefs)
                    await $_getPrefetchedData<
                      Contact,
                      $ContactsTable,
                      ContactAddressesData
                    >(
                      currentTable: table,
                      referencedTable: $$ContactsTableReferences
                          ._contactAddressesRefsTable(db),
                      managerFromTypedResult: (p0) => $$ContactsTableReferences(
                        db,
                        table,
                        p0,
                      ).contactAddressesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.contactKey == item.key,
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

typedef $$ContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactsTable,
      Contact,
      $$ContactsTableFilterComposer,
      $$ContactsTableOrderingComposer,
      $$ContactsTableAnnotationComposer,
      $$ContactsTableCreateCompanionBuilder,
      $$ContactsTableUpdateCompanionBuilder,
      (Contact, $$ContactsTableReferences),
      Contact,
      PrefetchHooks Function({bool contactAddressesRefs})
    >;
typedef $$ContactAddressesTableCreateCompanionBuilder =
    ContactAddressesCompanion Function({
      required String address,
      required String contactKey,
      Value<String> source,
      Value<int> rowid,
    });
typedef $$ContactAddressesTableUpdateCompanionBuilder =
    ContactAddressesCompanion Function({
      Value<String> address,
      Value<String> contactKey,
      Value<String> source,
      Value<int> rowid,
    });

final class $$ContactAddressesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ContactAddressesTable,
          ContactAddressesData
        > {
  $$ContactAddressesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ContactsTable _contactKeyTable(_$AppDatabase db) =>
      db.contacts.createAlias('contact_addresses__contact_key__contacts__key');

  $$ContactsTableProcessedTableManager get contactKey {
    final $_column = $_itemColumn<String>('contact_key')!;

    final manager = $$ContactsTableTableManager(
      $_db,
      $_db.contacts,
    ).filter((f) => f.key.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_contactKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ContactAddressesTableFilterComposer
    extends Composer<_$AppDatabase, $ContactAddressesTable> {
  $$ContactAddressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  $$ContactsTableFilterComposer get contactKey {
    final $$ContactsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contactKey,
      referencedTable: $db.contacts,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContactsTableFilterComposer(
            $db: $db,
            $table: $db.contacts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContactAddressesTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactAddressesTable> {
  $$ContactAddressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  $$ContactsTableOrderingComposer get contactKey {
    final $$ContactsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contactKey,
      referencedTable: $db.contacts,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContactsTableOrderingComposer(
            $db: $db,
            $table: $db.contacts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContactAddressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactAddressesTable> {
  $$ContactAddressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$ContactsTableAnnotationComposer get contactKey {
    final $$ContactsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contactKey,
      referencedTable: $db.contacts,
      getReferencedColumn: (t) => t.key,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContactsTableAnnotationComposer(
            $db: $db,
            $table: $db.contacts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContactAddressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactAddressesTable,
          ContactAddressesData,
          $$ContactAddressesTableFilterComposer,
          $$ContactAddressesTableOrderingComposer,
          $$ContactAddressesTableAnnotationComposer,
          $$ContactAddressesTableCreateCompanionBuilder,
          $$ContactAddressesTableUpdateCompanionBuilder,
          (ContactAddressesData, $$ContactAddressesTableReferences),
          ContactAddressesData,
          PrefetchHooks Function({bool contactKey})
        > {
  $$ContactAddressesTableTableManager(
    _$AppDatabase db,
    $ContactAddressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactAddressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactAddressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactAddressesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> address = const Value.absent(),
                Value<String> contactKey = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactAddressesCompanion(
                address: address,
                contactKey: contactKey,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String address,
                required String contactKey,
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactAddressesCompanion.insert(
                address: address,
                contactKey: contactKey,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContactAddressesTable, ContactAddressesData>(
                    table,
                  ),
                  $$ContactAddressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({contactKey = false}) {
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
                    if (contactKey) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.contactKey,
                        referencedTable: $$ContactAddressesTableReferences
                            ._contactKeyTable(db),
                        referencedColumn: $$ContactAddressesTableReferences
                            ._contactKeyTable(db)
                            .key,
                      ) as T;
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

typedef $$ContactAddressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactAddressesTable,
      ContactAddressesData,
      $$ContactAddressesTableFilterComposer,
      $$ContactAddressesTableOrderingComposer,
      $$ContactAddressesTableAnnotationComposer,
      $$ContactAddressesTableCreateCompanionBuilder,
      $$ContactAddressesTableUpdateCompanionBuilder,
      (ContactAddressesData, $$ContactAddressesTableReferences),
      ContactAddressesData,
      PrefetchHooks Function({bool contactKey})
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      required int messageId,
      required String partId,
      Value<String> fileName,
      Value<String> mimeType,
      Value<int> size,
      Value<String?> contentId,
      Value<bool> isInline,
      Value<String?> localPath,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      Value<int> messageId,
      Value<String> partId,
      Value<String> fileName,
      Value<String> mimeType,
      Value<int> size,
      Value<String?> contentId,
      Value<bool> isInline,
      Value<String?> localPath,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MessagesTable _messageIdTable(_$AppDatabase db) =>
      db.messages.createAlias('attachments__message_id__messages__id');

  $$MessagesTableProcessedTableManager get messageId {
    final $_column = $_itemColumn<int>('message_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
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

  ColumnFilters<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInline => $composableBuilder(
    column: $table.isInline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  $$MessagesTableFilterComposer get messageId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
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

  ColumnOrderings<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInline => $composableBuilder(
    column: $table.isInline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessagesTableOrderingComposer get messageId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get partId =>
      $composableBuilder(column: $table.partId, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<bool> get isInline =>
      $composableBuilder(column: $table.isInline, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  $$MessagesTableAnnotationComposer get messageId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (Attachment, $$AttachmentsTableReferences),
          Attachment,
          PrefetchHooks Function({bool messageId})
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String?> contentId = const Value.absent(),
                Value<bool> isInline = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                messageId: messageId,
                partId: partId,
                fileName: fileName,
                mimeType: mimeType,
                size: size,
                contentId: contentId,
                isInline: isInline,
                localPath: localPath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int messageId,
                required String partId,
                Value<String> fileName = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String?> contentId = const Value.absent(),
                Value<bool> isInline = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                messageId: messageId,
                partId: partId,
                fileName: fileName,
                mimeType: mimeType,
                size: size,
                contentId: contentId,
                isInline: isInline,
                localPath: localPath,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttachmentsTable, Attachment>(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
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
                    if (messageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.messageId,
                        referencedTable: $$AttachmentsTableReferences
                            ._messageIdTable(db),
                        referencedColumn: $$AttachmentsTableReferences
                            ._messageIdTable(db)
                            .id,
                      ) as T;
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

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (Attachment, $$AttachmentsTableReferences),
      Attachment,
      PrefetchHooks Function({bool messageId})
    >;
typedef $$PeopleGroupsTableCreateCompanionBuilder =
    PeopleGroupsCompanion Function({
      Value<int> id,
      required String name,
      Value<DateTime> createdAt,
    });
typedef $$PeopleGroupsTableUpdateCompanionBuilder =
    PeopleGroupsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
    });

final class $$PeopleGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $PeopleGroupsTable, PeopleGroup> {
  $$PeopleGroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GroupMembersTable, List<GroupMember>>
  _groupMembersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.groupMembers,
    aliasName: 'people_groups__id__group_members__group_id',
  );

  $$GroupMembersTableProcessedTableManager get groupMembersRefs {
    final manager = $$GroupMembersTableTableManager(
      $_db,
      $_db.groupMembers,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_groupMembersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PeopleGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleGroupsTable> {
  $$PeopleGroupsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> groupMembersRefs(
    Expression<bool> Function($$GroupMembersTableFilterComposer f) f,
  ) {
    final $$GroupMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembers,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableFilterComposer(
            $db: $db,
            $table: $db.groupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleGroupsTable> {
  $$PeopleGroupsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeopleGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleGroupsTable> {
  $$PeopleGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> groupMembersRefs<T extends Object>(
    Expression<T> Function($$GroupMembersTableAnnotationComposer a) f,
  ) {
    final $$GroupMembersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembers,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableAnnotationComposer(
            $db: $db,
            $table: $db.groupMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleGroupsTable,
          PeopleGroup,
          $$PeopleGroupsTableFilterComposer,
          $$PeopleGroupsTableOrderingComposer,
          $$PeopleGroupsTableAnnotationComposer,
          $$PeopleGroupsTableCreateCompanionBuilder,
          $$PeopleGroupsTableUpdateCompanionBuilder,
          (PeopleGroup, $$PeopleGroupsTableReferences),
          PeopleGroup,
          PrefetchHooks Function({bool groupMembersRefs})
        > {
  $$PeopleGroupsTableTableManager(_$AppDatabase db, $PeopleGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeopleGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeopleGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeopleGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) => PeopleGroupsCompanion(id: id, name: name, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<DateTime> createdAt = const Value.absent(),
              }) => PeopleGroupsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PeopleGroupsTable, PeopleGroup>(table),
                  $$PeopleGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupMembersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (groupMembersRefs) db.groupMembers],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (groupMembersRefs)
                    await $_getPrefetchedData<
                      PeopleGroup,
                      $PeopleGroupsTable,
                      GroupMember
                    >(
                      currentTable: table,
                      referencedTable: $$PeopleGroupsTableReferences
                          ._groupMembersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PeopleGroupsTableReferences(
                            db,
                            table,
                            p0,
                          ).groupMembersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.groupId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PeopleGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleGroupsTable,
      PeopleGroup,
      $$PeopleGroupsTableFilterComposer,
      $$PeopleGroupsTableOrderingComposer,
      $$PeopleGroupsTableAnnotationComposer,
      $$PeopleGroupsTableCreateCompanionBuilder,
      $$PeopleGroupsTableUpdateCompanionBuilder,
      (PeopleGroup, $$PeopleGroupsTableReferences),
      PeopleGroup,
      PrefetchHooks Function({bool groupMembersRefs})
    >;
typedef $$GroupMembersTableCreateCompanionBuilder =
    GroupMembersCompanion Function({
      required int groupId,
      required String contactKey,
      Value<int> rowid,
    });
typedef $$GroupMembersTableUpdateCompanionBuilder =
    GroupMembersCompanion Function({
      Value<int> groupId,
      Value<String> contactKey,
      Value<int> rowid,
    });

final class $$GroupMembersTableReferences
    extends BaseReferences<_$AppDatabase, $GroupMembersTable, GroupMember> {
  $$GroupMembersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PeopleGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.peopleGroups.createAlias('group_members__group_id__people_groups__id');

  $$PeopleGroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<int>('group_id')!;

    final manager = $$PeopleGroupsTableTableManager(
      $_db,
      $_db.peopleGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GroupMembersTableFilterComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contactKey => $composableBuilder(
    column: $table.contactKey,
    builder: (column) => ColumnFilters(column),
  );

  $$PeopleGroupsTableFilterComposer get groupId {
    final $$PeopleGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.peopleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleGroupsTableFilterComposer(
            $db: $db,
            $table: $db.peopleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contactKey => $composableBuilder(
    column: $table.contactKey,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeopleGroupsTableOrderingComposer get groupId {
    final $$PeopleGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.peopleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.peopleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contactKey => $composableBuilder(
    column: $table.contactKey,
    builder: (column) => column,
  );

  $$PeopleGroupsTableAnnotationComposer get groupId {
    final $$PeopleGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.peopleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.peopleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupMembersTable,
          GroupMember,
          $$GroupMembersTableFilterComposer,
          $$GroupMembersTableOrderingComposer,
          $$GroupMembersTableAnnotationComposer,
          $$GroupMembersTableCreateCompanionBuilder,
          $$GroupMembersTableUpdateCompanionBuilder,
          (GroupMember, $$GroupMembersTableReferences),
          GroupMember,
          PrefetchHooks Function({bool groupId})
        > {
  $$GroupMembersTableTableManager(_$AppDatabase db, $GroupMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> groupId = const Value.absent(),
                Value<String> contactKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion(
                groupId: groupId,
                contactKey: contactKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int groupId,
                required String contactKey,
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion.insert(
                groupId: groupId,
                contactKey: contactKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GroupMembersTable, GroupMember>(table),
                  $$GroupMembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
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
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$GroupMembersTableReferences
                            ._groupIdTable(db),
                        referencedColumn: $$GroupMembersTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
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

typedef $$GroupMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupMembersTable,
      GroupMember,
      $$GroupMembersTableFilterComposer,
      $$GroupMembersTableOrderingComposer,
      $$GroupMembersTableAnnotationComposer,
      $$GroupMembersTableCreateCompanionBuilder,
      $$GroupMembersTableUpdateCompanionBuilder,
      (GroupMember, $$GroupMembersTableReferences),
      GroupMember,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$MessageRowAssignmentsTableCreateCompanionBuilder =
    MessageRowAssignmentsCompanion Function({
      required int messageId,
      required String rowKey,
      Value<int> rowid,
    });
typedef $$MessageRowAssignmentsTableUpdateCompanionBuilder =
    MessageRowAssignmentsCompanion Function({
      Value<int> messageId,
      Value<String> rowKey,
      Value<int> rowid,
    });

final class $$MessageRowAssignmentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MessageRowAssignmentsTable,
          MessageRowAssignment
        > {
  $$MessageRowAssignmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MessagesTable _messageIdTable(_$AppDatabase db) => db.messages
      .createAlias('message_row_assignments__message_id__messages__id');

  $$MessagesTableProcessedTableManager get messageId {
    final $_column = $_itemColumn<int>('message_id')!;

    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessageRowAssignmentsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageRowAssignmentsTable> {
  $$MessageRowAssignmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rowKey => $composableBuilder(
    column: $table.rowKey,
    builder: (column) => ColumnFilters(column),
  );

  $$MessagesTableFilterComposer get messageId {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageRowAssignmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageRowAssignmentsTable> {
  $$MessageRowAssignmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rowKey => $composableBuilder(
    column: $table.rowKey,
    builder: (column) => ColumnOrderings(column),
  );

  $$MessagesTableOrderingComposer get messageId {
    final $$MessagesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableOrderingComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageRowAssignmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageRowAssignmentsTable> {
  $$MessageRowAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rowKey =>
      $composableBuilder(column: $table.rowKey, builder: (column) => column);

  $$MessagesTableAnnotationComposer get messageId {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessageRowAssignmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageRowAssignmentsTable,
          MessageRowAssignment,
          $$MessageRowAssignmentsTableFilterComposer,
          $$MessageRowAssignmentsTableOrderingComposer,
          $$MessageRowAssignmentsTableAnnotationComposer,
          $$MessageRowAssignmentsTableCreateCompanionBuilder,
          $$MessageRowAssignmentsTableUpdateCompanionBuilder,
          (MessageRowAssignment, $$MessageRowAssignmentsTableReferences),
          MessageRowAssignment,
          PrefetchHooks Function({bool messageId})
        > {
  $$MessageRowAssignmentsTableTableManager(
    _$AppDatabase db,
    $MessageRowAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageRowAssignmentsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MessageRowAssignmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MessageRowAssignmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> messageId = const Value.absent(),
                Value<String> rowKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageRowAssignmentsCompanion(
                messageId: messageId,
                rowKey: rowKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int messageId,
                required String rowKey,
                Value<int> rowid = const Value.absent(),
              }) => MessageRowAssignmentsCompanion.insert(
                messageId: messageId,
                rowKey: rowKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $MessageRowAssignmentsTable,
                    MessageRowAssignment
                  >(table),
                  $$MessageRowAssignmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
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
                    if (messageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.messageId,
                        referencedTable: $$MessageRowAssignmentsTableReferences
                            ._messageIdTable(db),
                        referencedColumn: $$MessageRowAssignmentsTableReferences
                            ._messageIdTable(db)
                            .id,
                      ) as T;
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

typedef $$MessageRowAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageRowAssignmentsTable,
      MessageRowAssignment,
      $$MessageRowAssignmentsTableFilterComposer,
      $$MessageRowAssignmentsTableOrderingComposer,
      $$MessageRowAssignmentsTableAnnotationComposer,
      $$MessageRowAssignmentsTableCreateCompanionBuilder,
      $$MessageRowAssignmentsTableUpdateCompanionBuilder,
      (MessageRowAssignment, $$MessageRowAssignmentsTableReferences),
      MessageRowAssignment,
      PrefetchHooks Function({bool messageId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$IdentitiesTableTableManager get identities =>
      $$IdentitiesTableTableManager(_db, _db.identities);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$MessageParticipantsTableTableManager get messageParticipants =>
      $$MessageParticipantsTableTableManager(_db, _db.messageParticipants);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
  $$ContactAddressesTableTableManager get contactAddresses =>
      $$ContactAddressesTableTableManager(_db, _db.contactAddresses);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$PeopleGroupsTableTableManager get peopleGroups =>
      $$PeopleGroupsTableTableManager(_db, _db.peopleGroups);
  $$GroupMembersTableTableManager get groupMembers =>
      $$GroupMembersTableTableManager(_db, _db.groupMembers);
  $$MessageRowAssignmentsTableTableManager get messageRowAssignments =>
      $$MessageRowAssignmentsTableTableManager(_db, _db.messageRowAssignments);
}
