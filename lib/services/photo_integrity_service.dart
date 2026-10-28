import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/watermark_data.dart';

enum PhotoIntegrityState { verified, changed, missing, unreadable }

class PhotoIntegrityReport {
  const PhotoIntegrityReport({
    required this.state,
    this.photoSha256,
    this.integrityId,
    this.message,
  });

  final PhotoIntegrityState state;
  final String? photoSha256;
  final String? integrityId;
  final String? message;

  bool get verified => state == PhotoIntegrityState.verified;
}

/// Maintains a local SHA-256 record for a rendered photo, its clean source,
/// and edit metadata. This detects changes; it is not an independent
/// authenticity certificate or a remote timestamp authority.
class PhotoIntegrityService {
  static const manifestName = 'integrity.json';

  Future<String> hashFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<void> write({
    required File photo,
    required File source,
    required File metadata,
    required WatermarkData data,
    File? parentPhoto,
  }) async {
    final photoHash = await hashFile(photo);
    final sourceHash = await hashFile(source);
    final metadataHash = await hashFile(metadata);
    String? parentHash;
    if (parentPhoto != null && await parentPhoto.exists()) {
      parentHash = await hashFile(parentPhoto);
    }
    final manifest = <String, Object?>{
      'version': 1,
      'algorithm': 'SHA-256',
      'integrityId': _shortId(photoHash),
      'photoSha256': photoHash,
      'sourceSha256': sourceHash,
      'metadataSha256': metadataHash,
      'parentPhotoSha256': parentHash,
      'photoCode': data.photoCode,
      'captureMode': data.isManual ? 'manual' : 'live',
      'edited': data.isEdited,
      'capturedAt': data.capturedAt.toIso8601String(),
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
      'notice':
          'Local integrity record; not an independent authenticity certificate.',
    };
    final destination = File('${photo.path}.project/$manifestName');
    final temporary = File('${destination.path}.part');
    await temporary.writeAsString(jsonEncode(manifest), flush: true);
    await temporary.rename(destination.path);
  }

  Future<PhotoIntegrityReport> verify(File photo) async {
    final directory = '${photo.path}.project';
    final manifest = File('$directory/$manifestName');
    if (!await manifest.exists()) {
      return const PhotoIntegrityReport(
        state: PhotoIntegrityState.missing,
        message: 'Foto lama belum memiliki catatan integritas.',
      );
    }
    try {
      final value = jsonDecode(await manifest.readAsString());
      if (value is! Map<String, dynamic> || value['algorithm'] != 'SHA-256') {
        throw const FormatException('Unsupported integrity record');
      }
      final expectedPhoto = value['photoSha256'] as String?;
      final expectedSource = value['sourceSha256'] as String?;
      final expectedMetadata = value['metadataSha256'] as String?;
      if (expectedPhoto == null ||
          expectedSource == null ||
          expectedMetadata == null) {
        throw const FormatException('Incomplete integrity record');
      }
      final source = File('$directory/source.image');
      final metadata = File('$directory/data.json');
      if (!await photo.exists() ||
          !await source.exists() ||
          !await metadata.exists()) {
        return PhotoIntegrityReport(
          state: PhotoIntegrityState.changed,
          photoSha256: expectedPhoto,
          integrityId:
              value['integrityId'] as String? ?? _shortId(expectedPhoto),
          message: 'Foto, sumber, atau metadata proyek tidak lengkap.',
        );
      }
      final actualPhoto = await hashFile(photo);
      final actualSource = await hashFile(source);
      final actualMetadata = await hashFile(metadata);
      final matches =
          actualPhoto == expectedPhoto &&
          actualSource == expectedSource &&
          actualMetadata == expectedMetadata;
      return PhotoIntegrityReport(
        state: matches
            ? PhotoIntegrityState.verified
            : PhotoIntegrityState.changed,
        photoSha256: actualPhoto,
        integrityId: value['integrityId'] as String? ?? _shortId(expectedPhoto),
        message: matches
            ? 'Hash foto, sumber, dan metadata cocok.'
            : 'Foto atau data edit berubah setelah catatan dibuat.',
      );
    } catch (_) {
      return const PhotoIntegrityReport(
        state: PhotoIntegrityState.unreadable,
        message: 'Catatan integritas tidak dapat dibaca.',
      );
    }
  }

  static String _shortId(String hash) =>
      hash.substring(0, hash.length < 16 ? hash.length : 16).toUpperCase();
}
