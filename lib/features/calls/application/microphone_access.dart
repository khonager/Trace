/// Permission prompts can outlive the call or foreground session that opened
/// them. Recheck ownership after capture starts and release any stale stream.
Future<T> openCallMicrophone<T>({
  required bool Function() allowed,
  required Future<T> Function() open,
  required Future<void> Function(T) release,
}) async {
  if (!allowed()) throw StateError('Call is no longer active.');
  final stream = await open();
  if (!allowed()) {
    await release(stream);
    throw StateError('Call was canceled while opening the microphone.');
  }
  return stream;
}
