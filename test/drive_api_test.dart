import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swift_photo/services/drive_api.dart';

void main() {
  test(
    'Drive folder browser follows pagination and refreshes a rejected token once',
    () async {
      var tokens = 0, invalidations = 0, requests = 0;
      final api = DriveApi(
        token: () async => 'token-${tokens++}',
        invalidate: (_) async {
          invalidations++;
        },
        client: MockClient((request) async {
          requests++;
          if (requests == 1) return http.Response('{}', 401);
          expect(request.headers['Authorization'], startsWith('Bearer token-'));
          expect(
            request.url.queryParameters['q'],
            contains("'root' in parents"),
          );
          if (request.url.queryParameters['pageToken'] == null) {
            return http.Response(
              jsonEncode({
                'nextPageToken': 'page2',
                'files': [
                  {'id': 'one', 'name': 'Folder A'},
                ],
              }),
              200,
            );
          }
          expect(request.url.queryParameters['pageToken'], 'page2');
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'two', 'name': 'Folder B'},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      expect((await api.folders('root')).map((f) => f.id), ['one', 'two']);
      expect(invalidations, 1);
      expect(requests, 3);
    },
  );

  test('PNG upload streams in aligned chunks using the preallocated ID', () async {
    final directory = await Directory.systemTemp.createTemp(
      'swift_drive_upload_',
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
    ).writeAsBytes(Uint8List(1024 * 1024 + 18));
    var chunks = 0, checks = 0;
    final api = DriveApi(
      token: () async => 'access',
      invalidate: (_) async {},
      client: MockClient((request) async {
        if (request.method == 'GET') return http.Response('{}', 404);
        if (request.method == 'POST') {
          final metadata = jsonDecode(request.body) as Map<String, dynamic>;
          expect(metadata['id'], 'reserved-id');
          expect(metadata['parents'], ['target']);
          expect(metadata['name'], 'photo.png');
          return http.Response(
            '',
            200,
            headers: {
              'location':
                  'https://www.googleapis.com/upload/drive/v3/files?upload_id=session',
            },
          );
        }
        chunks++;
        expect(request.method, 'PUT');
        expect(request.bodyBytes.length, chunks == 1 ? 1024 * 1024 : 18);
        expect(
          request.headers['Content-Range'],
          chunks == 1
              ? 'bytes 0-1048575/1048594'
              : 'bytes 1048576-1048593/1048594',
        );
        return http.Response(
          chunks == 1 ? '' : '{"id":"reserved-id"}',
          chunks == 1 ? 308 : 200,
          headers: chunks == 1 ? {'range': 'bytes=0-1048575'} : {},
        );
      }),
    );
    addTearDown(api.close);
    await api.upload(
      file,
      'target',
      'reserved-id',
      shouldContinue: () async {
        checks++;
        return true;
      },
    );
    expect(chunks, 2);
    expect(checks, 2);
  });

  test(
    'A completed upload is detected after losing its response, without a duplicate',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'swift_drive_committed_',
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
      ).writeAsBytes([1, 2, 3]);
      var requests = 0;
      final api = DriveApi(
        token: () async => 'access',
        invalidate: (_) async {},
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'GET');
          return http.Response(
            '{"id":"reserved-id","size":"3","trashed":false}',
            200,
          );
        }),
      );
      addTearDown(api.close);
      await api.upload(
        file,
        'target',
        'reserved-id',
        shouldContinue: () async => true,
      );
      expect(requests, 1);
    },
  );

  test('An upload pauses before sending file data when Sync is disabled', () async {
    final directory = await Directory.systemTemp.createTemp(
      'swift_drive_pause_',
    );
    addTearDown(() async {
      final expected =
          '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}swift_drive_';
      if (!directory.absolute.path.startsWith(expected)) {
        throw StateError('Unexpected temporary directory');
      }
      await directory.delete(recursive: true);
    });
    final file = await File('${directory.path}/photo.png').writeAsBytes([1]);
    final api = DriveApi(
      token: () async => 'access',
      invalidate: (_) async {},
      client: MockClient((request) async {
        expect(request.method, isNot('PUT'));
        if (request.method == 'GET') return http.Response('{}', 404);
        return http.Response(
          '',
          200,
          headers: {
            'location':
                'https://www.googleapis.com/upload/drive/v3/files?upload_id=session',
          },
        );
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.upload(file, 'target', 'id', shouldContinue: () async => false),
      throwsA(isA<UploadPaused>()),
    );
  });
}
