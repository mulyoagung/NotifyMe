// Stub for Android/iOS/native desktop — all methods are no-ops
class TauriService {
  static Future<void> openUrlExternal(String url) async {}
  static Future<void> openWebviewWindow(String url, String title) async {}
  static Future<void> openSelectorWindow(String url) async {}
  static Future<String?> readClipboard() async => null;
}
