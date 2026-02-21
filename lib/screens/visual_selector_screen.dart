import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';

import 'package:webview_windows/webview_windows.dart' as win_web;

class VisualSelectorScreen extends StatefulWidget {
  final String url;
  const VisualSelectorScreen({Key? key, required this.url}) : super(key: key);

  @override
  State<VisualSelectorScreen> createState() => _VisualSelectorScreenState();
}

class _VisualSelectorScreenState extends State<VisualSelectorScreen> {
  late final WebViewController _controller;
  final _windowsController = win_web.WebviewController();
  bool _isLoading = true;
  String _currentSelector = '';
  bool _isWindowsInitError = false;
  bool _isSelectionMode = false;

  final String _selectionScript = '''
    window.NotifyMeSelectionEnabled = true;
    (function() {
      var prevStyle = null;
      var prevElement = null;

      function getCssSelector(el) {
        if (!(el instanceof Element)) return;
        var path = [];
        while (el.nodeType === Node.ELEMENT_NODE) {
          var selector = el.nodeName.toLowerCase();
          if (el.id) {
            selector += '#' + el.id;
            path.unshift(selector);
            break;
          } else {
            var sib = el, nth = 1;
            while (sib = sib.previousElementSibling) {
              if (sib.nodeName.toLowerCase() == selector)
                nth++;
            }
            if (nth != 1)
              selector += ":nth-of-type("+nth+")";
          }
          path.unshift(selector);
          el = el.parentNode;
        }
        return path.join(" > ");
      }

      document.body.addEventListener('mousemove', function(e) {
        if (!window.NotifyMeSelectionEnabled) return;
        if (prevElement) {
          prevElement.style.outline = prevStyle;
          prevElement.style.backgroundColor = '';
        }
        var el = e.target;
        prevStyle = el.style.outline;
        prevElement = el;
        el.style.outline = '3px solid #00F4B1';
        el.style.backgroundColor = 'rgba(0, 244, 177, 0.2)';
      });

      document.body.addEventListener('click', function(e) {
        if (!window.NotifyMeSelectionEnabled) return;
        e.preventDefault();
        e.stopPropagation();
        if (prevElement) {
          prevElement.style.outline = prevStyle;
          prevElement.style.backgroundColor = '';
          prevElement = null;
          prevStyle = null;
        }
        var selector = getCssSelector(e.target);
        SelectorChannel.postMessage(selector);
      }, true);
    })();
  ''';

  bool _isWebViewSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    String targetUrl =
        widget.url.startsWith('http') ? widget.url : 'https://${widget.url}';

    if (_isWindows) {
      _initWindowsWebview(targetUrl);
    } else if (_isWebViewSupported) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'SelectorChannel',
          onMessageReceived: (message) {
            setState(() {
              _currentSelector = message.message;
            });
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (mounted) {
                setState(() => _isLoading = false);
                _controller.runJavaScript(_selectionScript);
                _updateSelectionMode(_isSelectionMode);
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(targetUrl));
    } else {
      _isLoading = false;
    }
  }

  Future<void> _initWindowsWebview(String targetUrl) async {
    try {
      await _windowsController.initialize();
      _windowsController.url.listen((url) {});

      await _windowsController.loadUrl(targetUrl);

      _windowsController.loadingState.listen((event) {
        if (event == win_web.LoadingState.navigationCompleted) {
          if (mounted) setState(() => _isLoading = false);
          _windowsController.executeScript(_selectionScript);
          _updateSelectionMode(_isSelectionMode);
        }
      });

      _windowsController.webMessage.listen((event) {
        setState(() {
          _currentSelector = event['message'] ?? '';
        });
      });

      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _isWindowsInitError = true);
    }
  }

  @override
  void dispose() {
    if (_isWindows) {
      _windowsController.dispose();
    }
    super.dispose();
  }

  void _confirmSelection() {
    Navigator.pop(context, _currentSelector);
  }

  void _updateSelectionMode(bool enable) {
    String stateStr = enable ? 'true' : 'false';
    String script = "window.NotifyMeSelectionEnabled = $stateStr;";
    if (_isWindows) {
      if (_windowsController.value.isInitialized) {
        _windowsController.executeScript(script);
      }
    } else {
      _controller.runJavaScript(script);
    }
  }

  void _toggleMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _updateSelectionMode(_isSelectionMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Selector', style: TextStyle(fontSize: 16)),
        actions: [
          if (_currentSelector.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check, color: AppTheme.primaryColor),
              label: const Text(
                'Simpan',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_currentSelector.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              child: Row(
                children: [
                  const Text(
                    'Terpilih: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _currentSelector,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: !_isWebViewSupported || _isWindowsInitError
                ? Container(
                    color:
                        isDark ? const Color(0xFF161D1A) : Colors.grey.shade100,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.web_asset_off,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            !_isWebViewSupported
                                ? 'Visual Selector tidak didukung di Platform ini.\nSilakan masukkan CSS Selector secara manual.'
                                : 'Terjadi kesalahan memuat WebView Desktop.\nSilakan masukkan CSS Selector secara manual.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Kembali'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: const BorderSide(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      (_isWindows && !kIsWeb)
                          ? (_windowsController.value.isInitialized
                              ? win_web.Webview(_windowsController)
                              : const SizedBox())
                          : WebViewWidget(controller: _controller),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      if (!_isLoading &&
                          _currentSelector.isEmpty &&
                          _isSelectionMode)
                        Positioned(
                          bottom: 24,
                          left: 24,
                          right: 24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 8),
                              ],
                            ),
                            child: const Text(
                              'Tap elemen di halaman web untuk memantau bagian tersebut.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleMode,
        backgroundColor:
            _isSelectionMode ? Colors.redAccent : AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: Icon(_isSelectionMode ? Icons.close : Icons.ads_click),
        label: Text(
          _isSelectionMode ? 'Batalkan Seleksi' : 'Pilih Elemen',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
