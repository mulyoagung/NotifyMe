import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/monitored_link.dart';

class ScraperService {
  static Future<String?> fetchAndExtract(MonitoredLink link) async {
    // Basic fallback for non-supported platforms
    if (kIsWeb) return null;

    final completer = Completer<String?>();
    HeadlessInAppWebView? headlessWebView;

    try {
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(link.url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          loadsImagesAutomatically: false,
          mediaPlaybackRequiresUserGesture: true,
          disableDefaultErrorPage: true,
          useShouldInterceptRequest: true,
          // Keep cookies (session) alive – do NOT clear cache + cookies together
          cacheEnabled: false,
          clearCache:
              false, // IMPORTANT: false = cookies are preserved between sessions
          disableContextMenu: true,
          preferredContentMode: UserPreferredContentMode.MOBILE,
          useOnNavigationResponse: true,
        ),
        shouldInterceptRequest: (controller, request) async {
          // Block known heavy static resources locally to maximize battery and bandwidth saving
          final urlStr = request.url.toString().toLowerCase();
          if (urlStr.endsWith('.css') ||
              urlStr.endsWith('.woff') ||
              urlStr.endsWith('.woff2') ||
              urlStr.endsWith('.ttf') ||
              urlStr.endsWith('.mp4') ||
              urlStr.endsWith('.svg') ||
              urlStr.contains('google-analytics.com') ||
              urlStr.contains('googletagmanager.com') ||
              urlStr.contains('doubleclick.net')) {
            return WebResourceResponse(
              contentType: "text/plain",
              data: Uint8List.fromList([]),
              statusCode:
                  404, // Simulate dropped heavy resources to keep it fast
            );
          }
          return null; // Proceed normal loading for DOM/JS
        },
        onLoadStop: (controller, url) async {
          try {
            String extractedText = '';

            if (link.cssSelector.isNotEmpty) {
              // Step 1: Run pre-navigation JS (if user configured it)
              // This allows clicking a menu item or navigating to hidden content
              if (link.preNavigationScript.isNotEmpty) {
                await controller.evaluateJavascript(
                    source: link.preNavigationScript);
                // Allow time for navigation/click to settle
                await Future.delayed(const Duration(milliseconds: 800));
              }

              final jsResult = await controller.evaluateJavascript(source: '''
                function checkDOM() {
                  return new Promise((resolve) => {
                    let attempts = 0;
                    const interval = setInterval(() => {
                      var nodes = document.querySelectorAll("${link.cssSelector.replaceAll('"', '\\"')}");
                      
                      // Wait until we have some valid innerText content length from the nodes
                      var hasContent = false;
                      for (var i = 0; i < nodes.length; i++) {
                         if (nodes[i].innerText && nodes[i].innerText.trim().length > 0) hasContent = true;
                      }
                      
                      attempts++;
                      // Stop waiting if we found content, or if we tried 15 times (approx 3 seconds)
                      if (hasContent || attempts > 15) {
                        clearInterval(interval);
                        
                        var items = [];
                        for (var i = 0; i < nodes.length; i++) {
                          if (nodes[i].innerText) {
                            var lines = nodes[i].innerText.split('\\n');
                            for (var j = 0; j < lines.length; j++) {
                              var val = lines[j].trim();
                              if (val.length > 0) items.push(val);
                            }
                          }
                        }
                        
                        resolve(JSON.stringify(items));
                      }
                    }, 200); // Check every 200ms
                  });
                }
                
                checkDOM();
              ''');

              extractedText = jsResult?.toString().trim() ?? '[]';
            } else {
              // Fallback: smart poll body text (no fixed delay)
              final jsResult = await controller.evaluateJavascript(source: '''
                function checkBody() {
                  return new Promise((resolve) => {
                    let attempts = 0;
                    const interval = setInterval(() => {
                      attempts++;
                      var body = document.body;
                      if ((body && body.innerText && body.innerText.trim().length > 0) || attempts > 15) {
                        clearInterval(interval);
                        var lines = body ? body.innerText.split('\\n') : [];
                        var items = [];
                        for (var i = 0; i < lines.length; i++) {
                          var val = lines[i].trim();
                          if (val.length > 0) items.push(val);
                        }
                        resolve(JSON.stringify(items));
                      }
                    }, 200);
                  });
                }
                checkBody();
              ''');
              extractedText = jsResult?.toString().trim() ?? '[]';
            }

            // Avoid replacing all whitespace inside json string carelessly
            // We just store the json directly.
            if (extractedText.isNotEmpty && extractedText != '[]') {
              if (!completer.isCompleted) completer.complete(extractedText);
            } else {
              if (!completer.isCompleted) completer.complete(null);
            }
          } catch (e) {
            print('Error evaluating JS: \$e');
            if (!completer.isCompleted) completer.complete(null);
          }
        },
        onLoadError: (controller, url, code, message) {
          print('Error loading \${link.url}: \$message');
          if (!completer.isCompleted) completer.complete(null);
        },
        onLoadHttpError: (controller, url, statusCode, description) {
          print('HTTP Error loading \${link.url}: \$statusCode');
          if (!completer.isCompleted) completer.complete(null);
        },
      );

      await headlessWebView.run(); // Start headless browser

      // Force timeout after 25 seconds to guarantee no battery drain from hanging execution
      return await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          print('Headless Webview Timeout for \${link.url}');
          return null;
        },
      );
    } catch (e) {
      print('Exception in fetchAndExtract: \$e');
      return null;
    } finally {
      // ALWAYS dispose immediately to prevent memory leaks and battery drain
      await headlessWebView?.dispose();
    }
  }
}
