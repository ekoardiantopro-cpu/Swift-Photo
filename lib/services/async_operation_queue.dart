/// Serializes platform operations, including asynchronous cleanup.
class AsyncOperationQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> run(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    // A failed operation must not prevent the next cleanup/retry from running.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
