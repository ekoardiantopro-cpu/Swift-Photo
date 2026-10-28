import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_photo/services/async_operation_queue.dart';

void main() {
  test(
    'Camera cleanup completes before the next initialization begins',
    () async {
      final queue = AsyncOperationQueue();
      final finishInitialization = Completer<void>();
      final finishCleanup = Completer<void>();
      final events = <String>[];
      final initial = queue.run(() async {
        events.add('initialize');
        await finishInitialization.future;
      });
      final cleanup = queue.run(() async {
        events.add('dispose');
        await finishCleanup.future;
      });
      final resumed = queue.run(() async {
        events.add('resume');
      });
      await Future<void>.delayed(Duration.zero);
      expect(events, ['initialize']);
      finishInitialization.complete();
      await initial;
      await Future<void>.delayed(Duration.zero);
      expect(events, ['initialize', 'dispose']);
      finishCleanup.complete();
      await Future.wait([cleanup, resumed]);
      expect(events, ['initialize', 'dispose', 'resume']);
    },
  );

  test('A failed platform operation does not block cleanup or retry', () async {
    final queue = AsyncOperationQueue();
    final failed = queue.run(() async {
      throw StateError('Camera unavailable');
    });
    var cleaned = false;
    final cleanup = queue.run(() async {
      cleaned = true;
    });
    await expectLater(failed, throwsStateError);
    await cleanup;
    expect(cleaned, isTrue);
  });
}
