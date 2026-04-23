import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/monitored_link.dart';

/// A single child element represented as a fingerprint.
/// [key]  = unique identity: first 200 chars of innerText, stable across index shifts.
/// [html] = full outerHTML for accurate diffing and display.
class ElementSnapshot {
  final String key;
  final String html;
  ElementSnapshot({required this.key, required this.html});

  Map<String, dynamic> toMap() => {'key': key, 'html': html};

  factory ElementSnapshot.fromMap(Map<String, dynamic> m) =>
      ElementSnapshot(key: m['key'] as String, html: m['html'] as String);
}

/// Encode/decode a List<ElementSnapshot> to/from a JSON string for DB storage.
String encodeSnapshots(List<ElementSnapshot> items) =>
    jsonEncode(items.map((e) => e.toMap()).toList());

List<ElementSnapshot> decodeSnapshots(String raw) {
  try {
    final List<dynamic> list = jsonDecode(raw);
    return list
        .map((e) => ElementSnapshot.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return [];
  }
}

/// Returns only items whose key is NOT present in [oldKeys].
List<ElementSnapshot> diffSnapshots(
    List<ElementSnapshot> oldList, List<ElementSnapshot> newList) {
  final oldKeys = oldList.map((e) => e.key).toSet();
  return newList.where((e) => !oldKeys.contains(e.key)).toList();
}

class ScraperService {
  static Future<String?> fetchAndExtract(MonitoredLink link) async {
    if (kIsWeb) return null;

    final completer = Completer<String?>();
    HeadlessInAppWebView? headlessWebView;

    // The JavaScript that extracts direct children as HTML fingerprints.
    // Uses outerHTML as the source of truth – immune to index shifts.
    final String selector =
        link.cssSelector.replaceAll('"', '\\"').replaceAll("'", "\\'");

    final String extractionJS = '''
      (function extractChildren() {
        return new Promise(function(resolve) {
          var attempts = 0;

          var interval = setInterval(function() {
            attempts++;

            var root = null;
            try {
              root = document.querySelector("$selector");
            } catch(e) {}

            var hasContent = root && root.innerText && root.innerText.trim().length > 0;

            if (hasContent || attempts > 20) {
              clearInterval(interval);

              if (!root) { resolve('[]'); return; }

              var children = Array.from(root.children);

              // If the container has no direct children, treat root itself as the item
              if (children.length === 0) children = [root];

              var results = [];
              for (var i = 0; i < children.length; i++) {
                var el = children[i];

                // Key = first 200 chars of trimmed text content (stable, position-independent)
                var text = (el.innerText || el.textContent || '').trim().replace(/\\s+/g, ' ');
                if (text.length === 0) continue;
                var key = text.substring(0, 200);

                // Capture outerHTML for display and accurate diffing (cap at 8KB per child)
                var html = el.outerHTML || '';
                if (html.length > 8192) html = html.substring(0, 8192) + '<!-- truncated -->';

                results.push({ key: key, html: html });
              }

              resolve(JSON.stringify(results));
            }
          }, 200);
        });
      })();
    ''';

    final String bodyFallbackJS = '''
      (function() {
        return new Promise(function(resolve) {
          var attempts = 0;
          var interval = setInterval(function() {
            attempts++;
            var body = document.body;
            var hasContent = body && body.innerText && body.innerText.trim().length > 50;
            if (hasContent || attempts > 20) {
              clearInterval(interval);
              if (!body) { resolve('[]'); return; }

              // For body fallback: split top-level children as items
              var children = Array.from(body.children);
              var results = [];
              for (var i = 0; i < children.length; i++) {
                var el = children[i];
                var text = (el.innerText || '').trim().replace(/\\s+/g, ' ');
                if (text.length === 0) continue;
                var key = text.substring(0, 200);
                var html = el.outerHTML || '';
                if (html.length > 8192) html = html.substring(0, 8192) + '<!-- truncated -->';
                results.push({ key: key, html: html });
              }
              resolve(JSON.stringify(results));
            }
          }, 200);
        });
      })();
    ''';

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(link.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          loadsImagesAutomatically: false,
          mediaPlaybackRequiresUserGesture: true,
          disableDefaultErrorPage: true,
          useShouldInterceptRequest: true,
          // Keep session cookies alive (false = do NOT wipe cookies)
          cacheEnabled: false,
          clearCache: false,
          disableContextMenu: true,
          preferredContentMode: UserPreferredContentMode.MOBILE,
          useOnNavigationResponse: true,
        ),
        shouldInterceptRequest: (controller, request) async {
          final urlStr = request.url.toString().toLowerCase();
          final blocked = urlStr.endsWith('.css') ||
              urlStr.endsWith('.woff') ||
              urlStr.endsWith('.woff2') ||
              urlStr.endsWith('.ttf') ||
              urlStr.endsWith('.mp4') ||
              urlStr.endsWith('.svg') ||
              urlStr.contains('google-analytics.com') ||
              urlStr.contains('googletagmanager.com') ||
              urlStr.contains('doubleclick.net');
          if (blocked) {
            return WebResourceResponse(
              contentType: 'text/plain',
              data: Uint8List.fromList([]),
              statusCode: 404,
            );
          }
          return null;
        },
        onLoadStop: (controller, url) async {
          try {
            // Step 1: Execute pre-navigation script (click menus, etc.)
            if (link.preNavigationScript.isNotEmpty) {
              await controller.evaluateJavascript(
                  source: link.preNavigationScript);
              await Future.delayed(const Duration(milliseconds: 1000));
            }

            // Step 2: Extract HTML fingerprints
            final String js =
                link.cssSelector.isNotEmpty ? extractionJS : bodyFallbackJS;

            final jsResult =
                await controller.evaluateJavascript(source: js);

            final String raw = jsResult?.toString().trim() ?? '[]';

            // Validate it's a non-empty JSON array
            if (raw.isNotEmpty && raw != '[]' && raw.startsWith('[')) {
              if (!completer.isCompleted) completer.complete(raw);
            } else {
              if (!completer.isCompleted) completer.complete(null);
            }
          } catch (e) {
            print('ScraperService JS error: $e');
            if (!completer.isCompleted) completer.complete(null);
          }
        },
        onLoadError: (controller, url, code, message) {
          print('ScraperService load error ${link.url}: $message');
          if (!completer.isCompleted) completer.complete(null);
        },
        onLoadHttpError: (controller, url, statusCode, description) {
          print('ScraperService HTTP $statusCode: ${link.url}');
          if (!completer.isCompleted) completer.complete(null);
        },
      );

      await headlessWebView.run();

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('ScraperService timeout: ${link.url}');
          return null;
        },
      );
    } catch (e) {
      print('ScraperService exception: $e');
      return null;
    } finally {
      await headlessWebView?.dispose();
    }
  }
}
