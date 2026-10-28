import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import '../models/media_file_names.dart';
import 'package:path_provider/path_provider.dart';
import 'cloud_sync_service.dart';

class LocalMediaService {
  LocalMediaService({this._documentsProvider});
  final Future<Directory> Function()? _documentsProvider;
  Future<Directory> _documents() =>
      _documentsProvider?.call() ?? getApplicationDocumentsDirectory();
  Future<List<File>> listPhotos() async {
    final root = await _documents();
    final directory = Directory('${root.path}/SwiftPhoto');
    if (!await directory.exists()) return [];
    final photos = await directory
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.png'))
        .cast<File>()
        .toList();
    final dated = await Future.wait(
      photos.map(
        (file) async => (file: file, modified: (await file.stat()).modified),
      ),
    );
    dated.sort((a, b) => b.modified.compareTo(a.modified));
    return dated.map((entry) => entry.file).toList();
  }

  Future<File> saveInternal(Uint8List bytes, {File? editedFrom}) async {
    final root = await _documents();
    final directory = await Directory(
      '${root.path}/SwiftPhoto',
    ).create(recursive: true);
    var name = 'swift_${DateTime.now().microsecondsSinceEpoch}.png';
    if (editedFrom != null) {
      final candidates = MediaFileNames.editedCandidates(
        editedFrom.uri.pathSegments.last,
      );
      String? available;
      for (final candidate in candidates) {
        if (!await File('${directory.path}/$candidate').exists() &&
            !await File('${directory.path}/$candidate.part').exists()) {
          available = candidate;
          break;
        }
      }
      if (available == null) {
        throw StateError(
          'Semua 36 nama salinan sudah digunakan untuk foto ini',
        );
      }
      name = available;
    }
    final temporary = File('${directory.path}/$name.part');
    await temporary.writeAsBytes(bytes, flush: true);
    final saved = await temporary.rename('${directory.path}/$name');
    if (_documentsProvider == null) {
      // Local commit is independent of network/account availability.
      try {
        final sync = CloudSyncService();
        await sync.store.enqueue(saved);
        unawaited(sync.schedule().catchError((Object _) {}));
      } catch (_) {
        // Startup recovery scans photos newer than the enabled timestamp.
      }
    }
    return saved;
  }

  Future<void> saveToGallery(File file) async {
    if (!await Gal.hasAccess()) {
      final allowed = await Gal.requestAccess();
      if (!allowed) throw StateError('Izin galeri tidak diberikan');
    }
    await Gal.putImage(file.path);
  }
}
