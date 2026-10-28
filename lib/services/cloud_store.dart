import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class CloudConfig {
  const CloudConfig({
    this.accountId,
    this.email,
    this.folderId,
    this.folderName,
    this.enabled = false,
    this.enabledAt = 0,
  });
  final String? accountId;
  final String? email;
  final String? folderId;
  final String? folderName;
  final bool enabled;
  final int enabledAt;
  bool get connected => accountId != null && email != null;
  factory CloudConfig.fromMap(Map<String, Object?> json) => CloudConfig(
    accountId: json['accountId'] as String?,
    email: json['email'] as String?,
    folderId: json['folderId'] as String?,
    folderName: json['folderName'] as String?,
    enabled: json['enabled'] == 1,
    enabledAt: json['enabledAt'] as int? ?? 0,
  );
}

enum CloudJobStatus { pending, uploading, synced, blocked }

class CloudJob {
  const CloudJob({
    required this.id,
    required this.path,
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    this.error,
  });

  final int id;
  final String path;
  final CloudJobStatus status;
  final int attempts;
  final int createdAt;
  final int updatedAt;
  final String? error;

  String get fileName => path.split(Platform.pathSeparator).last;

  factory CloudJob.fromMap(Map<String, Object?> value) => CloudJob(
    id: value['id'] as int,
    path: value['path'] as String,
    status: CloudJobStatus.values.firstWhere(
      (status) => status.name == value['status'],
      orElse: () => CloudJobStatus.pending,
    ),
    attempts: value['attempts'] as int? ?? 0,
    createdAt: value['createdAt'] as int? ?? 0,
    updatedAt: value['updatedAt'] as int? ?? 0,
    error: value['error'] as String?,
  );
}

class CloudStore {
  CloudStore({Database? database}) : _injected = database;
  final Database? _injected;
  static Future<Database>? _database;
  Future<Database> get database async =>
      _injected ?? await (_database ??= _open());

  static Future<Database> _open() async {
    final root = await getApplicationDocumentsDirectory();
    return openDatabase(
      '${root.path}/cloud_sync.db',
      version: 2,
      onCreate: createSchema,
      onUpgrade: upgradeSchema,
    );
  }

  static Future<void> createSchema(Database db, int version) async {
    await db.execute(
      'CREATE TABLE config (id INTEGER PRIMARY KEY CHECK(id=1), accountId TEXT, email TEXT, folderId TEXT, folderName TEXT, enabled INTEGER NOT NULL DEFAULT 0, enabledAt INTEGER NOT NULL DEFAULT 0)',
    );
    await db.insert('config', {'id': 1});
    await db.execute(
      'CREATE TABLE jobs (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL, accountId TEXT NOT NULL, email TEXT NOT NULL, folderId TEXT NOT NULL, remoteId TEXT, status TEXT NOT NULL DEFAULT \'pending\', attempts INTEGER NOT NULL DEFAULT 0, lease INTEGER NOT NULL DEFAULT 0, error TEXT, createdAt INTEGER NOT NULL DEFAULT 0, updatedAt INTEGER NOT NULL DEFAULT 0, UNIQUE(path, accountId, folderId))',
    );
  }

