import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'cloud_store.dart';
import 'drive_api.dart';
import 'google_drive_auth.dart';

const _periodicTask = 'com.swiftphoto.swift_photo.drive_sync';
const _oneOffTask = 'swift-photo-drive-now';

@pragma('vm:entry-point')
void cloudSyncDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      return await CloudSyncService().drain();
    } catch (_) {
      return false;
    }
  });
}

class CloudSyncService {
  CloudSyncService({CloudStore? store, GoogleDriveAuth? auth, this._apiFactory})
    : store = store ?? CloudStore(),
      auth = auth ?? GoogleDriveAuth();
  final CloudStore store;
  final GoogleDriveAuth auth;
  final DriveApi Function(CloudConfig)? _apiFactory;
  static Future<void>? _initialization;
  static const _tag = 'swift-photo-drive';

  Future<void> initialize() =>
      _initialization ??= Workmanager().initialize(cloudSyncDispatcher);

  DriveApi api(CloudConfig c) =>
      _apiFactory?.call(c) ??
      DriveApi(
        token: () => auth.token(c.accountId!, c.email!),
        invalidate: auth.invalidate,
      );

  Future<void> schedule() async {
    await initialize();
    if (!(await store.config()).enabled) return;
    await Workmanager().registerOneOffTask(
      _oneOffTask,
      _periodicTask,
      tag: _tag,
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
    await Workmanager().registerPeriodicTask(
      _periodicTask,
      _periodicTask,
      tag: _tag,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  Future<void> pause() async {
    await store.setEnabled(false);
    await initialize();
    await Workmanager().cancelByTag(_tag);
  }

  /// Called after the local file is committed; never waits for network/OAuth.
  Future<void> onPhotoSaved(File file) async {
    await store.enqueue(file);
    await schedule();
  }

  /// Repair the small crash window between local save and queue insertion.
  /// Older local photos are only queued by the explicit "Sync foto lokal" action.
  Future<void> recover({bool includeOlderPhotos = false}) async {
    final c = await store.config();
    if (!c.enabled || !c.connected || c.folderId == null) return;
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/SwiftPhoto');
    if (await directory.exists()) {
      await for (final entry in directory.list()) {
        if (entry is File &&
            entry.path.endsWith('.png') &&
            (includeOlderPhotos ||
                (await entry.lastModified()).millisecondsSinceEpoch >=
                    c.enabledAt)) {
          await store.enqueue(entry);
        }
      }
    }
    await schedule();
  }

  /// One worker per job, claimed transactionally across UI/background isolates.
  /// IDs are persisted before upload to avoid duplicate files on retry.
  Future<bool> drain() async {
    final started = DateTime.now();
    while (DateTime.now().difference(started) < const Duration(minutes: 4)) {
      final job = await store.claim();
      if (job == null) return true;
      final id = job['id'] as int;
      final c = CloudConfig(
        accountId: job['accountId'] as String,
        email: job['email'] as String,
      );
      final client = api(c);
      try {
        final file = File(job['path'] as String);
        if (!await file.exists()) {
          await store.updateJob(id, {
            'status': 'blocked',
            'error': 'Foto lokal tidak ditemukan.',
          });
          continue;
        }
        final remoteId =
            job['remoteId'] as String? ?? await client.generateId();
        await store.updateJob(id, {'remoteId': remoteId});
        await client.upload(
          file,
          job['folderId'] as String,
          remoteId,
          shouldContinue: () async {
            final latest = await store.config();
            if (!latest.enabled || latest.accountId != c.accountId) {
              return false;
            }
            await store.updateJob(id, {
              'lease': DateTime.now().millisecondsSinceEpoch + 600000,
            });
            return true;
          },
        );
        await store.updateJob(id, {
          'status': 'synced',
          'error': null,
          'lease': 0,
        });
      } on UploadPaused {
        await store.updateJob(id, {'status': 'pending', 'lease': 0});
        return true;
      } on DriveSignInRequired {
        await store.updateJob(id, {
          'status': 'blocked',
          'lease': 0,
          'error': 'Hubungkan kembali akun Google.',
        });
        return true;
      } on GoogleSignInException {
        await store.updateJob(id, {
          'status': 'pending',
          'lease': 0,
          'error':
              'Sesi Google belum tersedia. Buka Sync dan hubungkan kembali jika diperlukan.',
        });
        return false;
      } on DriveApiException catch (e) {
        await store.updateJob(id, {
          'status': e.retryable ? 'pending' : 'blocked',
          'lease': 0,
          'error': e.toString(),
        });
        if (e.retryable) return false;
      } catch (_) {
        await store.updateJob(id, {
          'status': 'pending',
          'lease': 0,
          'error': 'Unggah tertunda. Akan dicoba lagi saat koneksi tersedia.',
        });
        return false;
      } finally {
        client.close();
      }
    }
    return false;
  }

  static void resumeSafely() {
    unawaited(
      CloudSyncService().recover().catchError((Object error) {
        debugPrint('Cloud queue will be checked again on the next launch.');
      }),
    );
  }
}
