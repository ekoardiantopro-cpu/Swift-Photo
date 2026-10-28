import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class DriveApiException implements Exception {
  const DriveApiException(this.status, this.message);
  final int status;
  final String message;
  bool get retryable =>
      status == 408 ||
      status == 429 ||
      status >= 500 ||
      message.contains('rateLimitExceeded') ||
      message.contains('userRateLimitExceeded');
  @override
  String toString() => switch (status) {
    401 => 'Izin Google berakhir. Hubungkan kembali akun.',
    403 when message.contains('storageQuotaExceeded') =>
      'Penyimpanan Google Drive penuh.',
    403
        when message.contains('accessNotConfigured') ||
            message.contains('SERVICE_DISABLED') =>
      'Aktifkan Google Drive API pada proyek Google Cloud.',
    403 => 'Izin Drive ditolak. Periksa izin akun dan folder tujuan.',
    404 => 'Folder/file Drive tidak ditemukan. Pilih ulang folder tujuan.',
    _ => 'Google Drive belum dapat dihubungi (HTTP $status).',
  };
}

class DriveFolder {
  const DriveFolder(this.id, this.name);
  final String id;
  final String name;
}

class DriveApi {
  DriveApi({required this.token, required this.invalidate, http.Client? client})
    : _client = client ?? http.Client();
  final Future<String> Function() token;
  final Future<void> Function(String) invalidate;
  final http.Client _client;
  void close() => _client.close();

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Object? body,
    Map<String, String> headers = const {},
  }) async {
    for (var attempt = 0; ; attempt++) {
      final bearer = await token();
      final request = http.Request(method, uri)
        ..headers.addAll({...headers, 'Authorization': 'Bearer $bearer'});
      if (body is Uint8List) {
        request.bodyBytes = body;
      } else if (body != null) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      }
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 90)),
      ).timeout(const Duration(seconds: 90));
      if (response.statusCode == 401 && attempt == 0) {
        await invalidate(bearer);
        continue;
      }
      if (response.statusCode >= 400) {
        throw DriveApiException(response.statusCode, response.body);
      }
      return response;
    }
  }

  Future<List<DriveFolder>> folders(String parent) async {
    final folders = <DriveFolder>[];
    String? page;
    do {
      final response = await _request(
        'GET',
        Uri.https('www.googleapis.com', '/drive/v3/files', {
          'q':
              "'${parent.replaceAll("'", "\\'")}' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
          'fields': 'nextPageToken,files(id,name)',
          'pageSize': '100',
          'orderBy': 'name',
          'pageToken': ?page,
        }),
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      folders.addAll(
        (json['files'] as List? ?? const []).map(
          (v) => DriveFolder(v['id'] as String, v['name'] as String),
        ),
      );
      page = json['nextPageToken'] as String?;
    } while (page != null);
    return folders;
  }

  Future<DriveFolder> createFolder(String parent, String name) async {
    final response = await _request(
      'POST',
      Uri.https('www.googleapis.com', '/drive/v3/files', {'fields': 'id,name'}),
      body: {
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': [parent],
      },
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return DriveFolder(json['id'] as String, json['name'] as String);
  }

  Future<String> generateId() async {
    final response = await _request(
      'GET',
      Uri.https('www.googleapis.com', '/drive/v3/files/generateIds', {
        'count': '1',
        'space': 'drive',
        'type': 'files',
      }),
    );
    return ((jsonDecode(response.body) as Map<String, dynamic>)['ids'] as List)
            .single
        as String;
  }

  Future<bool> isUploaded(String id, int size) async {
    try {
      final response = await _request(
        'GET',
        Uri.https('www.googleapis.com', '/drive/v3/files/$id', {
          'fields': 'id,size,trashed',
        }),
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['trashed'] != true && json['size'] == '$size';
    } on DriveApiException catch (e) {
      if (e.status == 404) return false;
      rethrow;
    }
  }

  /// The caller persists the pre-generated file ID before starting. A committed
  /// upload can therefore be recognized after a lost response/process restart.
  Future<void> upload(
    File file,
    String folderId,
    String remoteId, {
    required Future<bool> Function() shouldContinue,
  }) async {
    final size = await file.length();
    if (await isUploaded(remoteId, size)) return;
    final response = await _request(
      'POST',
      Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
        'uploadType': 'resumable',
        'fields': 'id',
      }),
      headers: {
        'X-Upload-Content-Type': 'image/png',
        'X-Upload-Content-Length': '$size',
      },
      body: {
        'id': remoteId,
        'name': file.uri.pathSegments.last,
        'parents': [folderId],
        'mimeType': 'image/png',
      },
    );
    final location = response.headers['location'];
    if (location == null) {
      throw const FormatException('Drive upload session missing');
    }
    final uri = Uri.parse(location);
    if (uri.scheme != 'https' || uri.host != 'www.googleapis.com') {
      throw const FormatException('Invalid Drive upload session');
    }
    final input = await file.open();
    try {
      var offset = 0;
      while (offset < size) {
        if (!await shouldContinue()) throw const UploadPaused();
        final end = min(offset + 1024 * 1024, size);
        final bytes = await input.read(end - offset);
        if (bytes.length != end - offset) {
          throw const FileSystemException('Foto lokal berubah saat diunggah');
        }
        final part = await _request(
          'PUT',
          uri,
          body: bytes,
          headers: {
            'Content-Type': 'image/png',
            'Content-Range': 'bytes $offset-${end - 1}/$size',
          },
        );
        if (end == size) {
          if (part.statusCode != 200 && part.statusCode != 201) {
            throw const FormatException('Drive did not confirm upload');
          }
        } else if (part.statusCode != 308) {
          throw const FormatException('Drive upload interrupted');
        } else if (part.headers['range'] != 'bytes=0-${end - 1}') {
          // Do not advance past bytes that the server has not acknowledged.
          // A retry starts a new session using the same persisted file ID.
          throw const FormatException(
            'Drive did not acknowledge the full chunk',
          );
        }
        offset = end;
      }
    } finally {
      await input.close();
    }
  }
}

class UploadPaused implements Exception {
  const UploadPaused();
}