  static Future<void> upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE jobs ADD COLUMN createdAt INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE jobs ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0',
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.update('jobs', {'createdAt': now, 'updatedAt': now});
    }
  }

  Future<CloudConfig> config() async =>
      CloudConfig.fromMap((await (await database).query('config')).single);

  Future<void> connect(String id, String email) async {
    final db = await database;
    await db.transaction((txn) async {
      final previous = (await txn.query('config')).single;
      await txn.update('config', {
        'accountId': id,
        'email': email,
        if (previous['accountId'] != id) ...{
          'folderId': null,
          'folderName': null,
          'enabled': 0,
          'enabledAt': 0,
        },
      }, where: 'id=1');
    });
  }

  Future<void> target(String id, String name) async {
    await (await database).update('config', {
      'folderId': id,
      'folderName': name,
      'enabled': 1,
      'enabledAt': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id=1');
  }

  Future<void> setEnabled(bool value) async {
    final c = await config();
    if (value && (!c.connected || c.folderId == null)) {
      throw StateError('Hubungkan Google dan pilih folder terlebih dahulu.');
    }
    await (await database).update('config', {
      'enabled': value ? 1 : 0,
      if (value && !c.enabled)
        'enabledAt': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id=1');
  }

  Future<void> disconnect() async {
    await (await database).update('config', {
      'accountId': null,
      'email': null,
      'folderId': null,
      'folderName': null,
      'enabled': 0,
      'enabledAt': 0,
    }, where: 'id=1');
  }

  Future<void> enqueue(File file) async {
    final db = await database;
    await db.transaction((txn) async {
      final c = CloudConfig.fromMap((await txn.query('config')).single);
      if (!c.enabled || !c.connected || c.folderId == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert('jobs', {
        'path': file.path,
        'accountId': c.accountId,
        'email': c.email,
        'folderId': c.folderId,
        'createdAt': now,
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  Future<Map<String, Object?>?> claim() async {
    final db = await database;
    return db.transaction((txn) async {
      final c = CloudConfig.fromMap((await txn.query('config')).single);
      if (!c.enabled || !c.connected) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      final rows = await txn.query(
        'jobs',
        where: 'accountId=? AND (status=? OR (status=? AND lease<?))',
        whereArgs: [c.accountId, 'pending', 'uploading', now],
        orderBy: 'id',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.single;
      await txn.update(
        'jobs',
        {
          'status': 'uploading',
          'lease': now + 600000,
          'attempts': (row['attempts'] as int) + 1,
          'updatedAt': now,
        },
        where: 'id=?',
        whereArgs: [row['id']],
      );
      return row;
    });
  }

  Future<void> updateJob(int id, Map<String, Object?> fields) async =>
      (await database).update(
        'jobs',
        {...fields, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
        where: 'id=?',
        whereArgs: [id],
      );

  Future<void> retry() async {
    final c = await config();
    await (await database).update(
      'jobs',
      {
        'status': 'pending',
        'error': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'accountId=? AND status=?',
      whereArgs: [c.accountId, 'blocked'],
    );
  }

  Future<void> retryJob(int id) async {
    final c = await config();
    await (await database).update(
      'jobs',
      {
        'status': 'pending',
        'error': null,
        'lease': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id=? AND accountId=? AND status!=?',
      whereArgs: [id, c.accountId, 'synced'],
    );
  }

  Future<List<CloudJob>> jobs({int limit = 50}) async {
    final c = await config();
    if (!c.connected) return const [];
    final rows = await (await database).query(
      'jobs',
      where: 'accountId=?',
      whereArgs: [c.accountId],
      orderBy:
          "CASE status WHEN 'uploading' THEN 0 WHEN 'blocked' THEN 1 WHEN 'pending' THEN 2 ELSE 3 END, updatedAt DESC, id DESC",
      limit: limit,
    );
    return rows.map(CloudJob.fromMap).toList(growable: false);
  }

  Future<({int pending, int uploading, int synced, int blocked, String? error})>
  summary() async {
    final c = await config();
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT status, COUNT(*) AS n FROM jobs WHERE accountId=? GROUP BY status',
      [c.accountId],
    );
    var pending = 0, uploading = 0, synced = 0, blocked = 0;
    for (final row in rows) {
      final n = row['n'] as int;
      switch (row['status']) {
        case 'synced':
          synced += n;
        case 'blocked':
          blocked += n;
        case 'uploading':
          uploading += n;
        default:
          pending += n;
      }
    }
    final errors = await db.query(
      'jobs',
      columns: ['error'],
      where: 'accountId=? AND error IS NOT NULL AND status!=?',
      whereArgs: [c.accountId, 'synced'],
      orderBy: 'id DESC',
      limit: 1,
    );
    return (
      pending: pending,
      uploading: uploading,
      synced: synced,
      blocked: blocked,
      error: errors.isEmpty ? null : errors.single['error'] as String?,
    );
  }
}
