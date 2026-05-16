Uri? _capturedLaunchUri;

void captureInitialLaunchUri() {
  _capturedLaunchUri ??= Uri.base;
}

Uri resolveCapturedLaunchUri() {
  return _capturedLaunchUri ?? Uri.base;
}

void clearCapturedLaunchUri() {
  _capturedLaunchUri = null;
}
