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
  static const VerificationMeta _discoveredMeta = const VerificationMeta(
    'discovered',
  );
  @override
  late final GeneratedColumn<bool> discovered = GeneratedColumn<bool>(
    'discovered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("discovered" IN (0, 1))',
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
    discovered,
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
    if (data.containsKey('discovered')) {
      context.handle(
        _discoveredMeta,
        discovered.isAcceptableOrUnknown(data['discovered']!, _discoveredMeta),
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
      discovered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}discovered'],
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

  /// True when the identity was learned from the account's Sent folder
  /// (a "send as" alias) rather than entered by the user.
  final bool discovered;
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
    required this.discovered,
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
    map['discovered'] = Variable<bool>(discovered);
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
      discovered: Value(discovered),
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
      discovered: serializer.fromJson<bool>(json['discovered']),
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
      'discovered': serializer.toJson<bool>(discovered),
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
    bool? discovered,
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
    discovered: discovered ?? this.discovered,
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
      discovered: data.discovered.present
          ? data.discovered.value
          : this.discovered,
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
          ..write('isDefault: $isDefault, ')
          ..write('discovered: $discovered')
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
    discovered,
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
          other.isDefault == this.isDefault &&
          other.discovered == this.discovered);
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
  final Value<bool> discovered;
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
    this.discovered = const Value.absent(),
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
    this.discovered = const Value.absent(),
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
    Expression<bool>? discovered,
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
      if (discovered != null) 'discovered': discovered,
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
    Value<bool>? discovered,
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
      discovered: discovered ?? this.discovered,
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
    if (discovered.present) {
      map['discovered'] = Variable<bool>(discovered.value);
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
          ..write('isDefault: $isDefault, ')
          ..write('discovered: $discovered')
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
  static const VerificationMeta _threadKeyMeta = const VerificationMeta(
    'threadKey',
  );
  @override
  late final GeneratedColumn<String> threadKey = GeneratedColumn<String>(
    'thread_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagesAllowedMeta = const VerificationMeta(
    'imagesAllowed',
  );
  @override
  late final GeneratedColumn<bool> imagesAllowed = GeneratedColumn<bool>(
    'images_allowed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("images_allowed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bulkSignalsMeta = const VerificationMeta(
    'bulkSignals',
  );
  @override
  late final GeneratedColumn<String> bulkSignals = GeneratedColumn<String>(
    'bulk_signals',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _classificationMeta = const VerificationMeta(
    'classification',
  );
  @override
  late final GeneratedColumn<String> classification = GeneratedColumn<String>(
    'classification',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('people'),
  );
  static const VerificationMeta _feedsCategoryMeta = const VerificationMeta(
    'feedsCategory',
  );
  @override
  late final GeneratedColumn<String> feedsCategory = GeneratedColumn<String>(
    'feeds_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _icsTextMeta = const VerificationMeta(
    'icsText',
  );
  @override
  late final GeneratedColumn<String> icsText = GeneratedColumn<String>(
    'ics_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extractedAtMeta = const VerificationMeta(
    'extractedAt',
  );
  @override
  late final GeneratedColumn<DateTime> extractedAt = GeneratedColumn<DateTime>(
    'extracted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
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
    threadKey,
    imagesAllowed,
    bulkSignals,
    classification,
    feedsCategory,
    icsText,
    extractedAt,
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
    if (data.containsKey('thread_key')) {
      context.handle(
        _threadKeyMeta,
        threadKey.isAcceptableOrUnknown(data['thread_key']!, _threadKeyMeta),
      );
    }
    if (data.containsKey('images_allowed')) {
      context.handle(
        _imagesAllowedMeta,
        imagesAllowed.isAcceptableOrUnknown(
          data['images_allowed']!,
          _imagesAllowedMeta,
        ),
      );
    }
    if (data.containsKey('bulk_signals')) {
      context.handle(
        _bulkSignalsMeta,
        bulkSignals.isAcceptableOrUnknown(
          data['bulk_signals']!,
          _bulkSignalsMeta,
        ),
      );
    }
    if (data.containsKey('classification')) {
      context.handle(
        _classificationMeta,
        classification.isAcceptableOrUnknown(
          data['classification']!,
          _classificationMeta,
        ),
      );
    }
    if (data.containsKey('feeds_category')) {
      context.handle(
        _feedsCategoryMeta,
        feedsCategory.isAcceptableOrUnknown(
          data['feeds_category']!,
          _feedsCategoryMeta,
        ),
      );
    }
    if (data.containsKey('ics_text')) {
      context.handle(
        _icsTextMeta,
        icsText.isAcceptableOrUnknown(data['ics_text']!, _icsTextMeta),
      );
    }
    if (data.containsKey('extracted_at')) {
      context.handle(
        _extractedAtMeta,
        extractedAt.isAcceptableOrUnknown(
          data['extracted_at']!,
          _extractedAtMeta,
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
      threadKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_key'],
      ),
      imagesAllowed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}images_allowed'],
      )!,
      bulkSignals: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bulk_signals'],
      ),
      classification: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}classification'],
      )!,
      feedsCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feeds_category'],
      ),
      icsText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ics_text'],
      ),
      extractedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}extracted_at'],
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

  /// Thread key from the hybrid threading model (spec 4.20): the root
  /// message's Message-ID, or `m:<id>`. Null until assigned.
  final String? threadKey;

  /// The user chose "Load images" for this message (spec 4.13).
  final bool imagesAllowed;

  /// Encoded [BulkSignals]; null until the list headers were fetched.
  final String? bulkSignals;

  /// `people` or `feeds` for this message (sender bucket with per-message
  /// exceptions, spec 4.11).
  final String classification;

  /// Message-level category when it differs from the sender default.
  final String? feedsCategory;

  /// The `text/calendar` part of an invitation, when the message has one.
  final String? icsText;

  /// When event extraction last ran on this message (spec 4.10).
  final DateTime? extractedAt;
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
    this.threadKey,
    required this.imagesAllowed,
    this.bulkSignals,
    required this.classification,
    this.feedsCategory,
    this.icsText,
    this.extractedAt,
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
    if (!nullToAbsent || threadKey != null) {
      map['thread_key'] = Variable<String>(threadKey);
    }
    map['images_allowed'] = Variable<bool>(imagesAllowed);
    if (!nullToAbsent || bulkSignals != null) {
      map['bulk_signals'] = Variable<String>(bulkSignals);
    }
    map['classification'] = Variable<String>(classification);
    if (!nullToAbsent || feedsCategory != null) {
      map['feeds_category'] = Variable<String>(feedsCategory);
    }
    if (!nullToAbsent || icsText != null) {
      map['ics_text'] = Variable<String>(icsText);
    }
    if (!nullToAbsent || extractedAt != null) {
      map['extracted_at'] = Variable<DateTime>(extractedAt);
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
      threadKey: threadKey == null && nullToAbsent
          ? const Value.absent()
          : Value(threadKey),
      imagesAllowed: Value(imagesAllowed),
      bulkSignals: bulkSignals == null && nullToAbsent
          ? const Value.absent()
          : Value(bulkSignals),
      classification: Value(classification),
      feedsCategory: feedsCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(feedsCategory),
      icsText: icsText == null && nullToAbsent
          ? const Value.absent()
          : Value(icsText),
      extractedAt: extractedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(extractedAt),
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
      threadKey: serializer.fromJson<String?>(json['threadKey']),
      imagesAllowed: serializer.fromJson<bool>(json['imagesAllowed']),
      bulkSignals: serializer.fromJson<String?>(json['bulkSignals']),
      classification: serializer.fromJson<String>(json['classification']),
      feedsCategory: serializer.fromJson<String?>(json['feedsCategory']),
      icsText: serializer.fromJson<String?>(json['icsText']),
      extractedAt: serializer.fromJson<DateTime?>(json['extractedAt']),
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
      'threadKey': serializer.toJson<String?>(threadKey),
      'imagesAllowed': serializer.toJson<bool>(imagesAllowed),
      'bulkSignals': serializer.toJson<String?>(bulkSignals),
      'classification': serializer.toJson<String>(classification),
      'feedsCategory': serializer.toJson<String?>(feedsCategory),
      'icsText': serializer.toJson<String?>(icsText),
      'extractedAt': serializer.toJson<DateTime?>(extractedAt),
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
    Value<String?> threadKey = const Value.absent(),
    bool? imagesAllowed,
    Value<String?> bulkSignals = const Value.absent(),
    String? classification,
    Value<String?> feedsCategory = const Value.absent(),
    Value<String?> icsText = const Value.absent(),
    Value<DateTime?> extractedAt = const Value.absent(),
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
    threadKey: threadKey.present ? threadKey.value : this.threadKey,
    imagesAllowed: imagesAllowed ?? this.imagesAllowed,
    bulkSignals: bulkSignals.present ? bulkSignals.value : this.bulkSignals,
    classification: classification ?? this.classification,
    feedsCategory: feedsCategory.present
        ? feedsCategory.value
        : this.feedsCategory,
    icsText: icsText.present ? icsText.value : this.icsText,
    extractedAt: extractedAt.present ? extractedAt.value : this.extractedAt,
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
      threadKey: data.threadKey.present ? data.threadKey.value : this.threadKey,
      imagesAllowed: data.imagesAllowed.present
          ? data.imagesAllowed.value
          : this.imagesAllowed,
      bulkSignals: data.bulkSignals.present
          ? data.bulkSignals.value
          : this.bulkSignals,
      classification: data.classification.present
          ? data.classification.value
          : this.classification,
      feedsCategory: data.feedsCategory.present
          ? data.feedsCategory.value
          : this.feedsCategory,
      icsText: data.icsText.present ? data.icsText.value : this.icsText,
      extractedAt: data.extractedAt.present
          ? data.extractedAt.value
          : this.extractedAt,
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
          ..write('providerThreadId: $providerThreadId, ')
          ..write('threadKey: $threadKey, ')
          ..write('imagesAllowed: $imagesAllowed, ')
          ..write('bulkSignals: $bulkSignals, ')
          ..write('classification: $classification, ')
          ..write('feedsCategory: $feedsCategory, ')
          ..write('icsText: $icsText, ')
          ..write('extractedAt: $extractedAt')
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
    threadKey,
    imagesAllowed,
    bulkSignals,
    classification,
    feedsCategory,
    icsText,
    extractedAt,
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
          other.providerThreadId == this.providerThreadId &&
          other.threadKey == this.threadKey &&
          other.imagesAllowed == this.imagesAllowed &&
          other.bulkSignals == this.bulkSignals &&
          other.classification == this.classification &&
          other.feedsCategory == this.feedsCategory &&
          other.icsText == this.icsText &&
          other.extractedAt == this.extractedAt);
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
  final Value<String?> threadKey;
  final Value<bool> imagesAllowed;
  final Value<String?> bulkSignals;
  final Value<String> classification;
  final Value<String?> feedsCategory;
  final Value<String?> icsText;
  final Value<DateTime?> extractedAt;
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
    this.threadKey = const Value.absent(),
    this.imagesAllowed = const Value.absent(),
    this.bulkSignals = const Value.absent(),
    this.classification = const Value.absent(),
    this.feedsCategory = const Value.absent(),
    this.icsText = const Value.absent(),
    this.extractedAt = const Value.absent(),
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
    this.threadKey = const Value.absent(),
    this.imagesAllowed = const Value.absent(),
    this.bulkSignals = const Value.absent(),
    this.classification = const Value.absent(),
    this.feedsCategory = const Value.absent(),
    this.icsText = const Value.absent(),
    this.extractedAt = const Value.absent(),
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
    Expression<String>? threadKey,
    Expression<bool>? imagesAllowed,
    Expression<String>? bulkSignals,
    Expression<String>? classification,
    Expression<String>? feedsCategory,
    Expression<String>? icsText,
    Expression<DateTime>? extractedAt,
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
      if (threadKey != null) 'thread_key': threadKey,
      if (imagesAllowed != null) 'images_allowed': imagesAllowed,
      if (bulkSignals != null) 'bulk_signals': bulkSignals,
      if (classification != null) 'classification': classification,
      if (feedsCategory != null) 'feeds_category': feedsCategory,
      if (icsText != null) 'ics_text': icsText,
      if (extractedAt != null) 'extracted_at': extractedAt,
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
    Value<String?>? threadKey,
    Value<bool>? imagesAllowed,
    Value<String?>? bulkSignals,
    Value<String>? classification,
    Value<String?>? feedsCategory,
    Value<String?>? icsText,
    Value<DateTime?>? extractedAt,
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
      threadKey: threadKey ?? this.threadKey,
      imagesAllowed: imagesAllowed ?? this.imagesAllowed,
      bulkSignals: bulkSignals ?? this.bulkSignals,
      classification: classification ?? this.classification,
      feedsCategory: feedsCategory ?? this.feedsCategory,
      icsText: icsText ?? this.icsText,
      extractedAt: extractedAt ?? this.extractedAt,
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
    if (threadKey.present) {
      map['thread_key'] = Variable<String>(threadKey.value);
    }
    if (imagesAllowed.present) {
      map['images_allowed'] = Variable<bool>(imagesAllowed.value);
    }
    if (bulkSignals.present) {
      map['bulk_signals'] = Variable<String>(bulkSignals.value);
    }
    if (classification.present) {
      map['classification'] = Variable<String>(classification.value);
    }
    if (feedsCategory.present) {
      map['feeds_category'] = Variable<String>(feedsCategory.value);
    }
    if (icsText.present) {
      map['ics_text'] = Variable<String>(icsText.value);
    }
    if (extractedAt.present) {
      map['extracted_at'] = Variable<DateTime>(extractedAt.value);
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
          ..write('providerThreadId: $providerThreadId, ')
          ..write('threadKey: $threadKey, ')
          ..write('imagesAllowed: $imagesAllowed, ')
          ..write('bulkSignals: $bulkSignals, ')
          ..write('classification: $classification, ')
          ..write('feedsCategory: $feedsCategory, ')
          ..write('icsText: $icsText, ')
          ..write('extractedAt: $extractedAt')
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
  static const VerificationMeta _classificationMeta = const VerificationMeta(
    'classification',
  );
  @override
  late final GeneratedColumn<String> classification = GeneratedColumn<String>(
    'classification',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('people'),
  );
  static const VerificationMeta _classificationSourceMeta =
      const VerificationMeta('classificationSource');
  @override
  late final GeneratedColumn<String> classificationSource =
      GeneratedColumn<String>(
        'classification_source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('auto'),
      );
  static const VerificationMeta _feedsCategoryMeta = const VerificationMeta(
    'feedsCategory',
  );
  @override
  late final GeneratedColumn<String> feedsCategory = GeneratedColumn<String>(
    'feeds_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countsTowardUnreadMeta =
      const VerificationMeta('countsTowardUnread');
  @override
  late final GeneratedColumn<bool> countsTowardUnread = GeneratedColumn<bool>(
    'counts_toward_unread',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("counts_toward_unread" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _classReasonsMeta = const VerificationMeta(
    'classReasons',
  );
  @override
  late final GeneratedColumn<String> classReasons = GeneratedColumn<String>(
    'class_reasons',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
    classification,
    classificationSource,
    feedsCategory,
    countsTowardUnread,
    classReasons,
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
    if (data.containsKey('classification')) {
      context.handle(
        _classificationMeta,
        classification.isAcceptableOrUnknown(
          data['classification']!,
          _classificationMeta,
        ),
      );
    }
    if (data.containsKey('classification_source')) {
      context.handle(
        _classificationSourceMeta,
        classificationSource.isAcceptableOrUnknown(
          data['classification_source']!,
          _classificationSourceMeta,
        ),
      );
    }
    if (data.containsKey('feeds_category')) {
      context.handle(
        _feedsCategoryMeta,
        feedsCategory.isAcceptableOrUnknown(
          data['feeds_category']!,
          _feedsCategoryMeta,
        ),
      );
    }
    if (data.containsKey('counts_toward_unread')) {
      context.handle(
        _countsTowardUnreadMeta,
        countsTowardUnread.isAcceptableOrUnknown(
          data['counts_toward_unread']!,
          _countsTowardUnreadMeta,
        ),
      );
    }
    if (data.containsKey('class_reasons')) {
      context.handle(
        _classReasonsMeta,
        classReasons.isAcceptableOrUnknown(
          data['class_reasons']!,
          _classReasonsMeta,
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
      classification: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}classification'],
      )!,
      classificationSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}classification_source'],
      )!,
      feedsCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feeds_category'],
      ),
      countsTowardUnread: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}counts_toward_unread'],
      )!,
      classReasons: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_reasons'],
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

  /// Effective bucket (`people` | `feeds`) and how it was decided
  /// (`auto` | `override` | `rule` | `people-signal`).
  final String classification;
  final String classificationSource;

  /// Sender-default Feeds category.
  final String? feedsCategory;

  /// Spec 4.11: a Feeds sender whose unread mail still counts.
  final bool countsTowardUnread;
  final String classReasons;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  const Contact({
    required this.key,
    required this.displayName,
    this.photoPath,
    required this.isMe,
    required this.inAddressBook,
    required this.classification,
    required this.classificationSource,
    this.feedsCategory,
    required this.countsTowardUnread,
    required this.classReasons,
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
    map['classification'] = Variable<String>(classification);
    map['classification_source'] = Variable<String>(classificationSource);
    if (!nullToAbsent || feedsCategory != null) {
      map['feeds_category'] = Variable<String>(feedsCategory);
    }
    map['counts_toward_unread'] = Variable<bool>(countsTowardUnread);
    map['class_reasons'] = Variable<String>(classReasons);
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
      classification: Value(classification),
      classificationSource: Value(classificationSource),
      feedsCategory: feedsCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(feedsCategory),
      countsTowardUnread: Value(countsTowardUnread),
      classReasons: Value(classReasons),
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
      classification: serializer.fromJson<String>(json['classification']),
      classificationSource: serializer.fromJson<String>(
        json['classificationSource'],
      ),
      feedsCategory: serializer.fromJson<String?>(json['feedsCategory']),
      countsTowardUnread: serializer.fromJson<bool>(json['countsTowardUnread']),
      classReasons: serializer.fromJson<String>(json['classReasons']),
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
      'classification': serializer.toJson<String>(classification),
      'classificationSource': serializer.toJson<String>(classificationSource),
      'feedsCategory': serializer.toJson<String?>(feedsCategory),
      'countsTowardUnread': serializer.toJson<bool>(countsTowardUnread),
      'classReasons': serializer.toJson<String>(classReasons),
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
    String? classification,
    String? classificationSource,
    Value<String?> feedsCategory = const Value.absent(),
    bool? countsTowardUnread,
    String? classReasons,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
  }) => Contact(
    key: key ?? this.key,
    displayName: displayName ?? this.displayName,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    isMe: isMe ?? this.isMe,
    inAddressBook: inAddressBook ?? this.inAddressBook,
    classification: classification ?? this.classification,
    classificationSource: classificationSource ?? this.classificationSource,
    feedsCategory: feedsCategory.present
        ? feedsCategory.value
        : this.feedsCategory,
    countsTowardUnread: countsTowardUnread ?? this.countsTowardUnread,
    classReasons: classReasons ?? this.classReasons,
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
      classification: data.classification.present
          ? data.classification.value
          : this.classification,
      classificationSource: data.classificationSource.present
          ? data.classificationSource.value
          : this.classificationSource,
      feedsCategory: data.feedsCategory.present
          ? data.feedsCategory.value
          : this.feedsCategory,
      countsTowardUnread: data.countsTowardUnread.present
          ? data.countsTowardUnread.value
          : this.countsTowardUnread,
      classReasons: data.classReasons.present
          ? data.classReasons.value
          : this.classReasons,
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
          ..write('classification: $classification, ')
          ..write('classificationSource: $classificationSource, ')
          ..write('feedsCategory: $feedsCategory, ')
          ..write('countsTowardUnread: $countsTowardUnread, ')
          ..write('classReasons: $classReasons, ')
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
    classification,
    classificationSource,
    feedsCategory,
    countsTowardUnread,
    classReasons,
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
          other.classification == this.classification &&
          other.classificationSource == this.classificationSource &&
          other.feedsCategory == this.feedsCategory &&
          other.countsTowardUnread == this.countsTowardUnread &&
          other.classReasons == this.classReasons &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class ContactsCompanion extends UpdateCompanion<Contact> {
  final Value<String> key;
  final Value<String> displayName;
  final Value<String?> photoPath;
  final Value<bool> isMe;
  final Value<bool> inAddressBook;
  final Value<String> classification;
  final Value<String> classificationSource;
  final Value<String?> feedsCategory;
  final Value<bool> countsTowardUnread;
  final Value<String> classReasons;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const ContactsCompanion({
    this.key = const Value.absent(),
    this.displayName = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.isMe = const Value.absent(),
    this.inAddressBook = const Value.absent(),
    this.classification = const Value.absent(),
    this.classificationSource = const Value.absent(),
    this.feedsCategory = const Value.absent(),
    this.countsTowardUnread = const Value.absent(),
    this.classReasons = const Value.absent(),
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
    this.classification = const Value.absent(),
    this.classificationSource = const Value.absent(),
    this.feedsCategory = const Value.absent(),
    this.countsTowardUnread = const Value.absent(),
    this.classReasons = const Value.absent(),
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
    Expression<String>? classification,
    Expression<String>? classificationSource,
    Expression<String>? feedsCategory,
    Expression<bool>? countsTowardUnread,
    Expression<String>? classReasons,
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
      if (classification != null) 'classification': classification,
      if (classificationSource != null)
        'classification_source': classificationSource,
      if (feedsCategory != null) 'feeds_category': feedsCategory,
      if (countsTowardUnread != null)
        'counts_toward_unread': countsTowardUnread,
      if (classReasons != null) 'class_reasons': classReasons,
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
    Value<String>? classification,
    Value<String>? classificationSource,
    Value<String?>? feedsCategory,
    Value<bool>? countsTowardUnread,
    Value<String>? classReasons,
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
      classification: classification ?? this.classification,
      classificationSource: classificationSource ?? this.classificationSource,
      feedsCategory: feedsCategory ?? this.feedsCategory,
      countsTowardUnread: countsTowardUnread ?? this.countsTowardUnread,
      classReasons: classReasons ?? this.classReasons,
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
    if (classification.present) {
      map['classification'] = Variable<String>(classification.value);
    }
    if (classificationSource.present) {
      map['classification_source'] = Variable<String>(
        classificationSource.value,
      );
    }
    if (feedsCategory.present) {
      map['feeds_category'] = Variable<String>(feedsCategory.value);
    }
    if (countsTowardUnread.present) {
      map['counts_toward_unread'] = Variable<bool>(countsTowardUnread.value);
    }
    if (classReasons.present) {
      map['class_reasons'] = Variable<String>(classReasons.value);
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
          ..write('classification: $classification, ')
          ..write('classificationSource: $classificationSource, ')
          ..write('feedsCategory: $feedsCategory, ')
          ..write('countsTowardUnread: $countsTowardUnread, ')
          ..write('classReasons: $classReasons, ')
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

class $RowPrefsTable extends RowPrefs with TableInfo<$RowPrefsTable, RowPref> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RowPrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rowKeyMeta = const VerificationMeta('rowKey');
  @override
  late final GeneratedColumn<String> rowKey = GeneratedColumn<String>(
    'row_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _mutedMeta = const VerificationMeta('muted');
  @override
  late final GeneratedColumn<bool> muted = GeneratedColumn<bool>(
    'muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozedUntil = GeneratedColumn<DateTime>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resurfacedAtMeta = const VerificationMeta(
    'resurfacedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resurfacedAt = GeneratedColumn<DateTime>(
    'resurfaced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    rowKey,
    pinned,
    muted,
    snoozedUntil,
    resurfacedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'row_prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RowPref> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_key')) {
      context.handle(
        _rowKeyMeta,
        rowKey.isAcceptableOrUnknown(data['row_key']!, _rowKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_rowKeyMeta);
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('muted')) {
      context.handle(
        _mutedMeta,
        muted.isAcceptableOrUnknown(data['muted']!, _mutedMeta),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('resurfaced_at')) {
      context.handle(
        _resurfacedAtMeta,
        resurfacedAt.isAcceptableOrUnknown(
          data['resurfaced_at']!,
          _resurfacedAtMeta,
        ),
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
  Set<GeneratedColumn> get $primaryKey => {rowKey};
  @override
  RowPref map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RowPref(
      rowKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_key'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      muted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}muted'],
      )!,
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snoozed_until'],
      ),
      resurfacedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resurfaced_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RowPrefsTable createAlias(String alias) {
    return $RowPrefsTable(attachedDatabase, alias);
  }
}

class RowPref extends DataClass implements Insertable<RowPref> {
  final String rowKey;
  final bool pinned;
  final bool muted;
  final DateTime? snoozedUntil;

  /// Set when a snooze ends: the row sorts as if newly received (spec 4.9).
  final DateTime? resurfacedAt;
  final DateTime updatedAt;
  const RowPref({
    required this.rowKey,
    required this.pinned,
    required this.muted,
    this.snoozedUntil,
    this.resurfacedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_key'] = Variable<String>(rowKey);
    map['pinned'] = Variable<bool>(pinned);
    map['muted'] = Variable<bool>(muted);
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil);
    }
    if (!nullToAbsent || resurfacedAt != null) {
      map['resurfaced_at'] = Variable<DateTime>(resurfacedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RowPrefsCompanion toCompanion(bool nullToAbsent) {
    return RowPrefsCompanion(
      rowKey: Value(rowKey),
      pinned: Value(pinned),
      muted: Value(muted),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      resurfacedAt: resurfacedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resurfacedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RowPref.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RowPref(
      rowKey: serializer.fromJson<String>(json['rowKey']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      muted: serializer.fromJson<bool>(json['muted']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
      resurfacedAt: serializer.fromJson<DateTime?>(json['resurfacedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowKey': serializer.toJson<String>(rowKey),
      'pinned': serializer.toJson<bool>(pinned),
      'muted': serializer.toJson<bool>(muted),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
      'resurfacedAt': serializer.toJson<DateTime?>(resurfacedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RowPref copyWith({
    String? rowKey,
    bool? pinned,
    bool? muted,
    Value<DateTime?> snoozedUntil = const Value.absent(),
    Value<DateTime?> resurfacedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => RowPref(
    rowKey: rowKey ?? this.rowKey,
    pinned: pinned ?? this.pinned,
    muted: muted ?? this.muted,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    resurfacedAt: resurfacedAt.present ? resurfacedAt.value : this.resurfacedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RowPref copyWithCompanion(RowPrefsCompanion data) {
    return RowPref(
      rowKey: data.rowKey.present ? data.rowKey.value : this.rowKey,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      muted: data.muted.present ? data.muted.value : this.muted,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      resurfacedAt: data.resurfacedAt.present
          ? data.resurfacedAt.value
          : this.resurfacedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RowPref(')
          ..write('rowKey: $rowKey, ')
          ..write('pinned: $pinned, ')
          ..write('muted: $muted, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('resurfacedAt: $resurfacedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(rowKey, pinned, muted, snoozedUntil, resurfacedAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RowPref &&
          other.rowKey == this.rowKey &&
          other.pinned == this.pinned &&
          other.muted == this.muted &&
          other.snoozedUntil == this.snoozedUntil &&
          other.resurfacedAt == this.resurfacedAt &&
          other.updatedAt == this.updatedAt);
}

class RowPrefsCompanion extends UpdateCompanion<RowPref> {
  final Value<String> rowKey;
  final Value<bool> pinned;
  final Value<bool> muted;
  final Value<DateTime?> snoozedUntil;
  final Value<DateTime?> resurfacedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RowPrefsCompanion({
    this.rowKey = const Value.absent(),
    this.pinned = const Value.absent(),
    this.muted = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.resurfacedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RowPrefsCompanion.insert({
    required String rowKey,
    this.pinned = const Value.absent(),
    this.muted = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.resurfacedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : rowKey = Value(rowKey);
  static Insertable<RowPref> custom({
    Expression<String>? rowKey,
    Expression<bool>? pinned,
    Expression<bool>? muted,
    Expression<DateTime>? snoozedUntil,
    Expression<DateTime>? resurfacedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rowKey != null) 'row_key': rowKey,
      if (pinned != null) 'pinned': pinned,
      if (muted != null) 'muted': muted,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (resurfacedAt != null) 'resurfaced_at': resurfacedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RowPrefsCompanion copyWith({
    Value<String>? rowKey,
    Value<bool>? pinned,
    Value<bool>? muted,
    Value<DateTime?>? snoozedUntil,
    Value<DateTime?>? resurfacedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RowPrefsCompanion(
      rowKey: rowKey ?? this.rowKey,
      pinned: pinned ?? this.pinned,
      muted: muted ?? this.muted,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      resurfacedAt: resurfacedAt ?? this.resurfacedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowKey.present) {
      map['row_key'] = Variable<String>(rowKey.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (muted.present) {
      map['muted'] = Variable<bool>(muted.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil.value);
    }
    if (resurfacedAt.present) {
      map['resurfaced_at'] = Variable<DateTime>(resurfacedAt.value);
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
    return (StringBuffer('RowPrefsCompanion(')
          ..write('rowKey: $rowKey, ')
          ..write('pinned: $pinned, ')
          ..write('muted: $muted, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('resurfacedAt: $resurfacedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RowSummariesTable extends RowSummaries
    with TableInfo<$RowSummariesTable, RowSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RowSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rowKeyMeta = const VerificationMeta('rowKey');
  @override
  late final GeneratedColumn<String> rowKey = GeneratedColumn<String>(
    'row_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unreadMeta = const VerificationMeta('unread');
  @override
  late final GeneratedColumn<int> unread = GeneratedColumn<int>(
    'unread',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReceivedMeta = const VerificationMeta(
    'lastReceived',
  );
  @override
  late final GeneratedColumn<DateTime> lastReceived = GeneratedColumn<DateTime>(
    'last_received',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAnyMeta = const VerificationMeta(
    'lastAny',
  );
  @override
  late final GeneratedColumn<DateTime> lastAny = GeneratedColumn<DateTime>(
    'last_any',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasStarredMeta = const VerificationMeta(
    'hasStarred',
  );
  @override
  late final GeneratedColumn<bool> hasStarred = GeneratedColumn<bool>(
    'has_starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_starred" IN (0, 1))',
    ),
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
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_attachments" IN (0, 1))',
    ),
  );
  static const VerificationMeta _hasSentMeta = const VerificationMeta(
    'hasSent',
  );
  @override
  late final GeneratedColumn<bool> hasSent = GeneratedColumn<bool>(
    'has_sent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_sent" IN (0, 1))',
    ),
  );
  static const VerificationMeta _newestMessageIdMeta = const VerificationMeta(
    'newestMessageId',
  );
  @override
  late final GeneratedColumn<int> newestMessageId = GeneratedColumn<int>(
    'newest_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _peopleTotalMeta = const VerificationMeta(
    'peopleTotal',
  );
  @override
  late final GeneratedColumn<int> peopleTotal = GeneratedColumn<int>(
    'people_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _peopleUnreadMeta = const VerificationMeta(
    'peopleUnread',
  );
  @override
  late final GeneratedColumn<int> peopleUnread = GeneratedColumn<int>(
    'people_unread',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _feedsTotalMeta = const VerificationMeta(
    'feedsTotal',
  );
  @override
  late final GeneratedColumn<int> feedsTotal = GeneratedColumn<int>(
    'feeds_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _feedsUnreadMeta = const VerificationMeta(
    'feedsUnread',
  );
  @override
  late final GeneratedColumn<int> feedsUnread = GeneratedColumn<int>(
    'feeds_unread',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPeopleMeta = const VerificationMeta(
    'lastPeople',
  );
  @override
  late final GeneratedColumn<DateTime> lastPeople = GeneratedColumn<DateTime>(
    'last_people',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastFeedsMeta = const VerificationMeta(
    'lastFeeds',
  );
  @override
  late final GeneratedColumn<DateTime> lastFeeds = GeneratedColumn<DateTime>(
    'last_feeds',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newestPeopleIdMeta = const VerificationMeta(
    'newestPeopleId',
  );
  @override
  late final GeneratedColumn<int> newestPeopleId = GeneratedColumn<int>(
    'newest_people_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _newestFeedsIdMeta = const VerificationMeta(
    'newestFeedsId',
  );
  @override
  late final GeneratedColumn<int> newestFeedsId = GeneratedColumn<int>(
    'newest_feeds_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    rowKey,
    total,
    unread,
    lastReceived,
    lastAny,
    hasStarred,
    hasAttachments,
    hasSent,
    newestMessageId,
    updatedAt,
    peopleTotal,
    peopleUnread,
    feedsTotal,
    feedsUnread,
    lastPeople,
    lastFeeds,
    newestPeopleId,
    newestFeedsId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'row_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RowSummary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_key')) {
      context.handle(
        _rowKeyMeta,
        rowKey.isAcceptableOrUnknown(data['row_key']!, _rowKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_rowKeyMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('unread')) {
      context.handle(
        _unreadMeta,
        unread.isAcceptableOrUnknown(data['unread']!, _unreadMeta),
      );
    } else if (isInserting) {
      context.missing(_unreadMeta);
    }
    if (data.containsKey('last_received')) {
      context.handle(
        _lastReceivedMeta,
        lastReceived.isAcceptableOrUnknown(
          data['last_received']!,
          _lastReceivedMeta,
        ),
      );
    }
    if (data.containsKey('last_any')) {
      context.handle(
        _lastAnyMeta,
        lastAny.isAcceptableOrUnknown(data['last_any']!, _lastAnyMeta),
      );
    }
    if (data.containsKey('has_starred')) {
      context.handle(
        _hasStarredMeta,
        hasStarred.isAcceptableOrUnknown(data['has_starred']!, _hasStarredMeta),
      );
    } else if (isInserting) {
      context.missing(_hasStarredMeta);
    }
    if (data.containsKey('has_attachments')) {
      context.handle(
        _hasAttachmentsMeta,
        hasAttachments.isAcceptableOrUnknown(
          data['has_attachments']!,
          _hasAttachmentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hasAttachmentsMeta);
    }
    if (data.containsKey('has_sent')) {
      context.handle(
        _hasSentMeta,
        hasSent.isAcceptableOrUnknown(data['has_sent']!, _hasSentMeta),
      );
    } else if (isInserting) {
      context.missing(_hasSentMeta);
    }
    if (data.containsKey('newest_message_id')) {
      context.handle(
        _newestMessageIdMeta,
        newestMessageId.isAcceptableOrUnknown(
          data['newest_message_id']!,
          _newestMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('people_total')) {
      context.handle(
        _peopleTotalMeta,
        peopleTotal.isAcceptableOrUnknown(
          data['people_total']!,
          _peopleTotalMeta,
        ),
      );
    }
    if (data.containsKey('people_unread')) {
      context.handle(
        _peopleUnreadMeta,
        peopleUnread.isAcceptableOrUnknown(
          data['people_unread']!,
          _peopleUnreadMeta,
        ),
      );
    }
    if (data.containsKey('feeds_total')) {
      context.handle(
        _feedsTotalMeta,
        feedsTotal.isAcceptableOrUnknown(data['feeds_total']!, _feedsTotalMeta),
      );
    }
    if (data.containsKey('feeds_unread')) {
      context.handle(
        _feedsUnreadMeta,
        feedsUnread.isAcceptableOrUnknown(
          data['feeds_unread']!,
          _feedsUnreadMeta,
        ),
      );
    }
    if (data.containsKey('last_people')) {
      context.handle(
        _lastPeopleMeta,
        lastPeople.isAcceptableOrUnknown(data['last_people']!, _lastPeopleMeta),
      );
    }
    if (data.containsKey('last_feeds')) {
      context.handle(
        _lastFeedsMeta,
        lastFeeds.isAcceptableOrUnknown(data['last_feeds']!, _lastFeedsMeta),
      );
    }
    if (data.containsKey('newest_people_id')) {
      context.handle(
        _newestPeopleIdMeta,
        newestPeopleId.isAcceptableOrUnknown(
          data['newest_people_id']!,
          _newestPeopleIdMeta,
        ),
      );
    }
    if (data.containsKey('newest_feeds_id')) {
      context.handle(
        _newestFeedsIdMeta,
        newestFeedsId.isAcceptableOrUnknown(
          data['newest_feeds_id']!,
          _newestFeedsIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rowKey};
  @override
  RowSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RowSummary(
      rowKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_key'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      unread: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread'],
      )!,
      lastReceived: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_received'],
      ),
      lastAny: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_any'],
      ),
      hasStarred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_starred'],
      )!,
      hasAttachments: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_attachments'],
      )!,
      hasSent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_sent'],
      )!,
      newestMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}newest_message_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      peopleTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}people_total'],
      )!,
      peopleUnread: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}people_unread'],
      )!,
      feedsTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}feeds_total'],
      )!,
      feedsUnread: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}feeds_unread'],
      )!,
      lastPeople: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_people'],
      ),
      lastFeeds: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_feeds'],
      ),
      newestPeopleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}newest_people_id'],
      ),
      newestFeedsId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}newest_feeds_id'],
      ),
    );
  }

  @override
  $RowSummariesTable createAlias(String alias) {
    return $RowSummariesTable(attachedDatabase, alias);
  }
}

class RowSummary extends DataClass implements Insertable<RowSummary> {
  final String rowKey;
  final int total;
  final int unread;

  /// Newest message not from me (ordering for contact rows, decision 4).
  final DateTime? lastReceived;

  /// Newest message of any sender (ordering for group rows, preview).
  final DateTime? lastAny;
  final bool hasStarred;
  final bool hasAttachments;
  final bool hasSent;
  final int? newestMessageId;
  final DateTime updatedAt;

  /// Per-bucket figures (spec 4.11): a row shows in People when it has
  /// People messages and in Feeds when it has Feeds messages.
  final int peopleTotal;
  final int peopleUnread;
  final int feedsTotal;
  final int feedsUnread;
  final DateTime? lastPeople;
  final DateTime? lastFeeds;
  final int? newestPeopleId;
  final int? newestFeedsId;
  const RowSummary({
    required this.rowKey,
    required this.total,
    required this.unread,
    this.lastReceived,
    this.lastAny,
    required this.hasStarred,
    required this.hasAttachments,
    required this.hasSent,
    this.newestMessageId,
    required this.updatedAt,
    required this.peopleTotal,
    required this.peopleUnread,
    required this.feedsTotal,
    required this.feedsUnread,
    this.lastPeople,
    this.lastFeeds,
    this.newestPeopleId,
    this.newestFeedsId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_key'] = Variable<String>(rowKey);
    map['total'] = Variable<int>(total);
    map['unread'] = Variable<int>(unread);
    if (!nullToAbsent || lastReceived != null) {
      map['last_received'] = Variable<DateTime>(lastReceived);
    }
    if (!nullToAbsent || lastAny != null) {
      map['last_any'] = Variable<DateTime>(lastAny);
    }
    map['has_starred'] = Variable<bool>(hasStarred);
    map['has_attachments'] = Variable<bool>(hasAttachments);
    map['has_sent'] = Variable<bool>(hasSent);
    if (!nullToAbsent || newestMessageId != null) {
      map['newest_message_id'] = Variable<int>(newestMessageId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['people_total'] = Variable<int>(peopleTotal);
    map['people_unread'] = Variable<int>(peopleUnread);
    map['feeds_total'] = Variable<int>(feedsTotal);
    map['feeds_unread'] = Variable<int>(feedsUnread);
    if (!nullToAbsent || lastPeople != null) {
      map['last_people'] = Variable<DateTime>(lastPeople);
    }
    if (!nullToAbsent || lastFeeds != null) {
      map['last_feeds'] = Variable<DateTime>(lastFeeds);
    }
    if (!nullToAbsent || newestPeopleId != null) {
      map['newest_people_id'] = Variable<int>(newestPeopleId);
    }
    if (!nullToAbsent || newestFeedsId != null) {
      map['newest_feeds_id'] = Variable<int>(newestFeedsId);
    }
    return map;
  }

  RowSummariesCompanion toCompanion(bool nullToAbsent) {
    return RowSummariesCompanion(
      rowKey: Value(rowKey),
      total: Value(total),
      unread: Value(unread),
      lastReceived: lastReceived == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReceived),
      lastAny: lastAny == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAny),
      hasStarred: Value(hasStarred),
      hasAttachments: Value(hasAttachments),
      hasSent: Value(hasSent),
      newestMessageId: newestMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(newestMessageId),
      updatedAt: Value(updatedAt),
      peopleTotal: Value(peopleTotal),
      peopleUnread: Value(peopleUnread),
      feedsTotal: Value(feedsTotal),
      feedsUnread: Value(feedsUnread),
      lastPeople: lastPeople == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPeople),
      lastFeeds: lastFeeds == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFeeds),
      newestPeopleId: newestPeopleId == null && nullToAbsent
          ? const Value.absent()
          : Value(newestPeopleId),
      newestFeedsId: newestFeedsId == null && nullToAbsent
          ? const Value.absent()
          : Value(newestFeedsId),
    );
  }

  factory RowSummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RowSummary(
      rowKey: serializer.fromJson<String>(json['rowKey']),
      total: serializer.fromJson<int>(json['total']),
      unread: serializer.fromJson<int>(json['unread']),
      lastReceived: serializer.fromJson<DateTime?>(json['lastReceived']),
      lastAny: serializer.fromJson<DateTime?>(json['lastAny']),
      hasStarred: serializer.fromJson<bool>(json['hasStarred']),
      hasAttachments: serializer.fromJson<bool>(json['hasAttachments']),
      hasSent: serializer.fromJson<bool>(json['hasSent']),
      newestMessageId: serializer.fromJson<int?>(json['newestMessageId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      peopleTotal: serializer.fromJson<int>(json['peopleTotal']),
      peopleUnread: serializer.fromJson<int>(json['peopleUnread']),
      feedsTotal: serializer.fromJson<int>(json['feedsTotal']),
      feedsUnread: serializer.fromJson<int>(json['feedsUnread']),
      lastPeople: serializer.fromJson<DateTime?>(json['lastPeople']),
      lastFeeds: serializer.fromJson<DateTime?>(json['lastFeeds']),
      newestPeopleId: serializer.fromJson<int?>(json['newestPeopleId']),
      newestFeedsId: serializer.fromJson<int?>(json['newestFeedsId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowKey': serializer.toJson<String>(rowKey),
      'total': serializer.toJson<int>(total),
      'unread': serializer.toJson<int>(unread),
      'lastReceived': serializer.toJson<DateTime?>(lastReceived),
      'lastAny': serializer.toJson<DateTime?>(lastAny),
      'hasStarred': serializer.toJson<bool>(hasStarred),
      'hasAttachments': serializer.toJson<bool>(hasAttachments),
      'hasSent': serializer.toJson<bool>(hasSent),
      'newestMessageId': serializer.toJson<int?>(newestMessageId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'peopleTotal': serializer.toJson<int>(peopleTotal),
      'peopleUnread': serializer.toJson<int>(peopleUnread),
      'feedsTotal': serializer.toJson<int>(feedsTotal),
      'feedsUnread': serializer.toJson<int>(feedsUnread),
      'lastPeople': serializer.toJson<DateTime?>(lastPeople),
      'lastFeeds': serializer.toJson<DateTime?>(lastFeeds),
      'newestPeopleId': serializer.toJson<int?>(newestPeopleId),
      'newestFeedsId': serializer.toJson<int?>(newestFeedsId),
    };
  }

  RowSummary copyWith({
    String? rowKey,
    int? total,
    int? unread,
    Value<DateTime?> lastReceived = const Value.absent(),
    Value<DateTime?> lastAny = const Value.absent(),
    bool? hasStarred,
    bool? hasAttachments,
    bool? hasSent,
    Value<int?> newestMessageId = const Value.absent(),
    DateTime? updatedAt,
    int? peopleTotal,
    int? peopleUnread,
    int? feedsTotal,
    int? feedsUnread,
    Value<DateTime?> lastPeople = const Value.absent(),
    Value<DateTime?> lastFeeds = const Value.absent(),
    Value<int?> newestPeopleId = const Value.absent(),
    Value<int?> newestFeedsId = const Value.absent(),
  }) => RowSummary(
    rowKey: rowKey ?? this.rowKey,
    total: total ?? this.total,
    unread: unread ?? this.unread,
    lastReceived: lastReceived.present ? lastReceived.value : this.lastReceived,
    lastAny: lastAny.present ? lastAny.value : this.lastAny,
    hasStarred: hasStarred ?? this.hasStarred,
    hasAttachments: hasAttachments ?? this.hasAttachments,
    hasSent: hasSent ?? this.hasSent,
    newestMessageId: newestMessageId.present
        ? newestMessageId.value
        : this.newestMessageId,
    updatedAt: updatedAt ?? this.updatedAt,
    peopleTotal: peopleTotal ?? this.peopleTotal,
    peopleUnread: peopleUnread ?? this.peopleUnread,
    feedsTotal: feedsTotal ?? this.feedsTotal,
    feedsUnread: feedsUnread ?? this.feedsUnread,
    lastPeople: lastPeople.present ? lastPeople.value : this.lastPeople,
    lastFeeds: lastFeeds.present ? lastFeeds.value : this.lastFeeds,
    newestPeopleId: newestPeopleId.present
        ? newestPeopleId.value
        : this.newestPeopleId,
    newestFeedsId: newestFeedsId.present
        ? newestFeedsId.value
        : this.newestFeedsId,
  );
  RowSummary copyWithCompanion(RowSummariesCompanion data) {
    return RowSummary(
      rowKey: data.rowKey.present ? data.rowKey.value : this.rowKey,
      total: data.total.present ? data.total.value : this.total,
      unread: data.unread.present ? data.unread.value : this.unread,
      lastReceived: data.lastReceived.present
          ? data.lastReceived.value
          : this.lastReceived,
      lastAny: data.lastAny.present ? data.lastAny.value : this.lastAny,
      hasStarred: data.hasStarred.present
          ? data.hasStarred.value
          : this.hasStarred,
      hasAttachments: data.hasAttachments.present
          ? data.hasAttachments.value
          : this.hasAttachments,
      hasSent: data.hasSent.present ? data.hasSent.value : this.hasSent,
      newestMessageId: data.newestMessageId.present
          ? data.newestMessageId.value
          : this.newestMessageId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      peopleTotal: data.peopleTotal.present
          ? data.peopleTotal.value
          : this.peopleTotal,
      peopleUnread: data.peopleUnread.present
          ? data.peopleUnread.value
          : this.peopleUnread,
      feedsTotal: data.feedsTotal.present
          ? data.feedsTotal.value
          : this.feedsTotal,
      feedsUnread: data.feedsUnread.present
          ? data.feedsUnread.value
          : this.feedsUnread,
      lastPeople: data.lastPeople.present
          ? data.lastPeople.value
          : this.lastPeople,
      lastFeeds: data.lastFeeds.present ? data.lastFeeds.value : this.lastFeeds,
      newestPeopleId: data.newestPeopleId.present
          ? data.newestPeopleId.value
          : this.newestPeopleId,
      newestFeedsId: data.newestFeedsId.present
          ? data.newestFeedsId.value
          : this.newestFeedsId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RowSummary(')
          ..write('rowKey: $rowKey, ')
          ..write('total: $total, ')
          ..write('unread: $unread, ')
          ..write('lastReceived: $lastReceived, ')
          ..write('lastAny: $lastAny, ')
          ..write('hasStarred: $hasStarred, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('hasSent: $hasSent, ')
          ..write('newestMessageId: $newestMessageId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('peopleTotal: $peopleTotal, ')
          ..write('peopleUnread: $peopleUnread, ')
          ..write('feedsTotal: $feedsTotal, ')
          ..write('feedsUnread: $feedsUnread, ')
          ..write('lastPeople: $lastPeople, ')
          ..write('lastFeeds: $lastFeeds, ')
          ..write('newestPeopleId: $newestPeopleId, ')
          ..write('newestFeedsId: $newestFeedsId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rowKey,
    total,
    unread,
    lastReceived,
    lastAny,
    hasStarred,
    hasAttachments,
    hasSent,
    newestMessageId,
    updatedAt,
    peopleTotal,
    peopleUnread,
    feedsTotal,
    feedsUnread,
    lastPeople,
    lastFeeds,
    newestPeopleId,
    newestFeedsId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RowSummary &&
          other.rowKey == this.rowKey &&
          other.total == this.total &&
          other.unread == this.unread &&
          other.lastReceived == this.lastReceived &&
          other.lastAny == this.lastAny &&
          other.hasStarred == this.hasStarred &&
          other.hasAttachments == this.hasAttachments &&
          other.hasSent == this.hasSent &&
          other.newestMessageId == this.newestMessageId &&
          other.updatedAt == this.updatedAt &&
          other.peopleTotal == this.peopleTotal &&
          other.peopleUnread == this.peopleUnread &&
          other.feedsTotal == this.feedsTotal &&
          other.feedsUnread == this.feedsUnread &&
          other.lastPeople == this.lastPeople &&
          other.lastFeeds == this.lastFeeds &&
          other.newestPeopleId == this.newestPeopleId &&
          other.newestFeedsId == this.newestFeedsId);
}

class RowSummariesCompanion extends UpdateCompanion<RowSummary> {
  final Value<String> rowKey;
  final Value<int> total;
  final Value<int> unread;
  final Value<DateTime?> lastReceived;
  final Value<DateTime?> lastAny;
  final Value<bool> hasStarred;
  final Value<bool> hasAttachments;
  final Value<bool> hasSent;
  final Value<int?> newestMessageId;
  final Value<DateTime> updatedAt;
  final Value<int> peopleTotal;
  final Value<int> peopleUnread;
  final Value<int> feedsTotal;
  final Value<int> feedsUnread;
  final Value<DateTime?> lastPeople;
  final Value<DateTime?> lastFeeds;
  final Value<int?> newestPeopleId;
  final Value<int?> newestFeedsId;
  final Value<int> rowid;
  const RowSummariesCompanion({
    this.rowKey = const Value.absent(),
    this.total = const Value.absent(),
    this.unread = const Value.absent(),
    this.lastReceived = const Value.absent(),
    this.lastAny = const Value.absent(),
    this.hasStarred = const Value.absent(),
    this.hasAttachments = const Value.absent(),
    this.hasSent = const Value.absent(),
    this.newestMessageId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.peopleTotal = const Value.absent(),
    this.peopleUnread = const Value.absent(),
    this.feedsTotal = const Value.absent(),
    this.feedsUnread = const Value.absent(),
    this.lastPeople = const Value.absent(),
    this.lastFeeds = const Value.absent(),
    this.newestPeopleId = const Value.absent(),
    this.newestFeedsId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RowSummariesCompanion.insert({
    required String rowKey,
    required int total,
    required int unread,
    this.lastReceived = const Value.absent(),
    this.lastAny = const Value.absent(),
    required bool hasStarred,
    required bool hasAttachments,
    required bool hasSent,
    this.newestMessageId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.peopleTotal = const Value.absent(),
    this.peopleUnread = const Value.absent(),
    this.feedsTotal = const Value.absent(),
    this.feedsUnread = const Value.absent(),
    this.lastPeople = const Value.absent(),
    this.lastFeeds = const Value.absent(),
    this.newestPeopleId = const Value.absent(),
    this.newestFeedsId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : rowKey = Value(rowKey),
       total = Value(total),
       unread = Value(unread),
       hasStarred = Value(hasStarred),
       hasAttachments = Value(hasAttachments),
       hasSent = Value(hasSent);
  static Insertable<RowSummary> custom({
    Expression<String>? rowKey,
    Expression<int>? total,
    Expression<int>? unread,
    Expression<DateTime>? lastReceived,
    Expression<DateTime>? lastAny,
    Expression<bool>? hasStarred,
    Expression<bool>? hasAttachments,
    Expression<bool>? hasSent,
    Expression<int>? newestMessageId,
    Expression<DateTime>? updatedAt,
    Expression<int>? peopleTotal,
    Expression<int>? peopleUnread,
    Expression<int>? feedsTotal,
    Expression<int>? feedsUnread,
    Expression<DateTime>? lastPeople,
    Expression<DateTime>? lastFeeds,
    Expression<int>? newestPeopleId,
    Expression<int>? newestFeedsId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rowKey != null) 'row_key': rowKey,
      if (total != null) 'total': total,
      if (unread != null) 'unread': unread,
      if (lastReceived != null) 'last_received': lastReceived,
      if (lastAny != null) 'last_any': lastAny,
      if (hasStarred != null) 'has_starred': hasStarred,
      if (hasAttachments != null) 'has_attachments': hasAttachments,
      if (hasSent != null) 'has_sent': hasSent,
      if (newestMessageId != null) 'newest_message_id': newestMessageId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (peopleTotal != null) 'people_total': peopleTotal,
      if (peopleUnread != null) 'people_unread': peopleUnread,
      if (feedsTotal != null) 'feeds_total': feedsTotal,
      if (feedsUnread != null) 'feeds_unread': feedsUnread,
      if (lastPeople != null) 'last_people': lastPeople,
      if (lastFeeds != null) 'last_feeds': lastFeeds,
      if (newestPeopleId != null) 'newest_people_id': newestPeopleId,
      if (newestFeedsId != null) 'newest_feeds_id': newestFeedsId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RowSummariesCompanion copyWith({
    Value<String>? rowKey,
    Value<int>? total,
    Value<int>? unread,
    Value<DateTime?>? lastReceived,
    Value<DateTime?>? lastAny,
    Value<bool>? hasStarred,
    Value<bool>? hasAttachments,
    Value<bool>? hasSent,
    Value<int?>? newestMessageId,
    Value<DateTime>? updatedAt,
    Value<int>? peopleTotal,
    Value<int>? peopleUnread,
    Value<int>? feedsTotal,
    Value<int>? feedsUnread,
    Value<DateTime?>? lastPeople,
    Value<DateTime?>? lastFeeds,
    Value<int?>? newestPeopleId,
    Value<int?>? newestFeedsId,
    Value<int>? rowid,
  }) {
    return RowSummariesCompanion(
      rowKey: rowKey ?? this.rowKey,
      total: total ?? this.total,
      unread: unread ?? this.unread,
      lastReceived: lastReceived ?? this.lastReceived,
      lastAny: lastAny ?? this.lastAny,
      hasStarred: hasStarred ?? this.hasStarred,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      hasSent: hasSent ?? this.hasSent,
      newestMessageId: newestMessageId ?? this.newestMessageId,
      updatedAt: updatedAt ?? this.updatedAt,
      peopleTotal: peopleTotal ?? this.peopleTotal,
      peopleUnread: peopleUnread ?? this.peopleUnread,
      feedsTotal: feedsTotal ?? this.feedsTotal,
      feedsUnread: feedsUnread ?? this.feedsUnread,
      lastPeople: lastPeople ?? this.lastPeople,
      lastFeeds: lastFeeds ?? this.lastFeeds,
      newestPeopleId: newestPeopleId ?? this.newestPeopleId,
      newestFeedsId: newestFeedsId ?? this.newestFeedsId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowKey.present) {
      map['row_key'] = Variable<String>(rowKey.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (unread.present) {
      map['unread'] = Variable<int>(unread.value);
    }
    if (lastReceived.present) {
      map['last_received'] = Variable<DateTime>(lastReceived.value);
    }
    if (lastAny.present) {
      map['last_any'] = Variable<DateTime>(lastAny.value);
    }
    if (hasStarred.present) {
      map['has_starred'] = Variable<bool>(hasStarred.value);
    }
    if (hasAttachments.present) {
      map['has_attachments'] = Variable<bool>(hasAttachments.value);
    }
    if (hasSent.present) {
      map['has_sent'] = Variable<bool>(hasSent.value);
    }
    if (newestMessageId.present) {
      map['newest_message_id'] = Variable<int>(newestMessageId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (peopleTotal.present) {
      map['people_total'] = Variable<int>(peopleTotal.value);
    }
    if (peopleUnread.present) {
      map['people_unread'] = Variable<int>(peopleUnread.value);
    }
    if (feedsTotal.present) {
      map['feeds_total'] = Variable<int>(feedsTotal.value);
    }
    if (feedsUnread.present) {
      map['feeds_unread'] = Variable<int>(feedsUnread.value);
    }
    if (lastPeople.present) {
      map['last_people'] = Variable<DateTime>(lastPeople.value);
    }
    if (lastFeeds.present) {
      map['last_feeds'] = Variable<DateTime>(lastFeeds.value);
    }
    if (newestPeopleId.present) {
      map['newest_people_id'] = Variable<int>(newestPeopleId.value);
    }
    if (newestFeedsId.present) {
      map['newest_feeds_id'] = Variable<int>(newestFeedsId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RowSummariesCompanion(')
          ..write('rowKey: $rowKey, ')
          ..write('total: $total, ')
          ..write('unread: $unread, ')
          ..write('lastReceived: $lastReceived, ')
          ..write('lastAny: $lastAny, ')
          ..write('hasStarred: $hasStarred, ')
          ..write('hasAttachments: $hasAttachments, ')
          ..write('hasSent: $hasSent, ')
          ..write('newestMessageId: $newestMessageId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('peopleTotal: $peopleTotal, ')
          ..write('peopleUnread: $peopleUnread, ')
          ..write('feedsTotal: $feedsTotal, ')
          ..write('feedsUnread: $feedsUnread, ')
          ..write('lastPeople: $lastPeople, ')
          ..write('lastFeeds: $lastFeeds, ')
          ..write('newestPeopleId: $newestPeopleId, ')
          ..write('newestFeedsId: $newestFeedsId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DirtyRowsTable extends DirtyRows
    with TableInfo<$DirtyRowsTable, DirtyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DirtyRowsTable(this.attachedDatabase, [this._alias]);
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
  List<GeneratedColumn> get $columns => [rowKey];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dirty_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<DirtyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
  Set<GeneratedColumn> get $primaryKey => {rowKey};
  @override
  DirtyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DirtyRow(
      rowKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_key'],
      )!,
    );
  }

  @override
  $DirtyRowsTable createAlias(String alias) {
    return $DirtyRowsTable(attachedDatabase, alias);
  }
}

class DirtyRow extends DataClass implements Insertable<DirtyRow> {
  final String rowKey;
  const DirtyRow({required this.rowKey});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_key'] = Variable<String>(rowKey);
    return map;
  }

  DirtyRowsCompanion toCompanion(bool nullToAbsent) {
    return DirtyRowsCompanion(rowKey: Value(rowKey));
  }

  factory DirtyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DirtyRow(rowKey: serializer.fromJson<String>(json['rowKey']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'rowKey': serializer.toJson<String>(rowKey)};
  }

  DirtyRow copyWith({String? rowKey}) =>
      DirtyRow(rowKey: rowKey ?? this.rowKey);
  DirtyRow copyWithCompanion(DirtyRowsCompanion data) {
    return DirtyRow(
      rowKey: data.rowKey.present ? data.rowKey.value : this.rowKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DirtyRow(')
          ..write('rowKey: $rowKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => rowKey.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DirtyRow && other.rowKey == this.rowKey);
}

class DirtyRowsCompanion extends UpdateCompanion<DirtyRow> {
  final Value<String> rowKey;
  final Value<int> rowid;
  const DirtyRowsCompanion({
    this.rowKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DirtyRowsCompanion.insert({
    required String rowKey,
    this.rowid = const Value.absent(),
  }) : rowKey = Value(rowKey);
  static Insertable<DirtyRow> custom({
    Expression<String>? rowKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rowKey != null) 'row_key': rowKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DirtyRowsCompanion copyWith({Value<String>? rowKey, Value<int>? rowid}) {
    return DirtyRowsCompanion(
      rowKey: rowKey ?? this.rowKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
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
    return (StringBuffer('DirtyRowsCompanion(')
          ..write('rowKey: $rowKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackerEventsTable extends TrackerEvents
    with TableInfo<$TrackerEventsTable, TrackerEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackerEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isTrackerMeta = const VerificationMeta(
    'isTracker',
  );
  @override
  late final GeneratedColumn<bool> isTracker = GeneratedColumn<bool>(
    'is_tracker',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_tracker" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _blockedMeta = const VerificationMeta(
    'blocked',
  );
  @override
  late final GeneratedColumn<bool> blocked = GeneratedColumn<bool>(
    'blocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("blocked" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messageId,
    host,
    isTracker,
    blocked,
    at,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracker_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackerEvent> instance, {
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
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('is_tracker')) {
      context.handle(
        _isTrackerMeta,
        isTracker.isAcceptableOrUnknown(data['is_tracker']!, _isTrackerMeta),
      );
    }
    if (data.containsKey('blocked')) {
      context.handle(
        _blockedMeta,
        blocked.isAcceptableOrUnknown(data['blocked']!, _blockedMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackerEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackerEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      isTracker: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_tracker'],
      )!,
      blocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}blocked'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $TrackerEventsTable createAlias(String alias) {
    return $TrackerEventsTable(attachedDatabase, alias);
  }
}

class TrackerEvent extends DataClass implements Insertable<TrackerEvent> {
  final int id;
  final int messageId;
  final String host;
  final bool isTracker;
  final bool blocked;
  final DateTime at;
  const TrackerEvent({
    required this.id,
    required this.messageId,
    required this.host,
    required this.isTracker,
    required this.blocked,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['message_id'] = Variable<int>(messageId);
    map['host'] = Variable<String>(host);
    map['is_tracker'] = Variable<bool>(isTracker);
    map['blocked'] = Variable<bool>(blocked);
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  TrackerEventsCompanion toCompanion(bool nullToAbsent) {
    return TrackerEventsCompanion(
      id: Value(id),
      messageId: Value(messageId),
      host: Value(host),
      isTracker: Value(isTracker),
      blocked: Value(blocked),
      at: Value(at),
    );
  }

  factory TrackerEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackerEvent(
      id: serializer.fromJson<int>(json['id']),
      messageId: serializer.fromJson<int>(json['messageId']),
      host: serializer.fromJson<String>(json['host']),
      isTracker: serializer.fromJson<bool>(json['isTracker']),
      blocked: serializer.fromJson<bool>(json['blocked']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'messageId': serializer.toJson<int>(messageId),
      'host': serializer.toJson<String>(host),
      'isTracker': serializer.toJson<bool>(isTracker),
      'blocked': serializer.toJson<bool>(blocked),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  TrackerEvent copyWith({
    int? id,
    int? messageId,
    String? host,
    bool? isTracker,
    bool? blocked,
    DateTime? at,
  }) => TrackerEvent(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    host: host ?? this.host,
    isTracker: isTracker ?? this.isTracker,
    blocked: blocked ?? this.blocked,
    at: at ?? this.at,
  );
  TrackerEvent copyWithCompanion(TrackerEventsCompanion data) {
    return TrackerEvent(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      host: data.host.present ? data.host.value : this.host,
      isTracker: data.isTracker.present ? data.isTracker.value : this.isTracker,
      blocked: data.blocked.present ? data.blocked.value : this.blocked,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackerEvent(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('host: $host, ')
          ..write('isTracker: $isTracker, ')
          ..write('blocked: $blocked, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, messageId, host, isTracker, blocked, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackerEvent &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.host == this.host &&
          other.isTracker == this.isTracker &&
          other.blocked == this.blocked &&
          other.at == this.at);
}

class TrackerEventsCompanion extends UpdateCompanion<TrackerEvent> {
  final Value<int> id;
  final Value<int> messageId;
  final Value<String> host;
  final Value<bool> isTracker;
  final Value<bool> blocked;
  final Value<DateTime> at;
  const TrackerEventsCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.host = const Value.absent(),
    this.isTracker = const Value.absent(),
    this.blocked = const Value.absent(),
    this.at = const Value.absent(),
  });
  TrackerEventsCompanion.insert({
    this.id = const Value.absent(),
    required int messageId,
    required String host,
    this.isTracker = const Value.absent(),
    this.blocked = const Value.absent(),
    this.at = const Value.absent(),
  }) : messageId = Value(messageId),
       host = Value(host);
  static Insertable<TrackerEvent> custom({
    Expression<int>? id,
    Expression<int>? messageId,
    Expression<String>? host,
    Expression<bool>? isTracker,
    Expression<bool>? blocked,
    Expression<DateTime>? at,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (host != null) 'host': host,
      if (isTracker != null) 'is_tracker': isTracker,
      if (blocked != null) 'blocked': blocked,
      if (at != null) 'at': at,
    });
  }

  TrackerEventsCompanion copyWith({
    Value<int>? id,
    Value<int>? messageId,
    Value<String>? host,
    Value<bool>? isTracker,
    Value<bool>? blocked,
    Value<DateTime>? at,
  }) {
    return TrackerEventsCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      host: host ?? this.host,
      isTracker: isTracker ?? this.isTracker,
      blocked: blocked ?? this.blocked,
      at: at ?? this.at,
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
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (isTracker.present) {
      map['is_tracker'] = Variable<bool>(isTracker.value);
    }
    if (blocked.present) {
      map['blocked'] = Variable<bool>(blocked.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackerEventsCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('host: $host, ')
          ..write('isTracker: $isTracker, ')
          ..write('blocked: $blocked, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, Draft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _identityIdMeta = const VerificationMeta(
    'identityId',
  );
  @override
  late final GeneratedColumn<int> identityId = GeneratedColumn<int>(
    'identity_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('new'),
  );
  static const VerificationMeta _rowKeyMeta = const VerificationMeta('rowKey');
  @override
  late final GeneratedColumn<String> rowKey = GeneratedColumn<String>(
    'row_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inReplyToMessageIdMeta =
      const VerificationMeta('inReplyToMessageId');
  @override
  late final GeneratedColumn<int> inReplyToMessageId = GeneratedColumn<int>(
    'in_reply_to_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recipientsToMeta = const VerificationMeta(
    'recipientsTo',
  );
  @override
  late final GeneratedColumn<String> recipientsTo = GeneratedColumn<String>(
    'recipients_to',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _recipientsCcMeta = const VerificationMeta(
    'recipientsCc',
  );
  @override
  late final GeneratedColumn<String> recipientsCc = GeneratedColumn<String>(
    'recipients_cc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _recipientsBccMeta = const VerificationMeta(
    'recipientsBcc',
  );
  @override
  late final GeneratedColumn<String> recipientsBcc = GeneratedColumn<String>(
    'recipients_bcc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
  static const VerificationMeta _bodyJsonMeta = const VerificationMeta(
    'bodyJson',
  );
  @override
  late final GeneratedColumn<String> bodyJson = GeneratedColumn<String>(
    'body_json',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _attachmentsJsonMeta = const VerificationMeta(
    'attachmentsJson',
  );
  @override
  late final GeneratedColumn<String> attachmentsJson = GeneratedColumn<String>(
    'attachments_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _includeQuoteMeta = const VerificationMeta(
    'includeQuote',
  );
  @override
  late final GeneratedColumn<bool> includeQuote = GeneratedColumn<bool>(
    'include_quote',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_quote" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
    accountId,
    identityId,
    kind,
    rowKey,
    inReplyToMessageId,
    recipientsTo,
    recipientsCc,
    recipientsBcc,
    subject,
    bodyJson,
    bodyHtml,
    attachmentsJson,
    includeQuote,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Draft> instance, {
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
    if (data.containsKey('identity_id')) {
      context.handle(
        _identityIdMeta,
        identityId.isAcceptableOrUnknown(data['identity_id']!, _identityIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('row_key')) {
      context.handle(
        _rowKeyMeta,
        rowKey.isAcceptableOrUnknown(data['row_key']!, _rowKeyMeta),
      );
    }
    if (data.containsKey('in_reply_to_message_id')) {
      context.handle(
        _inReplyToMessageIdMeta,
        inReplyToMessageId.isAcceptableOrUnknown(
          data['in_reply_to_message_id']!,
          _inReplyToMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('recipients_to')) {
      context.handle(
        _recipientsToMeta,
        recipientsTo.isAcceptableOrUnknown(
          data['recipients_to']!,
          _recipientsToMeta,
        ),
      );
    }
    if (data.containsKey('recipients_cc')) {
      context.handle(
        _recipientsCcMeta,
        recipientsCc.isAcceptableOrUnknown(
          data['recipients_cc']!,
          _recipientsCcMeta,
        ),
      );
    }
    if (data.containsKey('recipients_bcc')) {
      context.handle(
        _recipientsBccMeta,
        recipientsBcc.isAcceptableOrUnknown(
          data['recipients_bcc']!,
          _recipientsBccMeta,
        ),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('body_json')) {
      context.handle(
        _bodyJsonMeta,
        bodyJson.isAcceptableOrUnknown(data['body_json']!, _bodyJsonMeta),
      );
    }
    if (data.containsKey('body_html')) {
      context.handle(
        _bodyHtmlMeta,
        bodyHtml.isAcceptableOrUnknown(data['body_html']!, _bodyHtmlMeta),
      );
    }
    if (data.containsKey('attachments_json')) {
      context.handle(
        _attachmentsJsonMeta,
        attachmentsJson.isAcceptableOrUnknown(
          data['attachments_json']!,
          _attachmentsJsonMeta,
        ),
      );
    }
    if (data.containsKey('include_quote')) {
      context.handle(
        _includeQuoteMeta,
        includeQuote.isAcceptableOrUnknown(
          data['include_quote']!,
          _includeQuoteMeta,
        ),
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
  Draft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Draft(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_id'],
      )!,
      identityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}identity_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      rowKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_key'],
      ),
      inReplyToMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}in_reply_to_message_id'],
      ),
      recipientsTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipients_to'],
      )!,
      recipientsCc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipients_cc'],
      )!,
      recipientsBcc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipients_bcc'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      bodyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_json'],
      ),
      bodyHtml: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_html'],
      )!,
      attachmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments_json'],
      )!,
      includeQuote: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_quote'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }
}

class Draft extends DataClass implements Insertable<Draft> {
  final int id;
  final int accountId;
  final int? identityId;

  /// `new`, `reply`, `replyAll`, or `forward`.
  final String kind;

  /// People-list row the composer was opened from (replies/forwards).
  final String? rowKey;

  /// Local id of the message being replied to / forwarded.
  final int? inReplyToMessageId;
  final String recipientsTo;
  final String recipientsCc;
  final String recipientsBcc;
  final String subject;

  /// Editor document (appflowy JSON) so formatting survives a restart.
  final String? bodyJson;
  final String bodyHtml;
  final String attachmentsJson;
  final bool includeQuote;
  final DateTime updatedAt;
  const Draft({
    required this.id,
    required this.accountId,
    this.identityId,
    required this.kind,
    this.rowKey,
    this.inReplyToMessageId,
    required this.recipientsTo,
    required this.recipientsCc,
    required this.recipientsBcc,
    required this.subject,
    this.bodyJson,
    required this.bodyHtml,
    required this.attachmentsJson,
    required this.includeQuote,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    if (!nullToAbsent || identityId != null) {
      map['identity_id'] = Variable<int>(identityId);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || rowKey != null) {
      map['row_key'] = Variable<String>(rowKey);
    }
    if (!nullToAbsent || inReplyToMessageId != null) {
      map['in_reply_to_message_id'] = Variable<int>(inReplyToMessageId);
    }
    map['recipients_to'] = Variable<String>(recipientsTo);
    map['recipients_cc'] = Variable<String>(recipientsCc);
    map['recipients_bcc'] = Variable<String>(recipientsBcc);
    map['subject'] = Variable<String>(subject);
    if (!nullToAbsent || bodyJson != null) {
      map['body_json'] = Variable<String>(bodyJson);
    }
    map['body_html'] = Variable<String>(bodyHtml);
    map['attachments_json'] = Variable<String>(attachmentsJson);
    map['include_quote'] = Variable<bool>(includeQuote);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      identityId: identityId == null && nullToAbsent
          ? const Value.absent()
          : Value(identityId),
      kind: Value(kind),
      rowKey: rowKey == null && nullToAbsent
          ? const Value.absent()
          : Value(rowKey),
      inReplyToMessageId: inReplyToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(inReplyToMessageId),
      recipientsTo: Value(recipientsTo),
      recipientsCc: Value(recipientsCc),
      recipientsBcc: Value(recipientsBcc),
      subject: Value(subject),
      bodyJson: bodyJson == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyJson),
      bodyHtml: Value(bodyHtml),
      attachmentsJson: Value(attachmentsJson),
      includeQuote: Value(includeQuote),
      updatedAt: Value(updatedAt),
    );
  }

  factory Draft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Draft(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      identityId: serializer.fromJson<int?>(json['identityId']),
      kind: serializer.fromJson<String>(json['kind']),
      rowKey: serializer.fromJson<String?>(json['rowKey']),
      inReplyToMessageId: serializer.fromJson<int?>(json['inReplyToMessageId']),
      recipientsTo: serializer.fromJson<String>(json['recipientsTo']),
      recipientsCc: serializer.fromJson<String>(json['recipientsCc']),
      recipientsBcc: serializer.fromJson<String>(json['recipientsBcc']),
      subject: serializer.fromJson<String>(json['subject']),
      bodyJson: serializer.fromJson<String?>(json['bodyJson']),
      bodyHtml: serializer.fromJson<String>(json['bodyHtml']),
      attachmentsJson: serializer.fromJson<String>(json['attachmentsJson']),
      includeQuote: serializer.fromJson<bool>(json['includeQuote']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'identityId': serializer.toJson<int?>(identityId),
      'kind': serializer.toJson<String>(kind),
      'rowKey': serializer.toJson<String?>(rowKey),
      'inReplyToMessageId': serializer.toJson<int?>(inReplyToMessageId),
      'recipientsTo': serializer.toJson<String>(recipientsTo),
      'recipientsCc': serializer.toJson<String>(recipientsCc),
      'recipientsBcc': serializer.toJson<String>(recipientsBcc),
      'subject': serializer.toJson<String>(subject),
      'bodyJson': serializer.toJson<String?>(bodyJson),
      'bodyHtml': serializer.toJson<String>(bodyHtml),
      'attachmentsJson': serializer.toJson<String>(attachmentsJson),
      'includeQuote': serializer.toJson<bool>(includeQuote),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Draft copyWith({
    int? id,
    int? accountId,
    Value<int?> identityId = const Value.absent(),
    String? kind,
    Value<String?> rowKey = const Value.absent(),
    Value<int?> inReplyToMessageId = const Value.absent(),
    String? recipientsTo,
    String? recipientsCc,
    String? recipientsBcc,
    String? subject,
    Value<String?> bodyJson = const Value.absent(),
    String? bodyHtml,
    String? attachmentsJson,
    bool? includeQuote,
    DateTime? updatedAt,
  }) => Draft(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    identityId: identityId.present ? identityId.value : this.identityId,
    kind: kind ?? this.kind,
    rowKey: rowKey.present ? rowKey.value : this.rowKey,
    inReplyToMessageId: inReplyToMessageId.present
        ? inReplyToMessageId.value
        : this.inReplyToMessageId,
    recipientsTo: recipientsTo ?? this.recipientsTo,
    recipientsCc: recipientsCc ?? this.recipientsCc,
    recipientsBcc: recipientsBcc ?? this.recipientsBcc,
    subject: subject ?? this.subject,
    bodyJson: bodyJson.present ? bodyJson.value : this.bodyJson,
    bodyHtml: bodyHtml ?? this.bodyHtml,
    attachmentsJson: attachmentsJson ?? this.attachmentsJson,
    includeQuote: includeQuote ?? this.includeQuote,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Draft copyWithCompanion(DraftsCompanion data) {
    return Draft(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      identityId: data.identityId.present
          ? data.identityId.value
          : this.identityId,
      kind: data.kind.present ? data.kind.value : this.kind,
      rowKey: data.rowKey.present ? data.rowKey.value : this.rowKey,
      inReplyToMessageId: data.inReplyToMessageId.present
          ? data.inReplyToMessageId.value
          : this.inReplyToMessageId,
      recipientsTo: data.recipientsTo.present
          ? data.recipientsTo.value
          : this.recipientsTo,
      recipientsCc: data.recipientsCc.present
          ? data.recipientsCc.value
          : this.recipientsCc,
      recipientsBcc: data.recipientsBcc.present
          ? data.recipientsBcc.value
          : this.recipientsBcc,
      subject: data.subject.present ? data.subject.value : this.subject,
      bodyJson: data.bodyJson.present ? data.bodyJson.value : this.bodyJson,
      bodyHtml: data.bodyHtml.present ? data.bodyHtml.value : this.bodyHtml,
      attachmentsJson: data.attachmentsJson.present
          ? data.attachmentsJson.value
          : this.attachmentsJson,
      includeQuote: data.includeQuote.present
          ? data.includeQuote.value
          : this.includeQuote,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Draft(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('identityId: $identityId, ')
          ..write('kind: $kind, ')
          ..write('rowKey: $rowKey, ')
          ..write('inReplyToMessageId: $inReplyToMessageId, ')
          ..write('recipientsTo: $recipientsTo, ')
          ..write('recipientsCc: $recipientsCc, ')
          ..write('recipientsBcc: $recipientsBcc, ')
          ..write('subject: $subject, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('bodyHtml: $bodyHtml, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('includeQuote: $includeQuote, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    identityId,
    kind,
    rowKey,
    inReplyToMessageId,
    recipientsTo,
    recipientsCc,
    recipientsBcc,
    subject,
    bodyJson,
    bodyHtml,
    attachmentsJson,
    includeQuote,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Draft &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.identityId == this.identityId &&
          other.kind == this.kind &&
          other.rowKey == this.rowKey &&
          other.inReplyToMessageId == this.inReplyToMessageId &&
          other.recipientsTo == this.recipientsTo &&
          other.recipientsCc == this.recipientsCc &&
          other.recipientsBcc == this.recipientsBcc &&
          other.subject == this.subject &&
          other.bodyJson == this.bodyJson &&
          other.bodyHtml == this.bodyHtml &&
          other.attachmentsJson == this.attachmentsJson &&
          other.includeQuote == this.includeQuote &&
          other.updatedAt == this.updatedAt);
}

class DraftsCompanion extends UpdateCompanion<Draft> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<int?> identityId;
  final Value<String> kind;
  final Value<String?> rowKey;
  final Value<int?> inReplyToMessageId;
  final Value<String> recipientsTo;
  final Value<String> recipientsCc;
  final Value<String> recipientsBcc;
  final Value<String> subject;
  final Value<String?> bodyJson;
  final Value<String> bodyHtml;
  final Value<String> attachmentsJson;
  final Value<bool> includeQuote;
  final Value<DateTime> updatedAt;
  const DraftsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.identityId = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowKey = const Value.absent(),
    this.inReplyToMessageId = const Value.absent(),
    this.recipientsTo = const Value.absent(),
    this.recipientsCc = const Value.absent(),
    this.recipientsBcc = const Value.absent(),
    this.subject = const Value.absent(),
    this.bodyJson = const Value.absent(),
    this.bodyHtml = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.includeQuote = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DraftsCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    this.identityId = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowKey = const Value.absent(),
    this.inReplyToMessageId = const Value.absent(),
    this.recipientsTo = const Value.absent(),
    this.recipientsCc = const Value.absent(),
    this.recipientsBcc = const Value.absent(),
    this.subject = const Value.absent(),
    this.bodyJson = const Value.absent(),
    this.bodyHtml = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.includeQuote = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : accountId = Value(accountId);
  static Insertable<Draft> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<int>? identityId,
    Expression<String>? kind,
    Expression<String>? rowKey,
    Expression<int>? inReplyToMessageId,
    Expression<String>? recipientsTo,
    Expression<String>? recipientsCc,
    Expression<String>? recipientsBcc,
    Expression<String>? subject,
    Expression<String>? bodyJson,
    Expression<String>? bodyHtml,
    Expression<String>? attachmentsJson,
    Expression<bool>? includeQuote,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (identityId != null) 'identity_id': identityId,
      if (kind != null) 'kind': kind,
      if (rowKey != null) 'row_key': rowKey,
      if (inReplyToMessageId != null)
        'in_reply_to_message_id': inReplyToMessageId,
      if (recipientsTo != null) 'recipients_to': recipientsTo,
      if (recipientsCc != null) 'recipients_cc': recipientsCc,
      if (recipientsBcc != null) 'recipients_bcc': recipientsBcc,
      if (subject != null) 'subject': subject,
      if (bodyJson != null) 'body_json': bodyJson,
      if (bodyHtml != null) 'body_html': bodyHtml,
      if (attachmentsJson != null) 'attachments_json': attachmentsJson,
      if (includeQuote != null) 'include_quote': includeQuote,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DraftsCompanion copyWith({
    Value<int>? id,
    Value<int>? accountId,
    Value<int?>? identityId,
    Value<String>? kind,
    Value<String?>? rowKey,
    Value<int?>? inReplyToMessageId,
    Value<String>? recipientsTo,
    Value<String>? recipientsCc,
    Value<String>? recipientsBcc,
    Value<String>? subject,
    Value<String?>? bodyJson,
    Value<String>? bodyHtml,
    Value<String>? attachmentsJson,
    Value<bool>? includeQuote,
    Value<DateTime>? updatedAt,
  }) {
    return DraftsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      identityId: identityId ?? this.identityId,
      kind: kind ?? this.kind,
      rowKey: rowKey ?? this.rowKey,
      inReplyToMessageId: inReplyToMessageId ?? this.inReplyToMessageId,
      recipientsTo: recipientsTo ?? this.recipientsTo,
      recipientsCc: recipientsCc ?? this.recipientsCc,
      recipientsBcc: recipientsBcc ?? this.recipientsBcc,
      subject: subject ?? this.subject,
      bodyJson: bodyJson ?? this.bodyJson,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      includeQuote: includeQuote ?? this.includeQuote,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (identityId.present) {
      map['identity_id'] = Variable<int>(identityId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowKey.present) {
      map['row_key'] = Variable<String>(rowKey.value);
    }
    if (inReplyToMessageId.present) {
      map['in_reply_to_message_id'] = Variable<int>(inReplyToMessageId.value);
    }
    if (recipientsTo.present) {
      map['recipients_to'] = Variable<String>(recipientsTo.value);
    }
    if (recipientsCc.present) {
      map['recipients_cc'] = Variable<String>(recipientsCc.value);
    }
    if (recipientsBcc.present) {
      map['recipients_bcc'] = Variable<String>(recipientsBcc.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (bodyJson.present) {
      map['body_json'] = Variable<String>(bodyJson.value);
    }
    if (bodyHtml.present) {
      map['body_html'] = Variable<String>(bodyHtml.value);
    }
    if (attachmentsJson.present) {
      map['attachments_json'] = Variable<String>(attachmentsJson.value);
    }
    if (includeQuote.present) {
      map['include_quote'] = Variable<bool>(includeQuote.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('identityId: $identityId, ')
          ..write('kind: $kind, ')
          ..write('rowKey: $rowKey, ')
          ..write('inReplyToMessageId: $inReplyToMessageId, ')
          ..write('recipientsTo: $recipientsTo, ')
          ..write('recipientsCc: $recipientsCc, ')
          ..write('recipientsBcc: $recipientsBcc, ')
          ..write('subject: $subject, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('bodyHtml: $bodyHtml, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('includeQuote: $includeQuote, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $FeedsCategoryRowsTable extends FeedsCategoryRows
    with TableInfo<$FeedsCategoryRowsTable, FeedsCategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedsCategoryRowsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _builtinMeta = const VerificationMeta(
    'builtin',
  );
  @override
  late final GeneratedColumn<bool> builtin = GeneratedColumn<bool>(
    'builtin',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("builtin" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [id, name, builtin, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feeds_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeedsCategoryRow> instance, {
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
    if (data.containsKey('builtin')) {
      context.handle(
        _builtinMeta,
        builtin.isAcceptableOrUnknown(data['builtin']!, _builtinMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FeedsCategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedsCategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      builtin: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}builtin'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $FeedsCategoryRowsTable createAlias(String alias) {
    return $FeedsCategoryRowsTable(attachedDatabase, alias);
  }
}

class FeedsCategoryRow extends DataClass
    implements Insertable<FeedsCategoryRow> {
  final int id;
  final String name;
  final bool builtin;
  final int sortOrder;
  const FeedsCategoryRow({
    required this.id,
    required this.name,
    required this.builtin,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['builtin'] = Variable<bool>(builtin);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  FeedsCategoryRowsCompanion toCompanion(bool nullToAbsent) {
    return FeedsCategoryRowsCompanion(
      id: Value(id),
      name: Value(name),
      builtin: Value(builtin),
      sortOrder: Value(sortOrder),
    );
  }

  factory FeedsCategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedsCategoryRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      builtin: serializer.fromJson<bool>(json['builtin']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'builtin': serializer.toJson<bool>(builtin),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  FeedsCategoryRow copyWith({
    int? id,
    String? name,
    bool? builtin,
    int? sortOrder,
  }) => FeedsCategoryRow(
    id: id ?? this.id,
    name: name ?? this.name,
    builtin: builtin ?? this.builtin,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  FeedsCategoryRow copyWithCompanion(FeedsCategoryRowsCompanion data) {
    return FeedsCategoryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      builtin: data.builtin.present ? data.builtin.value : this.builtin,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedsCategoryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('builtin: $builtin, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, builtin, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedsCategoryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.builtin == this.builtin &&
          other.sortOrder == this.sortOrder);
}

class FeedsCategoryRowsCompanion extends UpdateCompanion<FeedsCategoryRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> builtin;
  final Value<int> sortOrder;
  const FeedsCategoryRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.builtin = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  FeedsCategoryRowsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.builtin = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : name = Value(name);
  static Insertable<FeedsCategoryRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? builtin,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (builtin != null) 'builtin': builtin,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  FeedsCategoryRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? builtin,
    Value<int>? sortOrder,
  }) {
    return FeedsCategoryRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      builtin: builtin ?? this.builtin,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (builtin.present) {
      map['builtin'] = Variable<bool>(builtin.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedsCategoryRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('builtin: $builtin, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $ClassificationRulesTable extends ClassificationRules
    with TableInfo<$ClassificationRulesTable, ClassificationRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassificationRulesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketMeta = const VerificationMeta('bucket');
  @override
  late final GeneratedColumn<String> bucket = GeneratedColumn<String>(
    'bucket',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    field,
    pattern,
    bucket,
    category,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'classification_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassificationRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('bucket')) {
      context.handle(
        _bucketMeta,
        bucket.isAcceptableOrUnknown(data['bucket']!, _bucketMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
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
  ClassificationRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassificationRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      bucket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ClassificationRulesTable createAlias(String alias) {
    return $ClassificationRulesTable(attachedDatabase, alias);
  }
}

class ClassificationRule extends DataClass
    implements Insertable<ClassificationRule> {
  final int id;
  final String field;
  final String pattern;
  final String? bucket;
  final String? category;
  final DateTime createdAt;
  const ClassificationRule({
    required this.id,
    required this.field,
    required this.pattern,
    this.bucket,
    this.category,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['field'] = Variable<String>(field);
    map['pattern'] = Variable<String>(pattern);
    if (!nullToAbsent || bucket != null) {
      map['bucket'] = Variable<String>(bucket);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ClassificationRulesCompanion toCompanion(bool nullToAbsent) {
    return ClassificationRulesCompanion(
      id: Value(id),
      field: Value(field),
      pattern: Value(pattern),
      bucket: bucket == null && nullToAbsent
          ? const Value.absent()
          : Value(bucket),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      createdAt: Value(createdAt),
    );
  }

  factory ClassificationRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClassificationRule(
      id: serializer.fromJson<int>(json['id']),
      field: serializer.fromJson<String>(json['field']),
      pattern: serializer.fromJson<String>(json['pattern']),
      bucket: serializer.fromJson<String?>(json['bucket']),
      category: serializer.fromJson<String?>(json['category']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'field': serializer.toJson<String>(field),
      'pattern': serializer.toJson<String>(pattern),
      'bucket': serializer.toJson<String?>(bucket),
      'category': serializer.toJson<String?>(category),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ClassificationRule copyWith({
    int? id,
    String? field,
    String? pattern,
    Value<String?> bucket = const Value.absent(),
    Value<String?> category = const Value.absent(),
    DateTime? createdAt,
  }) => ClassificationRule(
    id: id ?? this.id,
    field: field ?? this.field,
    pattern: pattern ?? this.pattern,
    bucket: bucket.present ? bucket.value : this.bucket,
    category: category.present ? category.value : this.category,
    createdAt: createdAt ?? this.createdAt,
  );
  ClassificationRule copyWithCompanion(ClassificationRulesCompanion data) {
    return ClassificationRule(
      id: data.id.present ? data.id.value : this.id,
      field: data.field.present ? data.field.value : this.field,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      bucket: data.bucket.present ? data.bucket.value : this.bucket,
      category: data.category.present ? data.category.value : this.category,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationRule(')
          ..write('id: $id, ')
          ..write('field: $field, ')
          ..write('pattern: $pattern, ')
          ..write('bucket: $bucket, ')
          ..write('category: $category, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, field, pattern, bucket, category, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassificationRule &&
          other.id == this.id &&
          other.field == this.field &&
          other.pattern == this.pattern &&
          other.bucket == this.bucket &&
          other.category == this.category &&
          other.createdAt == this.createdAt);
}

class ClassificationRulesCompanion extends UpdateCompanion<ClassificationRule> {
  final Value<int> id;
  final Value<String> field;
  final Value<String> pattern;
  final Value<String?> bucket;
  final Value<String?> category;
  final Value<DateTime> createdAt;
  const ClassificationRulesCompanion({
    this.id = const Value.absent(),
    this.field = const Value.absent(),
    this.pattern = const Value.absent(),
    this.bucket = const Value.absent(),
    this.category = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ClassificationRulesCompanion.insert({
    this.id = const Value.absent(),
    required String field,
    required String pattern,
    this.bucket = const Value.absent(),
    this.category = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : field = Value(field),
       pattern = Value(pattern);
  static Insertable<ClassificationRule> custom({
    Expression<int>? id,
    Expression<String>? field,
    Expression<String>? pattern,
    Expression<String>? bucket,
    Expression<String>? category,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (field != null) 'field': field,
      if (pattern != null) 'pattern': pattern,
      if (bucket != null) 'bucket': bucket,
      if (category != null) 'category': category,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ClassificationRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? field,
    Value<String>? pattern,
    Value<String?>? bucket,
    Value<String?>? category,
    Value<DateTime>? createdAt,
  }) {
    return ClassificationRulesCompanion(
      id: id ?? this.id,
      field: field ?? this.field,
      pattern: pattern ?? this.pattern,
      bucket: bucket ?? this.bucket,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (bucket.present) {
      map['bucket'] = Variable<String>(bucket.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationRulesCompanion(')
          ..write('id: $id, ')
          ..write('field: $field, ')
          ..write('pattern: $pattern, ')
          ..write('bucket: $bucket, ')
          ..write('category: $category, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ClassificationEventsTable extends ClassificationEvents
    with TableInfo<$ClassificationEventsTable, ClassificationEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassificationEventsTable(this.attachedDatabase, [this._alias]);
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
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _decisionMeta = const VerificationMeta(
    'decision',
  );
  @override
  late final GeneratedColumn<String> decision = GeneratedColumn<String>(
    'decision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonsMeta = const VerificationMeta(
    'reasons',
  );
  @override
  late final GeneratedColumn<String> reasons = GeneratedColumn<String>(
    'reasons',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messageId,
    contactKey,
    decision,
    category,
    reasons,
    source,
    at,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'classification_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassificationEvent> instance, {
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
    }
    if (data.containsKey('contact_key')) {
      context.handle(
        _contactKeyMeta,
        contactKey.isAcceptableOrUnknown(data['contact_key']!, _contactKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_contactKeyMeta);
    }
    if (data.containsKey('decision')) {
      context.handle(
        _decisionMeta,
        decision.isAcceptableOrUnknown(data['decision']!, _decisionMeta),
      );
    } else if (isInserting) {
      context.missing(_decisionMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('reasons')) {
      context.handle(
        _reasonsMeta,
        reasons.isAcceptableOrUnknown(data['reasons']!, _reasonsMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClassificationEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassificationEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      ),
      contactKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_key'],
      )!,
      decision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decision'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      reasons: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasons'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $ClassificationEventsTable createAlias(String alias) {
    return $ClassificationEventsTable(attachedDatabase, alias);
  }
}

class ClassificationEvent extends DataClass
    implements Insertable<ClassificationEvent> {
  final int id;
  final int? messageId;
  final String contactKey;
  final String decision;
  final String? category;
  final String reasons;
  final String source;
  final DateTime at;
  const ClassificationEvent({
    required this.id,
    this.messageId,
    required this.contactKey,
    required this.decision,
    this.category,
    required this.reasons,
    required this.source,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || messageId != null) {
      map['message_id'] = Variable<int>(messageId);
    }
    map['contact_key'] = Variable<String>(contactKey);
    map['decision'] = Variable<String>(decision);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['reasons'] = Variable<String>(reasons);
    map['source'] = Variable<String>(source);
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  ClassificationEventsCompanion toCompanion(bool nullToAbsent) {
    return ClassificationEventsCompanion(
      id: Value(id),
      messageId: messageId == null && nullToAbsent
          ? const Value.absent()
          : Value(messageId),
      contactKey: Value(contactKey),
      decision: Value(decision),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      reasons: Value(reasons),
      source: Value(source),
      at: Value(at),
    );
  }

  factory ClassificationEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClassificationEvent(
      id: serializer.fromJson<int>(json['id']),
      messageId: serializer.fromJson<int?>(json['messageId']),
      contactKey: serializer.fromJson<String>(json['contactKey']),
      decision: serializer.fromJson<String>(json['decision']),
      category: serializer.fromJson<String?>(json['category']),
      reasons: serializer.fromJson<String>(json['reasons']),
      source: serializer.fromJson<String>(json['source']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'messageId': serializer.toJson<int?>(messageId),
      'contactKey': serializer.toJson<String>(contactKey),
      'decision': serializer.toJson<String>(decision),
      'category': serializer.toJson<String?>(category),
      'reasons': serializer.toJson<String>(reasons),
      'source': serializer.toJson<String>(source),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  ClassificationEvent copyWith({
    int? id,
    Value<int?> messageId = const Value.absent(),
    String? contactKey,
    String? decision,
    Value<String?> category = const Value.absent(),
    String? reasons,
    String? source,
    DateTime? at,
  }) => ClassificationEvent(
    id: id ?? this.id,
    messageId: messageId.present ? messageId.value : this.messageId,
    contactKey: contactKey ?? this.contactKey,
    decision: decision ?? this.decision,
    category: category.present ? category.value : this.category,
    reasons: reasons ?? this.reasons,
    source: source ?? this.source,
    at: at ?? this.at,
  );
  ClassificationEvent copyWithCompanion(ClassificationEventsCompanion data) {
    return ClassificationEvent(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      contactKey: data.contactKey.present
          ? data.contactKey.value
          : this.contactKey,
      decision: data.decision.present ? data.decision.value : this.decision,
      category: data.category.present ? data.category.value : this.category,
      reasons: data.reasons.present ? data.reasons.value : this.reasons,
      source: data.source.present ? data.source.value : this.source,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationEvent(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('contactKey: $contactKey, ')
          ..write('decision: $decision, ')
          ..write('category: $category, ')
          ..write('reasons: $reasons, ')
          ..write('source: $source, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    messageId,
    contactKey,
    decision,
    category,
    reasons,
    source,
    at,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassificationEvent &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.contactKey == this.contactKey &&
          other.decision == this.decision &&
          other.category == this.category &&
          other.reasons == this.reasons &&
          other.source == this.source &&
          other.at == this.at);
}

class ClassificationEventsCompanion
    extends UpdateCompanion<ClassificationEvent> {
  final Value<int> id;
  final Value<int?> messageId;
  final Value<String> contactKey;
  final Value<String> decision;
  final Value<String?> category;
  final Value<String> reasons;
  final Value<String> source;
  final Value<DateTime> at;
  const ClassificationEventsCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.contactKey = const Value.absent(),
    this.decision = const Value.absent(),
    this.category = const Value.absent(),
    this.reasons = const Value.absent(),
    this.source = const Value.absent(),
    this.at = const Value.absent(),
  });
  ClassificationEventsCompanion.insert({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    required String contactKey,
    required String decision,
    this.category = const Value.absent(),
    this.reasons = const Value.absent(),
    required String source,
    this.at = const Value.absent(),
  }) : contactKey = Value(contactKey),
       decision = Value(decision),
       source = Value(source);
  static Insertable<ClassificationEvent> custom({
    Expression<int>? id,
    Expression<int>? messageId,
    Expression<String>? contactKey,
    Expression<String>? decision,
    Expression<String>? category,
    Expression<String>? reasons,
    Expression<String>? source,
    Expression<DateTime>? at,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (contactKey != null) 'contact_key': contactKey,
      if (decision != null) 'decision': decision,
      if (category != null) 'category': category,
      if (reasons != null) 'reasons': reasons,
      if (source != null) 'source': source,
      if (at != null) 'at': at,
    });
  }

  ClassificationEventsCompanion copyWith({
    Value<int>? id,
    Value<int?>? messageId,
    Value<String>? contactKey,
    Value<String>? decision,
    Value<String?>? category,
    Value<String>? reasons,
    Value<String>? source,
    Value<DateTime>? at,
  }) {
    return ClassificationEventsCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      contactKey: contactKey ?? this.contactKey,
      decision: decision ?? this.decision,
      category: category ?? this.category,
      reasons: reasons ?? this.reasons,
      source: source ?? this.source,
      at: at ?? this.at,
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
    if (contactKey.present) {
      map['contact_key'] = Variable<String>(contactKey.value);
    }
    if (decision.present) {
      map['decision'] = Variable<String>(decision.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (reasons.present) {
      map['reasons'] = Variable<String>(reasons.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassificationEventsCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('contactKey: $contactKey, ')
          ..write('decision: $decision, ')
          ..write('category: $category, ')
          ..write('reasons: $reasons, ')
          ..write('source: $source, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    parentId,
    color,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
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
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;
  final String name;
  final int? parentId;
  final int? color;
  final int sortOrder;
  final DateTime createdAt;
  const Tag({
    required this.id,
    required this.name,
    this.parentId,
    this.color,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      color: serializer.fromJson<int?>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<int?>(parentId),
      'color': serializer.toJson<int?>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Tag copyWith({
    int? id,
    String? name,
    Value<int?> parentId = const Value.absent(),
    Value<int?> color = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    color: color.present ? color.value : this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, parentId, color, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> parentId;
  final Value<int?> color;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.parentId = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? parentId,
    Expression<int>? color,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TagsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? parentId,
    Value<int?>? color,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $BoardColumnsTable extends BoardColumns
    with TableInfo<$BoardColumnsTable, BoardColumn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardColumnsTable(this.attachedDatabase, [this._alias]);
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
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'board_columns';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardColumn> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoardColumn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardColumn(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BoardColumnsTable createAlias(String alias) {
    return $BoardColumnsTable(attachedDatabase, alias);
  }
}

class BoardColumn extends DataClass implements Insertable<BoardColumn> {
  final int id;
  final String name;
  final int sortOrder;
  final DateTime createdAt;
  const BoardColumn({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BoardColumnsCompanion toCompanion(bool nullToAbsent) {
    return BoardColumnsCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory BoardColumn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardColumn(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BoardColumn copyWith({
    int? id,
    String? name,
    int? sortOrder,
    DateTime? createdAt,
  }) => BoardColumn(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  BoardColumn copyWithCompanion(BoardColumnsCompanion data) {
    return BoardColumn(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardColumn(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardColumn &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class BoardColumnsCompanion extends UpdateCompanion<BoardColumn> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const BoardColumnsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BoardColumnsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<BoardColumn> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BoardColumnsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return BoardColumnsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardColumnsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, Card> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _threadKeyMeta = const VerificationMeta(
    'threadKey',
  );
  @override
  late final GeneratedColumn<String> threadKey = GeneratedColumn<String>(
    'thread_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _columnIdMeta = const VerificationMeta(
    'columnId',
  );
  @override
  late final GeneratedColumn<int> columnId = GeneratedColumn<int>(
    'column_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES board_columns (id) ON DELETE CASCADE',
    ),
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
    threadKey,
    columnId,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<Card> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('thread_key')) {
      context.handle(
        _threadKeyMeta,
        threadKey.isAcceptableOrUnknown(data['thread_key']!, _threadKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_threadKeyMeta);
    }
    if (data.containsKey('column_id')) {
      context.handle(
        _columnIdMeta,
        columnId.isAcceptableOrUnknown(data['column_id']!, _columnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_columnIdMeta);
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
  Card map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Card(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      threadKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_key'],
      )!,
      columnId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}column_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
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
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }
}

class Card extends DataClass implements Insertable<Card> {
  final int id;
  final String threadKey;
  final int columnId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Card({
    required this.id,
    required this.threadKey,
    required this.columnId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['thread_key'] = Variable<String>(threadKey);
    map['column_id'] = Variable<int>(columnId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      id: Value(id),
      threadKey: Value(threadKey),
      columnId: Value(columnId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Card.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Card(
      id: serializer.fromJson<int>(json['id']),
      threadKey: serializer.fromJson<String>(json['threadKey']),
      columnId: serializer.fromJson<int>(json['columnId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'threadKey': serializer.toJson<String>(threadKey),
      'columnId': serializer.toJson<int>(columnId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Card copyWith({
    int? id,
    String? threadKey,
    int? columnId,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Card(
    id: id ?? this.id,
    threadKey: threadKey ?? this.threadKey,
    columnId: columnId ?? this.columnId,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Card copyWithCompanion(CardsCompanion data) {
    return Card(
      id: data.id.present ? data.id.value : this.id,
      threadKey: data.threadKey.present ? data.threadKey.value : this.threadKey,
      columnId: data.columnId.present ? data.columnId.value : this.columnId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Card(')
          ..write('id: $id, ')
          ..write('threadKey: $threadKey, ')
          ..write('columnId: $columnId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, threadKey, columnId, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Card &&
          other.id == this.id &&
          other.threadKey == this.threadKey &&
          other.columnId == this.columnId &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CardsCompanion extends UpdateCompanion<Card> {
  final Value<int> id;
  final Value<String> threadKey;
  final Value<int> columnId;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const CardsCompanion({
    this.id = const Value.absent(),
    this.threadKey = const Value.absent(),
    this.columnId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CardsCompanion.insert({
    this.id = const Value.absent(),
    required String threadKey,
    required int columnId,
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : threadKey = Value(threadKey),
       columnId = Value(columnId);
  static Insertable<Card> custom({
    Expression<int>? id,
    Expression<String>? threadKey,
    Expression<int>? columnId,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (threadKey != null) 'thread_key': threadKey,
      if (columnId != null) 'column_id': columnId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CardsCompanion copyWith({
    Value<int>? id,
    Value<String>? threadKey,
    Value<int>? columnId,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return CardsCompanion(
      id: id ?? this.id,
      threadKey: threadKey ?? this.threadKey,
      columnId: columnId ?? this.columnId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (threadKey.present) {
      map['thread_key'] = Variable<String>(threadKey.value);
    }
    if (columnId.present) {
      map['column_id'] = Variable<int>(columnId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('id: $id, ')
          ..write('threadKey: $threadKey, ')
          ..write('columnId: $columnId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CardTagsTable extends CardTags with TableInfo<$CardTagsTable, CardTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [cardId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardId, tagId};
  @override
  CardTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardTag(
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $CardTagsTable createAlias(String alias) {
    return $CardTagsTable(attachedDatabase, alias);
  }
}

class CardTag extends DataClass implements Insertable<CardTag> {
  final int cardId;
  final int tagId;
  const CardTag({required this.cardId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_id'] = Variable<int>(cardId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  CardTagsCompanion toCompanion(bool nullToAbsent) {
    return CardTagsCompanion(cardId: Value(cardId), tagId: Value(tagId));
  }

  factory CardTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardTag(
      cardId: serializer.fromJson<int>(json['cardId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardId': serializer.toJson<int>(cardId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  CardTag copyWith({int? cardId, int? tagId}) =>
      CardTag(cardId: cardId ?? this.cardId, tagId: tagId ?? this.tagId);
  CardTag copyWithCompanion(CardTagsCompanion data) {
    return CardTag(
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardTag(')
          ..write('cardId: $cardId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardTag &&
          other.cardId == this.cardId &&
          other.tagId == this.tagId);
}

class CardTagsCompanion extends UpdateCompanion<CardTag> {
  final Value<int> cardId;
  final Value<int> tagId;
  final Value<int> rowid;
  const CardTagsCompanion({
    this.cardId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardTagsCompanion.insert({
    required int cardId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : cardId = Value(cardId),
       tagId = Value(tagId);
  static Insertable<CardTag> custom({
    Expression<int>? cardId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardId != null) 'card_id': cardId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardTagsCompanion copyWith({
    Value<int>? cardId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return CardTagsCompanion(
      cardId: cardId ?? this.cardId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardTagsCompanion(')
          ..write('cardId: $cardId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _threadKeyMeta = const VerificationMeta(
    'threadKey',
  );
  @override
  late final GeneratedColumn<String> threadKey = GeneratedColumn<String>(
    'thread_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rowKeyMeta = const VerificationMeta('rowKey');
  @override
  late final GeneratedColumn<String> rowKey = GeneratedColumn<String>(
    'row_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _firedAtMeta = const VerificationMeta(
    'firedAt',
  );
  @override
  late final GeneratedColumn<DateTime> firedAt = GeneratedColumn<DateTime>(
    'fired_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    dueAt,
    messageId,
    threadKey,
    rowKey,
    done,
    firedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    }
    if (data.containsKey('thread_key')) {
      context.handle(
        _threadKeyMeta,
        threadKey.isAcceptableOrUnknown(data['thread_key']!, _threadKeyMeta),
      );
    }
    if (data.containsKey('row_key')) {
      context.handle(
        _rowKeyMeta,
        rowKey.isAcceptableOrUnknown(data['row_key']!, _rowKeyMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('fired_at')) {
      context.handle(
        _firedAtMeta,
        firedAt.isAcceptableOrUnknown(data['fired_at']!, _firedAtMeta),
      );
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
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      ),
      threadKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_key'],
      ),
      rowKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_key'],
      ),
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      firedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fired_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final int id;
  final String title;
  final DateTime dueAt;
  final int? messageId;
  final String? threadKey;
  final String? rowKey;
  final bool done;
  final DateTime? firedAt;
  final DateTime createdAt;
  const Reminder({
    required this.id,
    required this.title,
    required this.dueAt,
    this.messageId,
    this.threadKey,
    this.rowKey,
    required this.done,
    this.firedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['due_at'] = Variable<DateTime>(dueAt);
    if (!nullToAbsent || messageId != null) {
      map['message_id'] = Variable<int>(messageId);
    }
    if (!nullToAbsent || threadKey != null) {
      map['thread_key'] = Variable<String>(threadKey);
    }
    if (!nullToAbsent || rowKey != null) {
      map['row_key'] = Variable<String>(rowKey);
    }
    map['done'] = Variable<bool>(done);
    if (!nullToAbsent || firedAt != null) {
      map['fired_at'] = Variable<DateTime>(firedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      title: Value(title),
      dueAt: Value(dueAt),
      messageId: messageId == null && nullToAbsent
          ? const Value.absent()
          : Value(messageId),
      threadKey: threadKey == null && nullToAbsent
          ? const Value.absent()
          : Value(threadKey),
      rowKey: rowKey == null && nullToAbsent
          ? const Value.absent()
          : Value(rowKey),
      done: Value(done),
      firedAt: firedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(firedAt),
      createdAt: Value(createdAt),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      messageId: serializer.fromJson<int?>(json['messageId']),
      threadKey: serializer.fromJson<String?>(json['threadKey']),
      rowKey: serializer.fromJson<String?>(json['rowKey']),
      done: serializer.fromJson<bool>(json['done']),
      firedAt: serializer.fromJson<DateTime?>(json['firedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'messageId': serializer.toJson<int?>(messageId),
      'threadKey': serializer.toJson<String?>(threadKey),
      'rowKey': serializer.toJson<String?>(rowKey),
      'done': serializer.toJson<bool>(done),
      'firedAt': serializer.toJson<DateTime?>(firedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Reminder copyWith({
    int? id,
    String? title,
    DateTime? dueAt,
    Value<int?> messageId = const Value.absent(),
    Value<String?> threadKey = const Value.absent(),
    Value<String?> rowKey = const Value.absent(),
    bool? done,
    Value<DateTime?> firedAt = const Value.absent(),
    DateTime? createdAt,
  }) => Reminder(
    id: id ?? this.id,
    title: title ?? this.title,
    dueAt: dueAt ?? this.dueAt,
    messageId: messageId.present ? messageId.value : this.messageId,
    threadKey: threadKey.present ? threadKey.value : this.threadKey,
    rowKey: rowKey.present ? rowKey.value : this.rowKey,
    done: done ?? this.done,
    firedAt: firedAt.present ? firedAt.value : this.firedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      threadKey: data.threadKey.present ? data.threadKey.value : this.threadKey,
      rowKey: data.rowKey.present ? data.rowKey.value : this.rowKey,
      done: data.done.present ? data.done.value : this.done,
      firedAt: data.firedAt.present ? data.firedAt.value : this.firedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('dueAt: $dueAt, ')
          ..write('messageId: $messageId, ')
          ..write('threadKey: $threadKey, ')
          ..write('rowKey: $rowKey, ')
          ..write('done: $done, ')
          ..write('firedAt: $firedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    dueAt,
    messageId,
    threadKey,
    rowKey,
    done,
    firedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.title == this.title &&
          other.dueAt == this.dueAt &&
          other.messageId == this.messageId &&
          other.threadKey == this.threadKey &&
          other.rowKey == this.rowKey &&
          other.done == this.done &&
          other.firedAt == this.firedAt &&
          other.createdAt == this.createdAt);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> dueAt;
  final Value<int?> messageId;
  final Value<String?> threadKey;
  final Value<String?> rowKey;
  final Value<bool> done;
  final Value<DateTime?> firedAt;
  final Value<DateTime> createdAt;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.messageId = const Value.absent(),
    this.threadKey = const Value.absent(),
    this.rowKey = const Value.absent(),
    this.done = const Value.absent(),
    this.firedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RemindersCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required DateTime dueAt,
    this.messageId = const Value.absent(),
    this.threadKey = const Value.absent(),
    this.rowKey = const Value.absent(),
    this.done = const Value.absent(),
    this.firedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : title = Value(title),
       dueAt = Value(dueAt);
  static Insertable<Reminder> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? dueAt,
    Expression<int>? messageId,
    Expression<String>? threadKey,
    Expression<String>? rowKey,
    Expression<bool>? done,
    Expression<DateTime>? firedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (dueAt != null) 'due_at': dueAt,
      if (messageId != null) 'message_id': messageId,
      if (threadKey != null) 'thread_key': threadKey,
      if (rowKey != null) 'row_key': rowKey,
      if (done != null) 'done': done,
      if (firedAt != null) 'fired_at': firedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RemindersCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<DateTime>? dueAt,
    Value<int?>? messageId,
    Value<String?>? threadKey,
    Value<String?>? rowKey,
    Value<bool>? done,
    Value<DateTime?>? firedAt,
    Value<DateTime>? createdAt,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      dueAt: dueAt ?? this.dueAt,
      messageId: messageId ?? this.messageId,
      threadKey: threadKey ?? this.threadKey,
      rowKey: rowKey ?? this.rowKey,
      done: done ?? this.done,
      firedAt: firedAt ?? this.firedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (threadKey.present) {
      map['thread_key'] = Variable<String>(threadKey.value);
    }
    if (rowKey.present) {
      map['row_key'] = Variable<String>(rowKey.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (firedAt.present) {
      map['fired_at'] = Variable<DateTime>(firedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('dueAt: $dueAt, ')
          ..write('messageId: $messageId, ')
          ..write('threadKey: $threadKey, ')
          ..write('rowKey: $rowKey, ')
          ..write('done: $done, ')
          ..write('firedAt: $firedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PlannerEventsTable extends PlannerEvents
    with TableInfo<$PlannerEventsTable, PlannerEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlannerEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _colorKeyMeta = const VerificationMeta(
    'colorKey',
  );
  @override
  late final GeneratedColumn<String> colorKey = GeneratedColumn<String>(
    'color_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _sourceMessageIdMeta = const VerificationMeta(
    'sourceMessageId',
  );
  @override
  late final GeneratedColumn<int> sourceMessageId = GeneratedColumn<int>(
    'source_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _threadKeyMeta = const VerificationMeta(
    'threadKey',
  );
  @override
  late final GeneratedColumn<String> threadKey = GeneratedColumn<String>(
    'thread_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dismissedMeta = const VerificationMeta(
    'dismissed',
  );
  @override
  late final GeneratedColumn<bool> dismissed = GeneratedColumn<bool>(
    'dismissed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dismissed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evidenceMeta = const VerificationMeta(
    'evidence',
  );
  @override
  late final GeneratedColumn<String> evidence = GeneratedColumn<String>(
    'evidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  List<GeneratedColumn> get $columns => [
    id,
    title,
    startAt,
    endAt,
    allDay,
    kind,
    colorKey,
    sourceMessageId,
    threadKey,
    location,
    notes,
    done,
    dismissed,
    confidence,
    uid,
    evidence,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'planner_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlannerEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('color_key')) {
      context.handle(
        _colorKeyMeta,
        colorKey.isAcceptableOrUnknown(data['color_key']!, _colorKeyMeta),
      );
    }
    if (data.containsKey('source_message_id')) {
      context.handle(
        _sourceMessageIdMeta,
        sourceMessageId.isAcceptableOrUnknown(
          data['source_message_id']!,
          _sourceMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('thread_key')) {
      context.handle(
        _threadKeyMeta,
        threadKey.isAcceptableOrUnknown(data['thread_key']!, _threadKeyMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('dismissed')) {
      context.handle(
        _dismissedMeta,
        dismissed.isAcceptableOrUnknown(data['dismissed']!, _dismissedMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    }
    if (data.containsKey('evidence')) {
      context.handle(
        _evidenceMeta,
        evidence.isAcceptableOrUnknown(data['evidence']!, _evidenceMeta),
      );
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
  PlannerEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlannerEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      ),
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      ),
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      colorKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_key'],
      )!,
      sourceMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_message_id'],
      ),
      threadKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_key'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      dismissed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dismissed'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      ),
      evidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlannerEventsTable createAlias(String alias) {
    return $PlannerEventsTable(attachedDatabase, alias);
  }
}

class PlannerEvent extends DataClass implements Insertable<PlannerEvent> {
  final int id;
  final String title;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool allDay;

  /// `manual`, `extracted`, `invite`, or `todo`.
  final String kind;

  /// Color key: `personal`, `work`, `travel`, `health`, `other`.
  final String colorKey;
  final int? sourceMessageId;
  final String? threadKey;
  final String? location;
  final String notes;
  final bool done;
  final bool dismissed;
  final double confidence;
  final String? uid;
  final String evidence;
  final DateTime createdAt;
  const PlannerEvent({
    required this.id,
    required this.title,
    this.startAt,
    this.endAt,
    required this.allDay,
    required this.kind,
    required this.colorKey,
    this.sourceMessageId,
    this.threadKey,
    this.location,
    required this.notes,
    required this.done,
    required this.dismissed,
    required this.confidence,
    this.uid,
    required this.evidence,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || startAt != null) {
      map['start_at'] = Variable<DateTime>(startAt);
    }
    if (!nullToAbsent || endAt != null) {
      map['end_at'] = Variable<DateTime>(endAt);
    }
    map['all_day'] = Variable<bool>(allDay);
    map['kind'] = Variable<String>(kind);
    map['color_key'] = Variable<String>(colorKey);
    if (!nullToAbsent || sourceMessageId != null) {
      map['source_message_id'] = Variable<int>(sourceMessageId);
    }
    if (!nullToAbsent || threadKey != null) {
      map['thread_key'] = Variable<String>(threadKey);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['notes'] = Variable<String>(notes);
    map['done'] = Variable<bool>(done);
    map['dismissed'] = Variable<bool>(dismissed);
    map['confidence'] = Variable<double>(confidence);
    if (!nullToAbsent || uid != null) {
      map['uid'] = Variable<String>(uid);
    }
    map['evidence'] = Variable<String>(evidence);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlannerEventsCompanion toCompanion(bool nullToAbsent) {
    return PlannerEventsCompanion(
      id: Value(id),
      title: Value(title),
      startAt: startAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startAt),
      endAt: endAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endAt),
      allDay: Value(allDay),
      kind: Value(kind),
      colorKey: Value(colorKey),
      sourceMessageId: sourceMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMessageId),
      threadKey: threadKey == null && nullToAbsent
          ? const Value.absent()
          : Value(threadKey),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      notes: Value(notes),
      done: Value(done),
      dismissed: Value(dismissed),
      confidence: Value(confidence),
      uid: uid == null && nullToAbsent ? const Value.absent() : Value(uid),
      evidence: Value(evidence),
      createdAt: Value(createdAt),
    );
  }

  factory PlannerEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlannerEvent(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      startAt: serializer.fromJson<DateTime?>(json['startAt']),
      endAt: serializer.fromJson<DateTime?>(json['endAt']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      kind: serializer.fromJson<String>(json['kind']),
      colorKey: serializer.fromJson<String>(json['colorKey']),
      sourceMessageId: serializer.fromJson<int?>(json['sourceMessageId']),
      threadKey: serializer.fromJson<String?>(json['threadKey']),
      location: serializer.fromJson<String?>(json['location']),
      notes: serializer.fromJson<String>(json['notes']),
      done: serializer.fromJson<bool>(json['done']),
      dismissed: serializer.fromJson<bool>(json['dismissed']),
      confidence: serializer.fromJson<double>(json['confidence']),
      uid: serializer.fromJson<String?>(json['uid']),
      evidence: serializer.fromJson<String>(json['evidence']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'startAt': serializer.toJson<DateTime?>(startAt),
      'endAt': serializer.toJson<DateTime?>(endAt),
      'allDay': serializer.toJson<bool>(allDay),
      'kind': serializer.toJson<String>(kind),
      'colorKey': serializer.toJson<String>(colorKey),
      'sourceMessageId': serializer.toJson<int?>(sourceMessageId),
      'threadKey': serializer.toJson<String?>(threadKey),
      'location': serializer.toJson<String?>(location),
      'notes': serializer.toJson<String>(notes),
      'done': serializer.toJson<bool>(done),
      'dismissed': serializer.toJson<bool>(dismissed),
      'confidence': serializer.toJson<double>(confidence),
      'uid': serializer.toJson<String?>(uid),
      'evidence': serializer.toJson<String>(evidence),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PlannerEvent copyWith({
    int? id,
    String? title,
    Value<DateTime?> startAt = const Value.absent(),
    Value<DateTime?> endAt = const Value.absent(),
    bool? allDay,
    String? kind,
    String? colorKey,
    Value<int?> sourceMessageId = const Value.absent(),
    Value<String?> threadKey = const Value.absent(),
    Value<String?> location = const Value.absent(),
    String? notes,
    bool? done,
    bool? dismissed,
    double? confidence,
    Value<String?> uid = const Value.absent(),
    String? evidence,
    DateTime? createdAt,
  }) => PlannerEvent(
    id: id ?? this.id,
    title: title ?? this.title,
    startAt: startAt.present ? startAt.value : this.startAt,
    endAt: endAt.present ? endAt.value : this.endAt,
    allDay: allDay ?? this.allDay,
    kind: kind ?? this.kind,
    colorKey: colorKey ?? this.colorKey,
    sourceMessageId: sourceMessageId.present
        ? sourceMessageId.value
        : this.sourceMessageId,
    threadKey: threadKey.present ? threadKey.value : this.threadKey,
    location: location.present ? location.value : this.location,
    notes: notes ?? this.notes,
    done: done ?? this.done,
    dismissed: dismissed ?? this.dismissed,
    confidence: confidence ?? this.confidence,
    uid: uid.present ? uid.value : this.uid,
    evidence: evidence ?? this.evidence,
    createdAt: createdAt ?? this.createdAt,
  );
  PlannerEvent copyWithCompanion(PlannerEventsCompanion data) {
    return PlannerEvent(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      kind: data.kind.present ? data.kind.value : this.kind,
      colorKey: data.colorKey.present ? data.colorKey.value : this.colorKey,
      sourceMessageId: data.sourceMessageId.present
          ? data.sourceMessageId.value
          : this.sourceMessageId,
      threadKey: data.threadKey.present ? data.threadKey.value : this.threadKey,
      location: data.location.present ? data.location.value : this.location,
      notes: data.notes.present ? data.notes.value : this.notes,
      done: data.done.present ? data.done.value : this.done,
      dismissed: data.dismissed.present ? data.dismissed.value : this.dismissed,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      uid: data.uid.present ? data.uid.value : this.uid,
      evidence: data.evidence.present ? data.evidence.value : this.evidence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlannerEvent(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('allDay: $allDay, ')
          ..write('kind: $kind, ')
          ..write('colorKey: $colorKey, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('threadKey: $threadKey, ')
          ..write('location: $location, ')
          ..write('notes: $notes, ')
          ..write('done: $done, ')
          ..write('dismissed: $dismissed, ')
          ..write('confidence: $confidence, ')
          ..write('uid: $uid, ')
          ..write('evidence: $evidence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    startAt,
    endAt,
    allDay,
    kind,
    colorKey,
    sourceMessageId,
    threadKey,
    location,
    notes,
    done,
    dismissed,
    confidence,
    uid,
    evidence,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlannerEvent &&
          other.id == this.id &&
          other.title == this.title &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.allDay == this.allDay &&
          other.kind == this.kind &&
          other.colorKey == this.colorKey &&
          other.sourceMessageId == this.sourceMessageId &&
          other.threadKey == this.threadKey &&
          other.location == this.location &&
          other.notes == this.notes &&
          other.done == this.done &&
          other.dismissed == this.dismissed &&
          other.confidence == this.confidence &&
          other.uid == this.uid &&
          other.evidence == this.evidence &&
          other.createdAt == this.createdAt);
}

class PlannerEventsCompanion extends UpdateCompanion<PlannerEvent> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime?> startAt;
  final Value<DateTime?> endAt;
  final Value<bool> allDay;
  final Value<String> kind;
  final Value<String> colorKey;
  final Value<int?> sourceMessageId;
  final Value<String?> threadKey;
  final Value<String?> location;
  final Value<String> notes;
  final Value<bool> done;
  final Value<bool> dismissed;
  final Value<double> confidence;
  final Value<String?> uid;
  final Value<String> evidence;
  final Value<DateTime> createdAt;
  const PlannerEventsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.kind = const Value.absent(),
    this.colorKey = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.threadKey = const Value.absent(),
    this.location = const Value.absent(),
    this.notes = const Value.absent(),
    this.done = const Value.absent(),
    this.dismissed = const Value.absent(),
    this.confidence = const Value.absent(),
    this.uid = const Value.absent(),
    this.evidence = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PlannerEventsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.allDay = const Value.absent(),
    required String kind,
    this.colorKey = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.threadKey = const Value.absent(),
    this.location = const Value.absent(),
    this.notes = const Value.absent(),
    this.done = const Value.absent(),
    this.dismissed = const Value.absent(),
    this.confidence = const Value.absent(),
    this.uid = const Value.absent(),
    this.evidence = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : title = Value(title),
       kind = Value(kind);
  static Insertable<PlannerEvent> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<bool>? allDay,
    Expression<String>? kind,
    Expression<String>? colorKey,
    Expression<int>? sourceMessageId,
    Expression<String>? threadKey,
    Expression<String>? location,
    Expression<String>? notes,
    Expression<bool>? done,
    Expression<bool>? dismissed,
    Expression<double>? confidence,
    Expression<String>? uid,
    Expression<String>? evidence,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (allDay != null) 'all_day': allDay,
      if (kind != null) 'kind': kind,
      if (colorKey != null) 'color_key': colorKey,
      if (sourceMessageId != null) 'source_message_id': sourceMessageId,
      if (threadKey != null) 'thread_key': threadKey,
      if (location != null) 'location': location,
      if (notes != null) 'notes': notes,
      if (done != null) 'done': done,
      if (dismissed != null) 'dismissed': dismissed,
      if (confidence != null) 'confidence': confidence,
      if (uid != null) 'uid': uid,
      if (evidence != null) 'evidence': evidence,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PlannerEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<DateTime?>? startAt,
    Value<DateTime?>? endAt,
    Value<bool>? allDay,
    Value<String>? kind,
    Value<String>? colorKey,
    Value<int?>? sourceMessageId,
    Value<String?>? threadKey,
    Value<String?>? location,
    Value<String>? notes,
    Value<bool>? done,
    Value<bool>? dismissed,
    Value<double>? confidence,
    Value<String?>? uid,
    Value<String>? evidence,
    Value<DateTime>? createdAt,
  }) {
    return PlannerEventsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay ?? this.allDay,
      kind: kind ?? this.kind,
      colorKey: colorKey ?? this.colorKey,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      threadKey: threadKey ?? this.threadKey,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      done: done ?? this.done,
      dismissed: dismissed ?? this.dismissed,
      confidence: confidence ?? this.confidence,
      uid: uid ?? this.uid,
      evidence: evidence ?? this.evidence,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (colorKey.present) {
      map['color_key'] = Variable<String>(colorKey.value);
    }
    if (sourceMessageId.present) {
      map['source_message_id'] = Variable<int>(sourceMessageId.value);
    }
    if (threadKey.present) {
      map['thread_key'] = Variable<String>(threadKey.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (dismissed.present) {
      map['dismissed'] = Variable<bool>(dismissed.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (evidence.present) {
      map['evidence'] = Variable<String>(evidence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlannerEventsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('allDay: $allDay, ')
          ..write('kind: $kind, ')
          ..write('colorKey: $colorKey, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('threadKey: $threadKey, ')
          ..write('location: $location, ')
          ..write('notes: $notes, ')
          ..write('done: $done, ')
          ..write('dismissed: $dismissed, ')
          ..write('confidence: $confidence, ')
          ..write('uid: $uid, ')
          ..write('evidence: $evidence, ')
          ..write('createdAt: $createdAt')
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
  late final $RowPrefsTable rowPrefs = $RowPrefsTable(this);
  late final $RowSummariesTable rowSummaries = $RowSummariesTable(this);
  late final $DirtyRowsTable dirtyRows = $DirtyRowsTable(this);
  late final $TrackerEventsTable trackerEvents = $TrackerEventsTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $FeedsCategoryRowsTable feedsCategoryRows =
      $FeedsCategoryRowsTable(this);
  late final $ClassificationRulesTable classificationRules =
      $ClassificationRulesTable(this);
  late final $ClassificationEventsTable classificationEvents =
      $ClassificationEventsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $BoardColumnsTable boardColumns = $BoardColumnsTable(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $CardTagsTable cardTags = $CardTagsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $PlannerEventsTable plannerEvents = $PlannerEventsTable(this);
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
    rowPrefs,
    rowSummaries,
    dirtyRows,
    trackerEvents,
    drafts,
    feedsCategoryRows,
    classificationRules,
    classificationEvents,
    tags,
    boardColumns,
    cards,
    cardTags,
    reminders,
    plannerEvents,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tracker_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('drafts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'board_columns',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_tags', kind: UpdateKind.delete)],
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

  static MultiTypedResultKey<$DraftsTable, List<Draft>> _draftsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.drafts,
    aliasName: 'accounts__id__drafts__account_id',
  );

  $$DraftsTableProcessedTableManager get draftsRefs {
    final manager = $$DraftsTableTableManager(
      $_db,
      $_db.drafts,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_draftsRefsTable($_db));
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

  Expression<bool> draftsRefs(
    Expression<bool> Function($$DraftsTableFilterComposer f) f,
  ) {
    final $$DraftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftsTableFilterComposer(
            $db: $db,
            $table: $db.drafts,
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

  Expression<T> draftsRefs<T extends Object>(
    Expression<T> Function($$DraftsTableAnnotationComposer a) f,
  ) {
    final $$DraftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftsTableAnnotationComposer(
            $db: $db,
            $table: $db.drafts,
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
            bool draftsRefs,
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
                draftsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (identitiesRefs) db.identities,
                    if (foldersRefs) db.folders,
                    if (messagesRefs) db.messages,
                    if (draftsRefs) db.drafts,
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
                      if (draftsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Draft
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._draftsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).draftsRefs,
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
        bool draftsRefs,
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
  Value<bool> discovered,
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
  Value<bool> discovered,
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

  ColumnFilters<bool> get discovered => $composableBuilder(
    column: $table.discovered,
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

  ColumnOrderings<bool> get discovered => $composableBuilder(
    column: $table.discovered,
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

  GeneratedColumn<bool> get discovered => $composableBuilder(
    column: $table.discovered,
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
                Value<bool> discovered = const Value.absent(),
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
                discovered: discovered,
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
                Value<bool> discovered = const Value.absent(),
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
                discovered: discovered,
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
  Value<String?> threadKey,
  Value<bool> imagesAllowed,
  Value<String?> bulkSignals,
  Value<String> classification,
  Value<String?> feedsCategory,
  Value<String?> icsText,
  Value<DateTime?> extractedAt,
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
  Value<String?> threadKey,
  Value<bool> imagesAllowed,
  Value<String?> bulkSignals,
  Value<String> classification,
  Value<String?> feedsCategory,
  Value<String?> icsText,
  Value<DateTime?> extractedAt,
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

  static MultiTypedResultKey<$TrackerEventsTable, List<TrackerEvent>>
  _trackerEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trackerEvents,
    aliasName: 'messages__id__tracker_events__message_id',
  );

  $$TrackerEventsTableProcessedTableManager get trackerEventsRefs {
    final manager = $$TrackerEventsTableTableManager(
      $_db,
      $_db.trackerEvents,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackerEventsRefsTable($_db));
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

  ColumnFilters<String> get threadKey => $composableBuilder(
    column: $table.threadKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get imagesAllowed => $composableBuilder(
    column: $table.imagesAllowed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bulkSignals => $composableBuilder(
    column: $table.bulkSignals,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classification => $composableBuilder(
    column: $table.classification,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedsCategory => $composableBuilder(
    column: $table.feedsCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icsText => $composableBuilder(
    column: $table.icsText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get extractedAt => $composableBuilder(
    column: $table.extractedAt,
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

  Expression<bool> trackerEventsRefs(
    Expression<bool> Function($$TrackerEventsTableFilterComposer f) f,
  ) {
    final $$TrackerEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackerEvents,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackerEventsTableFilterComposer(
            $db: $db,
            $table: $db.trackerEvents,
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

  ColumnOrderings<String> get threadKey => $composableBuilder(
    column: $table.threadKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get imagesAllowed => $composableBuilder(
    column: $table.imagesAllowed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bulkSignals => $composableBuilder(
    column: $table.bulkSignals,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classification => $composableBuilder(
    column: $table.classification,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedsCategory => $composableBuilder(
    column: $table.feedsCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icsText => $composableBuilder(
    column: $table.icsText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get extractedAt => $composableBuilder(
    column: $table.extractedAt,
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

  GeneratedColumn<String> get threadKey =>
      $composableBuilder(column: $table.threadKey, builder: (column) => column);

  GeneratedColumn<bool> get imagesAllowed => $composableBuilder(
    column: $table.imagesAllowed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bulkSignals => $composableBuilder(
    column: $table.bulkSignals,
    builder: (column) => column,
  );

  GeneratedColumn<String> get classification => $composableBuilder(
    column: $table.classification,
    builder: (column) => column,
  );

  GeneratedColumn<String> get feedsCategory => $composableBuilder(
    column: $table.feedsCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icsText =>
      $composableBuilder(column: $table.icsText, builder: (column) => column);

  GeneratedColumn<DateTime> get extractedAt => $composableBuilder(
    column: $table.extractedAt,
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

  Expression<T> trackerEventsRefs<T extends Object>(
    Expression<T> Function($$TrackerEventsTableAnnotationComposer a) f,
  ) {
    final $$TrackerEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackerEvents,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackerEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.trackerEvents,
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
            bool trackerEventsRefs,
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
                Value<String?> threadKey = const Value.absent(),
                Value<bool> imagesAllowed = const Value.absent(),
                Value<String?> bulkSignals = const Value.absent(),
                Value<String> classification = const Value.absent(),
                Value<String?> feedsCategory = const Value.absent(),
                Value<String?> icsText = const Value.absent(),
                Value<DateTime?> extractedAt = const Value.absent(),
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
                threadKey: threadKey,
                imagesAllowed: imagesAllowed,
                bulkSignals: bulkSignals,
                classification: classification,
                feedsCategory: feedsCategory,
                icsText: icsText,
                extractedAt: extractedAt,
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
                Value<String?> threadKey = const Value.absent(),
                Value<bool> imagesAllowed = const Value.absent(),
                Value<String?> bulkSignals = const Value.absent(),
                Value<String> classification = const Value.absent(),
                Value<String?> feedsCategory = const Value.absent(),
                Value<String?> icsText = const Value.absent(),
                Value<DateTime?> extractedAt = const Value.absent(),
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
                threadKey: threadKey,
                imagesAllowed: imagesAllowed,
                bulkSignals: bulkSignals,
                classification: classification,
                feedsCategory: feedsCategory,
                icsText: icsText,
                extractedAt: extractedAt,
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
                trackerEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messageParticipantsRefs) db.messageParticipants,
                    if (attachmentsRefs) db.attachments,
                    if (messageRowAssignmentsRefs) db.messageRowAssignments,
                    if (trackerEventsRefs) db.trackerEvents,
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
                      if (trackerEventsRefs)
                        await $_getPrefetchedData<
                          Message,
                          $MessagesTable,
                          TrackerEvent
                        >(
                          currentTable: table,
                          referencedTable: $$MessagesTableReferences
                              ._trackerEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MessagesTableReferences(
                                db,
                                table,
                                p0,
                              ).trackerEventsRefs,
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
        bool trackerEventsRefs,
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
  Value<String> classification,
  Value<String> classificationSource,
  Value<String?> feedsCategory,
  Value<bool> countsTowardUnread,
  Value<String> classReasons,
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
  Value<String> classification,
  Value<String> classificationSource,
  Value<String?> feedsCategory,
  Value<bool> countsTowardUnread,
  Value<String> classReasons,
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

  ColumnFilters<String> get classification => $composableBuilder(
    column: $table.classification,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classificationSource => $composableBuilder(
    column: $table.classificationSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedsCategory => $composableBuilder(
    column: $table.feedsCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get countsTowardUnread => $composableBuilder(
    column: $table.countsTowardUnread,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classReasons => $composableBuilder(
    column: $table.classReasons,
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

  ColumnOrderings<String> get classification => $composableBuilder(
    column: $table.classification,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classificationSource => $composableBuilder(
    column: $table.classificationSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedsCategory => $composableBuilder(
    column: $table.feedsCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get countsTowardUnread => $composableBuilder(
    column: $table.countsTowardUnread,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classReasons => $composableBuilder(
    column: $table.classReasons,
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

  GeneratedColumn<String> get classification => $composableBuilder(
    column: $table.classification,
    builder: (column) => column,
  );

  GeneratedColumn<String> get classificationSource => $composableBuilder(
    column: $table.classificationSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get feedsCategory => $composableBuilder(
    column: $table.feedsCategory,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get countsTowardUnread => $composableBuilder(
    column: $table.countsTowardUnread,
    builder: (column) => column,
  );

  GeneratedColumn<String> get classReasons => $composableBuilder(
    column: $table.classReasons,
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
                Value<String> classification = const Value.absent(),
                Value<String> classificationSource = const Value.absent(),
                Value<String?> feedsCategory = const Value.absent(),
                Value<bool> countsTowardUnread = const Value.absent(),
                Value<String> classReasons = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                key: key,
                displayName: displayName,
                photoPath: photoPath,
                isMe: isMe,
                inAddressBook: inAddressBook,
                classification: classification,
                classificationSource: classificationSource,
                feedsCategory: feedsCategory,
                countsTowardUnread: countsTowardUnread,
                classReasons: classReasons,
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
                Value<String> classification = const Value.absent(),
                Value<String> classificationSource = const Value.absent(),
                Value<String?> feedsCategory = const Value.absent(),
                Value<bool> countsTowardUnread = const Value.absent(),
                Value<String> classReasons = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                key: key,
                displayName: displayName,
                photoPath: photoPath,
                isMe: isMe,
                inAddressBook: inAddressBook,
                classification: classification,
                classificationSource: classificationSource,
                feedsCategory: feedsCategory,
                countsTowardUnread: countsTowardUnread,
                classReasons: classReasons,
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
typedef $$RowPrefsTableCreateCompanionBuilder = RowPrefsCompanion Function({
  required String rowKey,
  Value<bool> pinned,
  Value<bool> muted,
  Value<DateTime?> snoozedUntil,
  Value<DateTime?> resurfacedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$RowPrefsTableUpdateCompanionBuilder = RowPrefsCompanion Function({
  Value<String> rowKey,
  Value<bool> pinned,
  Value<bool> muted,
  Value<DateTime?> snoozedUntil,
  Value<DateTime?> resurfacedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$RowPrefsTableFilterComposer
    extends Composer<_$AppDatabase, $RowPrefsTable> {
  $$RowPrefsTableFilterComposer({
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

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resurfacedAt => $composableBuilder(
    column: $table.resurfacedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RowPrefsTableOrderingComposer
    extends Composer<_$AppDatabase, $RowPrefsTable> {
  $$RowPrefsTableOrderingComposer({
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

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resurfacedAt => $composableBuilder(
    column: $table.resurfacedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RowPrefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RowPrefsTable> {
  $$RowPrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rowKey =>
      $composableBuilder(column: $table.rowKey, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<bool> get muted =>
      $composableBuilder(column: $table.muted, builder: (column) => column);

  GeneratedColumn<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resurfacedAt => $composableBuilder(
    column: $table.resurfacedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RowPrefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RowPrefsTable,
          RowPref,
          $$RowPrefsTableFilterComposer,
          $$RowPrefsTableOrderingComposer,
          $$RowPrefsTableAnnotationComposer,
          $$RowPrefsTableCreateCompanionBuilder,
          $$RowPrefsTableUpdateCompanionBuilder,
          (RowPref, BaseReferences<_$AppDatabase, $RowPrefsTable, RowPref>),
          RowPref,
          PrefetchHooks Function()
        > {
  $$RowPrefsTableTableManager(_$AppDatabase db, $RowPrefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RowPrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RowPrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RowPrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> rowKey = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<DateTime?> resurfacedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RowPrefsCompanion(
                rowKey: rowKey,
                pinned: pinned,
                muted: muted,
                snoozedUntil: snoozedUntil,
                resurfacedAt: resurfacedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String rowKey,
                Value<bool> pinned = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<DateTime?> resurfacedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RowPrefsCompanion.insert(
                rowKey: rowKey,
                pinned: pinned,
                muted: muted,
                snoozedUntil: snoozedUntil,
                resurfacedAt: resurfacedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RowPrefsTable, RowPref>(table),
                  BaseReferences<_$AppDatabase, $RowPrefsTable, RowPref>(
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

typedef $$RowPrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RowPrefsTable,
      RowPref,
      $$RowPrefsTableFilterComposer,
      $$RowPrefsTableOrderingComposer,
      $$RowPrefsTableAnnotationComposer,
      $$RowPrefsTableCreateCompanionBuilder,
      $$RowPrefsTableUpdateCompanionBuilder,
      (RowPref, BaseReferences<_$AppDatabase, $RowPrefsTable, RowPref>),
      RowPref,
      PrefetchHooks Function()
    >;
typedef $$RowSummariesTableCreateCompanionBuilder =
    RowSummariesCompanion Function({
      required String rowKey,
      required int total,
      required int unread,
      Value<DateTime?> lastReceived,
      Value<DateTime?> lastAny,
      required bool hasStarred,
      required bool hasAttachments,
      required bool hasSent,
      Value<int?> newestMessageId,
      Value<DateTime> updatedAt,
      Value<int> peopleTotal,
      Value<int> peopleUnread,
      Value<int> feedsTotal,
      Value<int> feedsUnread,
      Value<DateTime?> lastPeople,
      Value<DateTime?> lastFeeds,
      Value<int?> newestPeopleId,
      Value<int?> newestFeedsId,
      Value<int> rowid,
    });
typedef $$RowSummariesTableUpdateCompanionBuilder =
    RowSummariesCompanion Function({
      Value<String> rowKey,
      Value<int> total,
      Value<int> unread,
      Value<DateTime?> lastReceived,
      Value<DateTime?> lastAny,
      Value<bool> hasStarred,
      Value<bool> hasAttachments,
      Value<bool> hasSent,
      Value<int?> newestMessageId,
      Value<DateTime> updatedAt,
      Value<int> peopleTotal,
      Value<int> peopleUnread,
      Value<int> feedsTotal,
      Value<int> feedsUnread,
      Value<DateTime?> lastPeople,
      Value<DateTime?> lastFeeds,
      Value<int?> newestPeopleId,
      Value<int?> newestFeedsId,
      Value<int> rowid,
    });

class $$RowSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $RowSummariesTable> {
  $$RowSummariesTableFilterComposer({
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

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unread => $composableBuilder(
    column: $table.unread,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReceived => $composableBuilder(
    column: $table.lastReceived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAny => $composableBuilder(
    column: $table.lastAny,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasStarred => $composableBuilder(
    column: $table.hasStarred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasSent => $composableBuilder(
    column: $table.hasSent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get newestMessageId => $composableBuilder(
    column: $table.newestMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get peopleTotal => $composableBuilder(
    column: $table.peopleTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get peopleUnread => $composableBuilder(
    column: $table.peopleUnread,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get feedsTotal => $composableBuilder(
    column: $table.feedsTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get feedsUnread => $composableBuilder(
    column: $table.feedsUnread,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPeople => $composableBuilder(
    column: $table.lastPeople,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastFeeds => $composableBuilder(
    column: $table.lastFeeds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get newestPeopleId => $composableBuilder(
    column: $table.newestPeopleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get newestFeedsId => $composableBuilder(
    column: $table.newestFeedsId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RowSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $RowSummariesTable> {
  $$RowSummariesTableOrderingComposer({
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

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unread => $composableBuilder(
    column: $table.unread,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReceived => $composableBuilder(
    column: $table.lastReceived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAny => $composableBuilder(
    column: $table.lastAny,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasStarred => $composableBuilder(
    column: $table.hasStarred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasSent => $composableBuilder(
    column: $table.hasSent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get newestMessageId => $composableBuilder(
    column: $table.newestMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get peopleTotal => $composableBuilder(
    column: $table.peopleTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get peopleUnread => $composableBuilder(
    column: $table.peopleUnread,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get feedsTotal => $composableBuilder(
    column: $table.feedsTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get feedsUnread => $composableBuilder(
    column: $table.feedsUnread,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPeople => $composableBuilder(
    column: $table.lastPeople,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastFeeds => $composableBuilder(
    column: $table.lastFeeds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get newestPeopleId => $composableBuilder(
    column: $table.newestPeopleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get newestFeedsId => $composableBuilder(
    column: $table.newestFeedsId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RowSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RowSummariesTable> {
  $$RowSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rowKey =>
      $composableBuilder(column: $table.rowKey, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get unread =>
      $composableBuilder(column: $table.unread, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReceived => $composableBuilder(
    column: $table.lastReceived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAny =>
      $composableBuilder(column: $table.lastAny, builder: (column) => column);

  GeneratedColumn<bool> get hasStarred => $composableBuilder(
    column: $table.hasStarred,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasAttachments => $composableBuilder(
    column: $table.hasAttachments,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasSent =>
      $composableBuilder(column: $table.hasSent, builder: (column) => column);

  GeneratedColumn<int> get newestMessageId => $composableBuilder(
    column: $table.newestMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get peopleTotal => $composableBuilder(
    column: $table.peopleTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get peopleUnread => $composableBuilder(
    column: $table.peopleUnread,
    builder: (column) => column,
  );

  GeneratedColumn<int> get feedsTotal => $composableBuilder(
    column: $table.feedsTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get feedsUnread => $composableBuilder(
    column: $table.feedsUnread,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPeople => $composableBuilder(
    column: $table.lastPeople,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastFeeds =>
      $composableBuilder(column: $table.lastFeeds, builder: (column) => column);

  GeneratedColumn<int> get newestPeopleId => $composableBuilder(
    column: $table.newestPeopleId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get newestFeedsId => $composableBuilder(
    column: $table.newestFeedsId,
    builder: (column) => column,
  );
}

class $$RowSummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RowSummariesTable,
          RowSummary,
          $$RowSummariesTableFilterComposer,
          $$RowSummariesTableOrderingComposer,
          $$RowSummariesTableAnnotationComposer,
          $$RowSummariesTableCreateCompanionBuilder,
          $$RowSummariesTableUpdateCompanionBuilder,
          (
            RowSummary,
            BaseReferences<_$AppDatabase, $RowSummariesTable, RowSummary>,
          ),
          RowSummary,
          PrefetchHooks Function()
        > {
  $$RowSummariesTableTableManager(_$AppDatabase db, $RowSummariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RowSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RowSummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RowSummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> rowKey = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> unread = const Value.absent(),
                Value<DateTime?> lastReceived = const Value.absent(),
                Value<DateTime?> lastAny = const Value.absent(),
                Value<bool> hasStarred = const Value.absent(),
                Value<bool> hasAttachments = const Value.absent(),
                Value<bool> hasSent = const Value.absent(),
                Value<int?> newestMessageId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> peopleTotal = const Value.absent(),
                Value<int> peopleUnread = const Value.absent(),
                Value<int> feedsTotal = const Value.absent(),
                Value<int> feedsUnread = const Value.absent(),
                Value<DateTime?> lastPeople = const Value.absent(),
                Value<DateTime?> lastFeeds = const Value.absent(),
                Value<int?> newestPeopleId = const Value.absent(),
                Value<int?> newestFeedsId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RowSummariesCompanion(
                rowKey: rowKey,
                total: total,
                unread: unread,
                lastReceived: lastReceived,
                lastAny: lastAny,
                hasStarred: hasStarred,
                hasAttachments: hasAttachments,
                hasSent: hasSent,
                newestMessageId: newestMessageId,
                updatedAt: updatedAt,
                peopleTotal: peopleTotal,
                peopleUnread: peopleUnread,
                feedsTotal: feedsTotal,
                feedsUnread: feedsUnread,
                lastPeople: lastPeople,
                lastFeeds: lastFeeds,
                newestPeopleId: newestPeopleId,
                newestFeedsId: newestFeedsId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String rowKey,
                required int total,
                required int unread,
                Value<DateTime?> lastReceived = const Value.absent(),
                Value<DateTime?> lastAny = const Value.absent(),
                required bool hasStarred,
                required bool hasAttachments,
                required bool hasSent,
                Value<int?> newestMessageId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> peopleTotal = const Value.absent(),
                Value<int> peopleUnread = const Value.absent(),
                Value<int> feedsTotal = const Value.absent(),
                Value<int> feedsUnread = const Value.absent(),
                Value<DateTime?> lastPeople = const Value.absent(),
                Value<DateTime?> lastFeeds = const Value.absent(),
                Value<int?> newestPeopleId = const Value.absent(),
                Value<int?> newestFeedsId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RowSummariesCompanion.insert(
                rowKey: rowKey,
                total: total,
                unread: unread,
                lastReceived: lastReceived,
                lastAny: lastAny,
                hasStarred: hasStarred,
                hasAttachments: hasAttachments,
                hasSent: hasSent,
                newestMessageId: newestMessageId,
                updatedAt: updatedAt,
                peopleTotal: peopleTotal,
                peopleUnread: peopleUnread,
                feedsTotal: feedsTotal,
                feedsUnread: feedsUnread,
                lastPeople: lastPeople,
                lastFeeds: lastFeeds,
                newestPeopleId: newestPeopleId,
                newestFeedsId: newestFeedsId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RowSummariesTable, RowSummary>(table),
                  BaseReferences<_$AppDatabase, $RowSummariesTable, RowSummary>(
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

typedef $$RowSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RowSummariesTable,
      RowSummary,
      $$RowSummariesTableFilterComposer,
      $$RowSummariesTableOrderingComposer,
      $$RowSummariesTableAnnotationComposer,
      $$RowSummariesTableCreateCompanionBuilder,
      $$RowSummariesTableUpdateCompanionBuilder,
      (
        RowSummary,
        BaseReferences<_$AppDatabase, $RowSummariesTable, RowSummary>,
      ),
      RowSummary,
      PrefetchHooks Function()
    >;
typedef $$DirtyRowsTableCreateCompanionBuilder = DirtyRowsCompanion Function({
  required String rowKey,
  Value<int> rowid,
});
typedef $$DirtyRowsTableUpdateCompanionBuilder = DirtyRowsCompanion Function({
  Value<String> rowKey,
  Value<int> rowid,
});

class $$DirtyRowsTableFilterComposer
    extends Composer<_$AppDatabase, $DirtyRowsTable> {
  $$DirtyRowsTableFilterComposer({
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
}

class $$DirtyRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $DirtyRowsTable> {
  $$DirtyRowsTableOrderingComposer({
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
}

class $$DirtyRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DirtyRowsTable> {
  $$DirtyRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rowKey =>
      $composableBuilder(column: $table.rowKey, builder: (column) => column);
}

class $$DirtyRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DirtyRowsTable,
          DirtyRow,
          $$DirtyRowsTableFilterComposer,
          $$DirtyRowsTableOrderingComposer,
          $$DirtyRowsTableAnnotationComposer,
          $$DirtyRowsTableCreateCompanionBuilder,
          $$DirtyRowsTableUpdateCompanionBuilder,
          (DirtyRow, BaseReferences<_$AppDatabase, $DirtyRowsTable, DirtyRow>),
          DirtyRow,
          PrefetchHooks Function()
        > {
  $$DirtyRowsTableTableManager(_$AppDatabase db, $DirtyRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DirtyRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DirtyRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DirtyRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> rowKey = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DirtyRowsCompanion(rowKey: rowKey, rowid: rowid),
          createCompanionCallback: ({
            required String rowKey,
            Value<int> rowid = const Value.absent(),
          }) => DirtyRowsCompanion.insert(rowKey: rowKey, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DirtyRowsTable, DirtyRow>(table),
                  BaseReferences<_$AppDatabase, $DirtyRowsTable, DirtyRow>(
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

typedef $$DirtyRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DirtyRowsTable,
      DirtyRow,
      $$DirtyRowsTableFilterComposer,
      $$DirtyRowsTableOrderingComposer,
      $$DirtyRowsTableAnnotationComposer,
      $$DirtyRowsTableCreateCompanionBuilder,
      $$DirtyRowsTableUpdateCompanionBuilder,
      (DirtyRow, BaseReferences<_$AppDatabase, $DirtyRowsTable, DirtyRow>),
      DirtyRow,
      PrefetchHooks Function()
    >;
typedef $$TrackerEventsTableCreateCompanionBuilder =
    TrackerEventsCompanion Function({
      Value<int> id,
      required int messageId,
      required String host,
      Value<bool> isTracker,
      Value<bool> blocked,
      Value<DateTime> at,
    });
typedef $$TrackerEventsTableUpdateCompanionBuilder =
    TrackerEventsCompanion Function({
      Value<int> id,
      Value<int> messageId,
      Value<String> host,
      Value<bool> isTracker,
      Value<bool> blocked,
      Value<DateTime> at,
    });

final class $$TrackerEventsTableReferences
    extends BaseReferences<_$AppDatabase, $TrackerEventsTable, TrackerEvent> {
  $$TrackerEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MessagesTable _messageIdTable(_$AppDatabase db) =>
      db.messages.createAlias('tracker_events__message_id__messages__id');

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

class $$TrackerEventsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackerEventsTable> {
  $$TrackerEventsTableFilterComposer({
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

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTracker => $composableBuilder(
    column: $table.isTracker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get blocked => $composableBuilder(
    column: $table.blocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
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

class $$TrackerEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackerEventsTable> {
  $$TrackerEventsTableOrderingComposer({
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

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTracker => $composableBuilder(
    column: $table.isTracker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get blocked => $composableBuilder(
    column: $table.blocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
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

class $$TrackerEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackerEventsTable> {
  $$TrackerEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<bool> get isTracker =>
      $composableBuilder(column: $table.isTracker, builder: (column) => column);

  GeneratedColumn<bool> get blocked =>
      $composableBuilder(column: $table.blocked, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

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

class $$TrackerEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackerEventsTable,
          TrackerEvent,
          $$TrackerEventsTableFilterComposer,
          $$TrackerEventsTableOrderingComposer,
          $$TrackerEventsTableAnnotationComposer,
          $$TrackerEventsTableCreateCompanionBuilder,
          $$TrackerEventsTableUpdateCompanionBuilder,
          (TrackerEvent, $$TrackerEventsTableReferences),
          TrackerEvent,
          PrefetchHooks Function({bool messageId})
        > {
  $$TrackerEventsTableTableManager(_$AppDatabase db, $TrackerEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackerEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackerEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackerEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<bool> isTracker = const Value.absent(),
                Value<bool> blocked = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
              }) => TrackerEventsCompanion(
                id: id,
                messageId: messageId,
                host: host,
                isTracker: isTracker,
                blocked: blocked,
                at: at,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int messageId,
                required String host,
                Value<bool> isTracker = const Value.absent(),
                Value<bool> blocked = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
              }) => TrackerEventsCompanion.insert(
                id: id,
                messageId: messageId,
                host: host,
                isTracker: isTracker,
                blocked: blocked,
                at: at,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackerEventsTable, TrackerEvent>(table),
                  $$TrackerEventsTableReferences(db, table, e),
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
                        referencedTable: $$TrackerEventsTableReferences
                            ._messageIdTable(db),
                        referencedColumn: $$TrackerEventsTableReferences
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

typedef $$TrackerEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackerEventsTable,
      TrackerEvent,
      $$TrackerEventsTableFilterComposer,
      $$TrackerEventsTableOrderingComposer,
      $$TrackerEventsTableAnnotationComposer,
      $$TrackerEventsTableCreateCompanionBuilder,
      $$TrackerEventsTableUpdateCompanionBuilder,
      (TrackerEvent, $$TrackerEventsTableReferences),
      TrackerEvent,
      PrefetchHooks Function({bool messageId})
    >;
typedef $$DraftsTableCreateCompanionBuilder = DraftsCompanion Function({
  Value<int> id,
  required int accountId,
  Value<int?> identityId,
  Value<String> kind,
  Value<String?> rowKey,
  Value<int?> inReplyToMessageId,
  Value<String> recipientsTo,
  Value<String> recipientsCc,
  Value<String> recipientsBcc,
  Value<String> subject,
  Value<String?> bodyJson,
  Value<String> bodyHtml,
  Value<String> attachmentsJson,
  Value<bool> includeQuote,
  Value<DateTime> updatedAt,
});
typedef $$DraftsTableUpdateCompanionBuilder = DraftsCompanion Function({
  Value<int> id,
  Value<int> accountId,
  Value<int?> identityId,
  Value<String> kind,
  Value<String?> rowKey,
  Value<int?> inReplyToMessageId,
  Value<String> recipientsTo,
  Value<String> recipientsCc,
  Value<String> recipientsBcc,
  Value<String> subject,
  Value<String?> bodyJson,
  Value<String> bodyHtml,
  Value<String> attachmentsJson,
  Value<bool> includeQuote,
  Value<DateTime> updatedAt,
});

final class $$DraftsTableReferences
    extends BaseReferences<_$AppDatabase, $DraftsTable, Draft> {
  $$DraftsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$AppDatabase db) =>
      db.accounts.createAlias('drafts__account_id__accounts__id');

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

class $$DraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
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

  ColumnFilters<int> get identityId => $composableBuilder(
    column: $table.identityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowKey => $composableBuilder(
    column: $table.rowKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inReplyToMessageId => $composableBuilder(
    column: $table.inReplyToMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientsTo => $composableBuilder(
    column: $table.recipientsTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientsCc => $composableBuilder(
    column: $table.recipientsCc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientsBcc => $composableBuilder(
    column: $table.recipientsBcc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyJson => $composableBuilder(
    column: $table.bodyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyHtml => $composableBuilder(
    column: $table.bodyHtml,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includeQuote => $composableBuilder(
    column: $table.includeQuote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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

class $$DraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
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

  ColumnOrderings<int> get identityId => $composableBuilder(
    column: $table.identityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowKey => $composableBuilder(
    column: $table.rowKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inReplyToMessageId => $composableBuilder(
    column: $table.inReplyToMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientsTo => $composableBuilder(
    column: $table.recipientsTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientsCc => $composableBuilder(
    column: $table.recipientsCc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientsBcc => $composableBuilder(
    column: $table.recipientsBcc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyJson => $composableBuilder(
    column: $table.bodyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyHtml => $composableBuilder(
    column: $table.bodyHtml,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includeQuote => $composableBuilder(
    column: $table.includeQuote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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

class $$DraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get identityId => $composableBuilder(
    column: $table.identityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get rowKey =>
      $composableBuilder(column: $table.rowKey, builder: (column) => column);

  GeneratedColumn<int> get inReplyToMessageId => $composableBuilder(
    column: $table.inReplyToMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientsTo => $composableBuilder(
    column: $table.recipientsTo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientsCc => $composableBuilder(
    column: $table.recipientsCc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientsBcc => $composableBuilder(
    column: $table.recipientsBcc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get bodyJson =>
      $composableBuilder(column: $table.bodyJson, builder: (column) => column);

  GeneratedColumn<String> get bodyHtml =>
      $composableBuilder(column: $table.bodyHtml, builder: (column) => column);

  GeneratedColumn<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get includeQuote => $composableBuilder(
    column: $table.includeQuote,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

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

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftsTable,
          Draft,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (Draft, $$DraftsTableReferences),
          Draft,
          PrefetchHooks Function({bool accountId})
        > {
  $$DraftsTableTableManager(_$AppDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> accountId = const Value.absent(),
                Value<int?> identityId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> rowKey = const Value.absent(),
                Value<int?> inReplyToMessageId = const Value.absent(),
                Value<String> recipientsTo = const Value.absent(),
                Value<String> recipientsCc = const Value.absent(),
                Value<String> recipientsBcc = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String?> bodyJson = const Value.absent(),
                Value<String> bodyHtml = const Value.absent(),
                Value<String> attachmentsJson = const Value.absent(),
                Value<bool> includeQuote = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DraftsCompanion(
                id: id,
                accountId: accountId,
                identityId: identityId,
                kind: kind,
                rowKey: rowKey,
                inReplyToMessageId: inReplyToMessageId,
                recipientsTo: recipientsTo,
                recipientsCc: recipientsCc,
                recipientsBcc: recipientsBcc,
                subject: subject,
                bodyJson: bodyJson,
                bodyHtml: bodyHtml,
                attachmentsJson: attachmentsJson,
                includeQuote: includeQuote,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int accountId,
                Value<int?> identityId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> rowKey = const Value.absent(),
                Value<int?> inReplyToMessageId = const Value.absent(),
                Value<String> recipientsTo = const Value.absent(),
                Value<String> recipientsCc = const Value.absent(),
                Value<String> recipientsBcc = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String?> bodyJson = const Value.absent(),
                Value<String> bodyHtml = const Value.absent(),
                Value<String> attachmentsJson = const Value.absent(),
                Value<bool> includeQuote = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DraftsCompanion.insert(
                id: id,
                accountId: accountId,
                identityId: identityId,
                kind: kind,
                rowKey: rowKey,
                inReplyToMessageId: inReplyToMessageId,
                recipientsTo: recipientsTo,
                recipientsCc: recipientsCc,
                recipientsBcc: recipientsBcc,
                subject: subject,
                bodyJson: bodyJson,
                bodyHtml: bodyHtml,
                attachmentsJson: attachmentsJson,
                includeQuote: includeQuote,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DraftsTable, Draft>(table),
                  $$DraftsTableReferences(db, table, e),
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
                        referencedTable: $$DraftsTableReferences
                            ._accountIdTable(db),
                        referencedColumn: $$DraftsTableReferences
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

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftsTable,
      Draft,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (Draft, $$DraftsTableReferences),
      Draft,
      PrefetchHooks Function({bool accountId})
    >;
typedef $$FeedsCategoryRowsTableCreateCompanionBuilder =
    FeedsCategoryRowsCompanion Function({
      Value<int> id,
      required String name,
      Value<bool> builtin,
      Value<int> sortOrder,
    });
typedef $$FeedsCategoryRowsTableUpdateCompanionBuilder =
    FeedsCategoryRowsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<bool> builtin,
      Value<int> sortOrder,
    });

class $$FeedsCategoryRowsTableFilterComposer
    extends Composer<_$AppDatabase, $FeedsCategoryRowsTable> {
  $$FeedsCategoryRowsTableFilterComposer({
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

  ColumnFilters<bool> get builtin => $composableBuilder(
    column: $table.builtin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FeedsCategoryRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedsCategoryRowsTable> {
  $$FeedsCategoryRowsTableOrderingComposer({
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

  ColumnOrderings<bool> get builtin => $composableBuilder(
    column: $table.builtin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FeedsCategoryRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedsCategoryRowsTable> {
  $$FeedsCategoryRowsTableAnnotationComposer({
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

  GeneratedColumn<bool> get builtin =>
      $composableBuilder(column: $table.builtin, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$FeedsCategoryRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FeedsCategoryRowsTable,
          FeedsCategoryRow,
          $$FeedsCategoryRowsTableFilterComposer,
          $$FeedsCategoryRowsTableOrderingComposer,
          $$FeedsCategoryRowsTableAnnotationComposer,
          $$FeedsCategoryRowsTableCreateCompanionBuilder,
          $$FeedsCategoryRowsTableUpdateCompanionBuilder,
          (
            FeedsCategoryRow,
            BaseReferences<
              _$AppDatabase,
              $FeedsCategoryRowsTable,
              FeedsCategoryRow
            >,
          ),
          FeedsCategoryRow,
          PrefetchHooks Function()
        > {
  $$FeedsCategoryRowsTableTableManager(
    _$AppDatabase db,
    $FeedsCategoryRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedsCategoryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedsCategoryRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedsCategoryRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> builtin = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => FeedsCategoryRowsCompanion(
                id: id,
                name: name,
                builtin: builtin,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> builtin = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => FeedsCategoryRowsCompanion.insert(
                id: id,
                name: name,
                builtin: builtin,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FeedsCategoryRowsTable, FeedsCategoryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FeedsCategoryRowsTable,
                    FeedsCategoryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FeedsCategoryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FeedsCategoryRowsTable,
      FeedsCategoryRow,
      $$FeedsCategoryRowsTableFilterComposer,
      $$FeedsCategoryRowsTableOrderingComposer,
      $$FeedsCategoryRowsTableAnnotationComposer,
      $$FeedsCategoryRowsTableCreateCompanionBuilder,
      $$FeedsCategoryRowsTableUpdateCompanionBuilder,
      (
        FeedsCategoryRow,
        BaseReferences<
          _$AppDatabase,
          $FeedsCategoryRowsTable,
          FeedsCategoryRow
        >,
      ),
      FeedsCategoryRow,
      PrefetchHooks Function()
    >;
typedef $$ClassificationRulesTableCreateCompanionBuilder =
    ClassificationRulesCompanion Function({
      Value<int> id,
      required String field,
      required String pattern,
      Value<String?> bucket,
      Value<String?> category,
      Value<DateTime> createdAt,
    });
typedef $$ClassificationRulesTableUpdateCompanionBuilder =
    ClassificationRulesCompanion Function({
      Value<int> id,
      Value<String> field,
      Value<String> pattern,
      Value<String?> bucket,
      Value<String?> category,
      Value<DateTime> createdAt,
    });

class $$ClassificationRulesTableFilterComposer
    extends Composer<_$AppDatabase, $ClassificationRulesTable> {
  $$ClassificationRulesTableFilterComposer({
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

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClassificationRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClassificationRulesTable> {
  $$ClassificationRulesTableOrderingComposer({
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

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucket => $composableBuilder(
    column: $table.bucket,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClassificationRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClassificationRulesTable> {
  $$ClassificationRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ClassificationRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClassificationRulesTable,
          ClassificationRule,
          $$ClassificationRulesTableFilterComposer,
          $$ClassificationRulesTableOrderingComposer,
          $$ClassificationRulesTableAnnotationComposer,
          $$ClassificationRulesTableCreateCompanionBuilder,
          $$ClassificationRulesTableUpdateCompanionBuilder,
          (
            ClassificationRule,
            BaseReferences<
              _$AppDatabase,
              $ClassificationRulesTable,
              ClassificationRule
            >,
          ),
          ClassificationRule,
          PrefetchHooks Function()
        > {
  $$ClassificationRulesTableTableManager(
    _$AppDatabase db,
    $ClassificationRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassificationRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClassificationRulesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ClassificationRulesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<String?> bucket = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ClassificationRulesCompanion(
                id: id,
                field: field,
                pattern: pattern,
                bucket: bucket,
                category: category,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String field,
                required String pattern,
                Value<String?> bucket = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ClassificationRulesCompanion.insert(
                id: id,
                field: field,
                pattern: pattern,
                bucket: bucket,
                category: category,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClassificationRulesTable, ClassificationRule>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ClassificationRulesTable,
                    ClassificationRule
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClassificationRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClassificationRulesTable,
      ClassificationRule,
      $$ClassificationRulesTableFilterComposer,
      $$ClassificationRulesTableOrderingComposer,
      $$ClassificationRulesTableAnnotationComposer,
      $$ClassificationRulesTableCreateCompanionBuilder,
      $$ClassificationRulesTableUpdateCompanionBuilder,
      (
        ClassificationRule,
        BaseReferences<
          _$AppDatabase,
          $ClassificationRulesTable,
          ClassificationRule
        >,
      ),
      ClassificationRule,
      PrefetchHooks Function()
    >;
typedef $$ClassificationEventsTableCreateCompanionBuilder =
    ClassificationEventsCompanion Function({
      Value<int> id,
      Value<int?> messageId,
      required String contactKey,
      required String decision,
      Value<String?> category,
      Value<String> reasons,
      required String source,
      Value<DateTime> at,
    });
typedef $$ClassificationEventsTableUpdateCompanionBuilder =
    ClassificationEventsCompanion Function({
      Value<int> id,
      Value<int?> messageId,
      Value<String> contactKey,
      Value<String> decision,
      Value<String?> category,
      Value<String> reasons,
      Value<String> source,
      Value<DateTime> at,
    });

class $$ClassificationEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ClassificationEventsTable> {
  $$ClassificationEventsTableFilterComposer({
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

  ColumnFilters<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactKey => $composableBuilder(
    column: $table.contactKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decision => $composableBuilder(
    column: $table.decision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasons => $composableBuilder(
    column: $table.reasons,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClassificationEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClassificationEventsTable> {
  $$ClassificationEventsTableOrderingComposer({
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

  ColumnOrderings<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactKey => $composableBuilder(
    column: $table.contactKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decision => $composableBuilder(
    column: $table.decision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasons => $composableBuilder(
    column: $table.reasons,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClassificationEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClassificationEventsTable> {
  $$ClassificationEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get contactKey => $composableBuilder(
    column: $table.contactKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get decision =>
      $composableBuilder(column: $table.decision, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get reasons =>
      $composableBuilder(column: $table.reasons, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$ClassificationEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClassificationEventsTable,
          ClassificationEvent,
          $$ClassificationEventsTableFilterComposer,
          $$ClassificationEventsTableOrderingComposer,
          $$ClassificationEventsTableAnnotationComposer,
          $$ClassificationEventsTableCreateCompanionBuilder,
          $$ClassificationEventsTableUpdateCompanionBuilder,
          (
            ClassificationEvent,
            BaseReferences<
              _$AppDatabase,
              $ClassificationEventsTable,
              ClassificationEvent
            >,
          ),
          ClassificationEvent,
          PrefetchHooks Function()
        > {
  $$ClassificationEventsTableTableManager(
    _$AppDatabase db,
    $ClassificationEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassificationEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClassificationEventsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ClassificationEventsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> messageId = const Value.absent(),
                Value<String> contactKey = const Value.absent(),
                Value<String> decision = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> reasons = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
              }) => ClassificationEventsCompanion(
                id: id,
                messageId: messageId,
                contactKey: contactKey,
                decision: decision,
                category: category,
                reasons: reasons,
                source: source,
                at: at,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> messageId = const Value.absent(),
                required String contactKey,
                required String decision,
                Value<String?> category = const Value.absent(),
                Value<String> reasons = const Value.absent(),
                required String source,
                Value<DateTime> at = const Value.absent(),
              }) => ClassificationEventsCompanion.insert(
                id: id,
                messageId: messageId,
                contactKey: contactKey,
                decision: decision,
                category: category,
                reasons: reasons,
                source: source,
                at: at,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClassificationEventsTable, ClassificationEvent>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ClassificationEventsTable,
                    ClassificationEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClassificationEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClassificationEventsTable,
      ClassificationEvent,
      $$ClassificationEventsTableFilterComposer,
      $$ClassificationEventsTableOrderingComposer,
      $$ClassificationEventsTableAnnotationComposer,
      $$ClassificationEventsTableCreateCompanionBuilder,
      $$ClassificationEventsTableUpdateCompanionBuilder,
      (
        ClassificationEvent,
        BaseReferences<
          _$AppDatabase,
          $ClassificationEventsTable,
          ClassificationEvent
        >,
      ),
      ClassificationEvent,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  required String name,
  Value<int?> parentId,
  Value<int?> color,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int?> parentId,
  Value<int?> color,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
});

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CardTagsTable, List<CardTag>> _cardTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cardTags,
    aliasName: 'tags__id__card_tags__tag_id',
  );

  $$CardTagsTableProcessedTableManager get cardTagsRefs {
    final manager = $$CardTagsTableTableManager(
      $_db,
      $_db.cardTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
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

  ColumnFilters<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
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

  Expression<bool> cardTagsRefs(
    Expression<bool> Function($$CardTagsTableFilterComposer f) f,
  ) {
    final $$CardTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardTagsTableFilterComposer(
            $db: $db,
            $table: $db.cardTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
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

  ColumnOrderings<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
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
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
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

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> cardTagsRefs<T extends Object>(
    Expression<T> Function($$CardTagsTableAnnotationComposer a) f,
  ) {
    final $$CardTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.cardTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool cardTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                parentId: parentId,
                color: color,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> parentId = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                parentId: parentId,
                color: color,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagsTable, Tag>(table),
                  $$TagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cardTagsRefs) db.cardTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cardTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, CardTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences._cardTagsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).cardTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool cardTagsRefs})
    >;
typedef $$BoardColumnsTableCreateCompanionBuilder =
    BoardColumnsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });
typedef $$BoardColumnsTableUpdateCompanionBuilder =
    BoardColumnsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
    });

final class $$BoardColumnsTableReferences
    extends BaseReferences<_$AppDatabase, $BoardColumnsTable, BoardColumn> {
  $$BoardColumnsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CardsTable, List<Card>> _cardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cards,
    aliasName: 'board_columns__id__cards__column_id',
  );

  $$CardsTableProcessedTableManager get cardsRefs {
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.columnId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BoardColumnsTableFilterComposer
    extends Composer<_$AppDatabase, $BoardColumnsTable> {
  $$BoardColumnsTableFilterComposer({
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

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cardsRefs(
    Expression<bool> Function($$CardsTableFilterComposer f) f,
  ) {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.columnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BoardColumnsTableOrderingComposer
    extends Composer<_$AppDatabase, $BoardColumnsTable> {
  $$BoardColumnsTableOrderingComposer({
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

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BoardColumnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BoardColumnsTable> {
  $$BoardColumnsTableAnnotationComposer({
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

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> cardsRefs<T extends Object>(
    Expression<T> Function($$CardsTableAnnotationComposer a) f,
  ) {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.columnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BoardColumnsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BoardColumnsTable,
          BoardColumn,
          $$BoardColumnsTableFilterComposer,
          $$BoardColumnsTableOrderingComposer,
          $$BoardColumnsTableAnnotationComposer,
          $$BoardColumnsTableCreateCompanionBuilder,
          $$BoardColumnsTableUpdateCompanionBuilder,
          (BoardColumn, $$BoardColumnsTableReferences),
          BoardColumn,
          PrefetchHooks Function({bool cardsRefs})
        > {
  $$BoardColumnsTableTableManager(_$AppDatabase db, $BoardColumnsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardColumnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardColumnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardColumnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BoardColumnsCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BoardColumnsCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BoardColumnsTable, BoardColumn>(table),
                  $$BoardColumnsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cardsRefs) db.cards],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cardsRefs)
                    await $_getPrefetchedData<
                      BoardColumn,
                      $BoardColumnsTable,
                      Card
                    >(
                      currentTable: table,
                      referencedTable: $$BoardColumnsTableReferences
                          ._cardsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$BoardColumnsTableReferences(
                            db,
                            table,
                            p0,
                          ).cardsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.columnId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BoardColumnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BoardColumnsTable,
      BoardColumn,
      $$BoardColumnsTableFilterComposer,
      $$BoardColumnsTableOrderingComposer,
      $$BoardColumnsTableAnnotationComposer,
      $$BoardColumnsTableCreateCompanionBuilder,
      $$BoardColumnsTableUpdateCompanionBuilder,
      (BoardColumn, $$BoardColumnsTableReferences),
      BoardColumn,
      PrefetchHooks Function({bool cardsRefs})
    >;
typedef $$CardsTableCreateCompanionBuilder = CardsCompanion Function({
  Value<int> id,
  required String threadKey,
  required int columnId,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$CardsTableUpdateCompanionBuilder = CardsCompanion Function({
  Value<int> id,
  Value<String> threadKey,
  Value<int> columnId,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$CardsTableReferences
    extends BaseReferences<_$AppDatabase, $CardsTable, Card> {
  $$CardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BoardColumnsTable _columnIdTable(_$AppDatabase db) =>
      db.boardColumns.createAlias('cards__column_id__board_columns__id');

  $$BoardColumnsTableProcessedTableManager get columnId {
    final $_column = $_itemColumn<int>('column_id')!;

    final manager = $$BoardColumnsTableTableManager(
      $_db,
      $_db.boardColumns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_columnIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CardTagsTable, List<CardTag>> _cardTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cardTags,
    aliasName: 'cards__id__card_tags__card_id',
  );

  $$CardTagsTableProcessedTableManager get cardTagsRefs {
    final manager = $$CardTagsTableTableManager(
      $_db,
      $_db.cardTags,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
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

  ColumnFilters<String> get threadKey => $composableBuilder(
    column: $table.threadKey,
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BoardColumnsTableFilterComposer get columnId {
    final $$BoardColumnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.columnId,
      referencedTable: $db.boardColumns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardColumnsTableFilterComposer(
            $db: $db,
            $table: $db.boardColumns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cardTagsRefs(
    Expression<bool> Function($$CardTagsTableFilterComposer f) f,
  ) {
    final $$CardTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardTags,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardTagsTableFilterComposer(
            $db: $db,
            $table: $db.cardTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
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

  ColumnOrderings<String> get threadKey => $composableBuilder(
    column: $table.threadKey,
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BoardColumnsTableOrderingComposer get columnId {
    final $$BoardColumnsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.columnId,
      referencedTable: $db.boardColumns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardColumnsTableOrderingComposer(
            $db: $db,
            $table: $db.boardColumns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get threadKey =>
      $composableBuilder(column: $table.threadKey, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BoardColumnsTableAnnotationComposer get columnId {
    final $$BoardColumnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.columnId,
      referencedTable: $db.boardColumns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BoardColumnsTableAnnotationComposer(
            $db: $db,
            $table: $db.boardColumns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cardTagsRefs<T extends Object>(
    Expression<T> Function($$CardTagsTableAnnotationComposer a) f,
  ) {
    final $$CardTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardTags,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.cardTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          Card,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (Card, $$CardsTableReferences),
          Card,
          PrefetchHooks Function({bool columnId, bool cardTagsRefs})
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> threadKey = const Value.absent(),
                Value<int> columnId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CardsCompanion(
                id: id,
                threadKey: threadKey,
                columnId: columnId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String threadKey,
                required int columnId,
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CardsCompanion.insert(
                id: id,
                threadKey: threadKey,
                columnId: columnId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardsTable, Card>(table),
                  $$CardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({columnId = false, cardTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (cardTagsRefs) db.cardTags],
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
                    if (columnId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.columnId,
                        referencedTable: $$CardsTableReferences._columnIdTable(
                          db,
                        ),
                        referencedColumn: $$CardsTableReferences
                            ._columnIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (cardTagsRefs)
                    await $_getPrefetchedData<Card, $CardsTable, CardTag>(
                      currentTable: table,
                      referencedTable: $$CardsTableReferences
                          ._cardTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CardsTableReferences(db, table, p0).cardTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.cardId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      Card,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (Card, $$CardsTableReferences),
      Card,
      PrefetchHooks Function({bool columnId, bool cardTagsRefs})
    >;
typedef $$CardTagsTableCreateCompanionBuilder = CardTagsCompanion Function({
  required int cardId,
  required int tagId,
  Value<int> rowid,
});
typedef $$CardTagsTableUpdateCompanionBuilder = CardTagsCompanion Function({
  Value<int> cardId,
  Value<int> tagId,
  Value<int> rowid,
});

final class $$CardTagsTableReferences
    extends BaseReferences<_$AppDatabase, $CardTagsTable, CardTag> {
  $$CardTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$AppDatabase db) =>
      db.cards.createAlias('card_tags__card_id__cards__id');

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('card_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardTagsTableFilterComposer
    extends Composer<_$AppDatabase, $CardTagsTable> {
  $$CardTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardTagsTable> {
  $$CardTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardTagsTable> {
  $$CardTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardTagsTable,
          CardTag,
          $$CardTagsTableFilterComposer,
          $$CardTagsTableOrderingComposer,
          $$CardTagsTableAnnotationComposer,
          $$CardTagsTableCreateCompanionBuilder,
          $$CardTagsTableUpdateCompanionBuilder,
          (CardTag, $$CardTagsTableReferences),
          CardTag,
          PrefetchHooks Function({bool cardId, bool tagId})
        > {
  $$CardTagsTableTableManager(_$AppDatabase db, $CardTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> cardId = const Value.absent(),
            Value<int> tagId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => CardTagsCompanion(cardId: cardId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required int cardId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => CardTagsCompanion.insert(
                cardId: cardId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardTagsTable, CardTag>(table),
                  $$CardTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false, tagId = false}) {
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
                    if (cardId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cardId,
                        referencedTable: $$CardTagsTableReferences._cardIdTable(
                          db,
                        ),
                        referencedColumn: $$CardTagsTableReferences
                            ._cardIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $$CardTagsTableReferences._tagIdTable(
                          db,
                        ),
                        referencedColumn: $$CardTagsTableReferences
                            ._tagIdTable(db)
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

typedef $$CardTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardTagsTable,
      CardTag,
      $$CardTagsTableFilterComposer,
      $$CardTagsTableOrderingComposer,
      $$CardTagsTableAnnotationComposer,
      $$CardTagsTableCreateCompanionBuilder,
      $$CardTagsTableUpdateCompanionBuilder,
      (CardTag, $$CardTagsTableReferences),
      CardTag,
      PrefetchHooks Function({bool cardId, bool tagId})
    >;
typedef $$RemindersTableCreateCompanionBuilder = RemindersCompanion Function({
  Value<int> id,
  required String title,
  required DateTime dueAt,
  Value<int?> messageId,
  Value<String?> threadKey,
  Value<String?> rowKey,
  Value<bool> done,
  Value<DateTime?> firedAt,
  Value<DateTime> createdAt,
});
typedef $$RemindersTableUpdateCompanionBuilder = RemindersCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<DateTime> dueAt,
  Value<int?> messageId,
  Value<String?> threadKey,
  Value<String?> rowKey,
  Value<bool> done,
  Value<DateTime?> firedAt,
  Value<DateTime> createdAt,
});

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadKey => $composableBuilder(
    column: $table.threadKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowKey => $composableBuilder(
    column: $table.rowKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadKey => $composableBuilder(
    column: $table.threadKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowKey => $composableBuilder(
    column: $table.rowKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<int> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get threadKey =>
      $composableBuilder(column: $table.threadKey, builder: (column) => column);

  GeneratedColumn<String> get rowKey =>
      $composableBuilder(column: $table.rowKey, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<DateTime> get firedAt =>
      $composableBuilder(column: $table.firedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          Reminder,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
          Reminder,
          PrefetchHooks Function()
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<int?> messageId = const Value.absent(),
                Value<String?> threadKey = const Value.absent(),
                Value<String?> rowKey = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<DateTime?> firedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                title: title,
                dueAt: dueAt,
                messageId: messageId,
                threadKey: threadKey,
                rowKey: rowKey,
                done: done,
                firedAt: firedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required DateTime dueAt,
                Value<int?> messageId = const Value.absent(),
                Value<String?> threadKey = const Value.absent(),
                Value<String?> rowKey = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<DateTime?> firedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                title: title,
                dueAt: dueAt,
                messageId: messageId,
                threadKey: threadKey,
                rowKey: rowKey,
                done: done,
                firedAt: firedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemindersTable, Reminder>(table),
                  BaseReferences<_$AppDatabase, $RemindersTable, Reminder>(
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

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      Reminder,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
      Reminder,
      PrefetchHooks Function()
    >;
typedef $$PlannerEventsTableCreateCompanionBuilder =
    PlannerEventsCompanion Function({
      Value<int> id,
      required String title,
      Value<DateTime?> startAt,
      Value<DateTime?> endAt,
      Value<bool> allDay,
      required String kind,
      Value<String> colorKey,
      Value<int?> sourceMessageId,
      Value<String?> threadKey,
      Value<String?> location,
      Value<String> notes,
      Value<bool> done,
      Value<bool> dismissed,
      Value<double> confidence,
      Value<String?> uid,
      Value<String> evidence,
      Value<DateTime> createdAt,
    });
typedef $$PlannerEventsTableUpdateCompanionBuilder =
    PlannerEventsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<DateTime?> startAt,
      Value<DateTime?> endAt,
      Value<bool> allDay,
      Value<String> kind,
      Value<String> colorKey,
      Value<int?> sourceMessageId,
      Value<String?> threadKey,
      Value<String?> location,
      Value<String> notes,
      Value<bool> done,
      Value<bool> dismissed,
      Value<double> confidence,
      Value<String?> uid,
      Value<String> evidence,
      Value<DateTime> createdAt,
    });

class $$PlannerEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PlannerEventsTable> {
  $$PlannerEventsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorKey => $composableBuilder(
    column: $table.colorKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadKey => $composableBuilder(
    column: $table.threadKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidence => $composableBuilder(
    column: $table.evidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlannerEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlannerEventsTable> {
  $$PlannerEventsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorKey => $composableBuilder(
    column: $table.colorKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadKey => $composableBuilder(
    column: $table.threadKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dismissed => $composableBuilder(
    column: $table.dismissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidence => $composableBuilder(
    column: $table.evidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlannerEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlannerEventsTable> {
  $$PlannerEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get colorKey =>
      $composableBuilder(column: $table.colorKey, builder: (column) => column);

  GeneratedColumn<int> get sourceMessageId => $composableBuilder(
    column: $table.sourceMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get threadKey =>
      $composableBuilder(column: $table.threadKey, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<bool> get dismissed =>
      $composableBuilder(column: $table.dismissed, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get evidence =>
      $composableBuilder(column: $table.evidence, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PlannerEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlannerEventsTable,
          PlannerEvent,
          $$PlannerEventsTableFilterComposer,
          $$PlannerEventsTableOrderingComposer,
          $$PlannerEventsTableAnnotationComposer,
          $$PlannerEventsTableCreateCompanionBuilder,
          $$PlannerEventsTableUpdateCompanionBuilder,
          (
            PlannerEvent,
            BaseReferences<_$AppDatabase, $PlannerEventsTable, PlannerEvent>,
          ),
          PlannerEvent,
          PrefetchHooks Function()
        > {
  $$PlannerEventsTableTableManager(_$AppDatabase db, $PlannerEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlannerEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlannerEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlannerEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime?> startAt = const Value.absent(),
                Value<DateTime?> endAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> colorKey = const Value.absent(),
                Value<int?> sourceMessageId = const Value.absent(),
                Value<String?> threadKey = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String?> uid = const Value.absent(),
                Value<String> evidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PlannerEventsCompanion(
                id: id,
                title: title,
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                kind: kind,
                colorKey: colorKey,
                sourceMessageId: sourceMessageId,
                threadKey: threadKey,
                location: location,
                notes: notes,
                done: done,
                dismissed: dismissed,
                confidence: confidence,
                uid: uid,
                evidence: evidence,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<DateTime?> startAt = const Value.absent(),
                Value<DateTime?> endAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                required String kind,
                Value<String> colorKey = const Value.absent(),
                Value<int?> sourceMessageId = const Value.absent(),
                Value<String?> threadKey = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<bool> dismissed = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String?> uid = const Value.absent(),
                Value<String> evidence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PlannerEventsCompanion.insert(
                id: id,
                title: title,
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                kind: kind,
                colorKey: colorKey,
                sourceMessageId: sourceMessageId,
                threadKey: threadKey,
                location: location,
                notes: notes,
                done: done,
                dismissed: dismissed,
                confidence: confidence,
                uid: uid,
                evidence: evidence,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlannerEventsTable, PlannerEvent>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PlannerEventsTable,
                    PlannerEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlannerEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlannerEventsTable,
      PlannerEvent,
      $$PlannerEventsTableFilterComposer,
      $$PlannerEventsTableOrderingComposer,
      $$PlannerEventsTableAnnotationComposer,
      $$PlannerEventsTableCreateCompanionBuilder,
      $$PlannerEventsTableUpdateCompanionBuilder,
      (
        PlannerEvent,
        BaseReferences<_$AppDatabase, $PlannerEventsTable, PlannerEvent>,
      ),
      PlannerEvent,
      PrefetchHooks Function()
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
  $$RowPrefsTableTableManager get rowPrefs =>
      $$RowPrefsTableTableManager(_db, _db.rowPrefs);
  $$RowSummariesTableTableManager get rowSummaries =>
      $$RowSummariesTableTableManager(_db, _db.rowSummaries);
  $$DirtyRowsTableTableManager get dirtyRows =>
      $$DirtyRowsTableTableManager(_db, _db.dirtyRows);
  $$TrackerEventsTableTableManager get trackerEvents =>
      $$TrackerEventsTableTableManager(_db, _db.trackerEvents);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
  $$FeedsCategoryRowsTableTableManager get feedsCategoryRows =>
      $$FeedsCategoryRowsTableTableManager(_db, _db.feedsCategoryRows);
  $$ClassificationRulesTableTableManager get classificationRules =>
      $$ClassificationRulesTableTableManager(_db, _db.classificationRules);
  $$ClassificationEventsTableTableManager get classificationEvents =>
      $$ClassificationEventsTableTableManager(_db, _db.classificationEvents);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$BoardColumnsTableTableManager get boardColumns =>
      $$BoardColumnsTableTableManager(_db, _db.boardColumns);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$CardTagsTableTableManager get cardTags =>
      $$CardTagsTableTableManager(_db, _db.cardTags);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$PlannerEventsTableTableManager get plannerEvents =>
      $$PlannerEventsTableTableManager(_db, _db.plannerEvents);
}
