// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/services.dart';

class TauriService {
  static String _esc(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n');

  static void _invoke(String cmd, Map<String, String> args) {
    try {
      final argsJson =
          args.entries.map((e) => '"${e.key}":"${_esc(e.value)}"').join(',');
      final script =
          'if(window.__TAURI__){window.__TAURI__.core.invoke("$cmd",{$argsJson}).catch(console.error);}';
      js.context.callMethod('eval', [script]);
    } catch (e) {
      // ignore errors silently — Tauri may not be initialized yet
    }
  }

  /// Open URL in the system default browser
  static Future<void> openUrlExternal(String url) async {
    _invoke('open_url_external', {'url': url});
  }

  /// Open URL in a new in-app Tauri window
  static Future<void> openWebviewWindow(String url, String title) async {
    _invoke('open_webview_window', {'url': url, 'title': title});
  }

  /// Open URL in Tauri window with element selector UI injected
  static Future<void> openSelectorWindow(String url) async {
    _invoke('open_selector_window', {'url': url});
  }

  /// Read text from clipboard
  static Future<String?> readClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      return data?.text;
    } catch (_) {
      return null;
    }
  }
}
