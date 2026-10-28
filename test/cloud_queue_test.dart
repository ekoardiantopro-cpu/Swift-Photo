import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swift_photo/services/cloud_store.dart';
import 'package:swift_photo/services/cloud_sync_service.dart';
import 'package:swift_photo/services/drive_api.dart';

class _UploadState {
  int generated = 0;
  bool offline = true;
  final ids = <String>[];
}

class _FakeDrive extends DriveApi {
  _FakeDrive(this.state)
    : super(token: () async => '', invalidate: (_) async {});
  final _UploadState state;
  @override
  Future<String> generateId() async {
    state.generated++;
    return 'remote-1';
  }

  @override
  Future<void> upload(
    File file,
    String folderId,
    String remoteId, {
    required Future<bool> Function() shouldContinue,
  }) async {
    state.ids.add(remoteId);
    if (!await shouldContinue()) throw const UploadPaused();
    if (state.offline) throw const SocketException('offline');
  }
}

void main() {
  sqfliteFfiInit();
  late Database db;
  late CloudStore store;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: CloudStore.createSchema,
      ),
    );
    store = CloudStore(database: db);
  });
  tearDown(() => db.close());

  test(
    'Sync is opt-in, deduplicated, and keeps queued files bound to their account and folder',
    () async {
      final photo = File('photo.png');
      await store.enqueue(photo);
      expect(await db.query('jobs'), isEmpty);
      await store.connect('a', 'a@example.com');
      await store.target('folder-a', 'Site A');
      await Future.wait([store.enqueue(photo), store.enqueue(photo)]);
      expect(await db.query('jobs'), hasLength(1));
      await store.connect('b', 'b@example.com');
      expect((await store.config()).enabled, isFalse);
      expect((await store.config()).folderId, isNull);
      await store.target('folder-b', 'Site B');
      expect(await store.claim(), isNull);
      await store.enqueue(photo);
      final job = (await store.claim())!;
      expect(job['accountId'], 'b');
      expect(job['folderId'], 'folder-b');
      expect(await store.claim(), isNull);
    },
  );

  test(
    'Disabled Sync pauses queued work and expired claims recover after process death',
    () async {
      await store.connect('a', 'a@example.com');
      await store.target('folder', 'Site');
      await store.enqueue(File('photo.png'));
      final first = (await store.claim())!;
      expect(await store.claim(), isNull);
      await store.updateJob(first['id'] as int, {'lease': 0});
      await store.setEnabled(false);
      expect(await store.claim(), isNull);
      await store.setEnabled(true);
      expect((await store.claim())!['id'], first['id']);
    },
  );

  test(
    'Queue exposes per-photo status and supports a targeted retry',
    () async {
      await store.connect('a', 'a@example.com');
      await store.target('folder', 'Site');
      await store.enqueue(File('first.png'));
      await store.enqueue(File('second.png'));

      final claimed = (await store.claim())!;
      var jobs = await store.jobs();
      expect(
        jobs.where((job) => job.status == CloudJobStatus.uploading),
        hasLength(1),
      );
      expect(
        jobs.where((job) => job.status == CloudJobStatus.pending),
        hasLength(1),
      );

      final claimedId = claimed['id'] as int;
      await store.updateJob(claimedId, {
        'status': 'blocked',
        'lease': 0,
        'error': 'Login dibutuhkan',
      });
      jobs = await store.jobs();
      expect(jobs.first.status, CloudJobStatus.blocked);
      expect(jobs.first.error, 'Login dibutuhkan');

      await store.retryJob(claimedId);
      final retried = (await store.jobs()).firstWhere(
        (job) => job.id == claimedId,
      );
      expect(retried.status, CloudJobStatus.pending);
      expect(retried.error, isNull);
    },
  );

  test('Version 1 queue migrates without deleting existing jobs', () async {
    final migrationDirectory = await Directory.systemTemp.createTemp(
      'swift_queue_migration_',
    );
    final migrationPath = '${migrationDirectory.path}/queue.db';
    var migrationDb = await databaseFactoryFfi.openDatabase(
      migrationPath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (database, _) async {
          await database.execute(
            'CREATE TABLE config (id INTEGER PRIMARY KEY CHECK(id=1), accountId TEXT, email TEXT, folderId TEXT, folderName TEXT, enabled INTEGER NOT NULL DEFAULT 0, enabledAt INTEGER NOT NULL DEFAULT 0)',
          );
          await database.insert('config', {
            'id': 1,
            'accountId': 'a',
            'email': 'a@example.com',
            'folderId': 'folder',
            'enabled': 1,
          });
          await database.execute(
            "CREATE TABLE jobs (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL, accountId TEXT NOT NULL, email TEXT NOT NULL, folderId TEXT NOT NULL, remoteId TEXT, status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0, lease INTEGER NOT NULL DEFAULT 0, error TEXT, UNIQUE(path, accountId, folderId))",
          );
          await database.insert('jobs', {
            'path': 'legacy.png',
            'accountId': 'a',
            'email': 'a@example.com',
            'folderId': 'folder',
          });
        },
      ),
    );
    await migrationDb.close();
    migrationDb = await databaseFactoryFfi.openDatabase(
      migrationPath,
      options: OpenDatabaseOptions(
        version: 2,
        singleInstance: false,
        onUpgrade: CloudStore.upgradeSchema,
      ),
    );
    final migrated = CloudStore(database: migrationDb);
    final jobs = await migrated.jobs();
    expect(jobs.single.fileName, 'legacy.png');
    expect(jobs.single.createdAt, greaterThan(0));
    await migrationDb.close();
    await migrationDirectory.delete(recursive: true);
  });

  test(
    'Offline retries preserve the remote ID and mark success only after upload confirmation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'swift_drive_queue_',
      );
      addTearDown(() async {
        final expected =
            '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}swift_drive_';
        if (!directory.absolute.path.startsWith(expected)) {
          throw StateError('Unexpected temporary directory');
        }
        await directory.delete(recursive: true);
      });
      final file = await File(
        '${directory.path}/photo.png',
      ).writeAsBytes([1, 2]);
      await store.connect('a', 'a@example.com');
      await store.target('folder', 'Site');
      await store.enqueue(file);
      final state = _UploadState();
      final service = CloudSyncService(
        store: store,
        apiFactory: (_) => _FakeDrive(state),
      );
      expect(await service.drain(), isFalse);
      expect((await store.summary()).pending, 1);
      expect((await store.summary()).synced, 0);
      state.offline = false;
      expect(await service.drain(), isTrue);
      expect(state.generated, 1);
      expect(state.ids, ['remote-1', 'remote-1']);
      expect((await store.summary()).synced, 1);
      expect((await store.summary()).pending, 0);
    },
  );
}
