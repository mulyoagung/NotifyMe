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
  late final win_web.WebviewController _windowsController;
  bool _isLoading = true;
  String _currentSelector = '';
  String _currentUrl = '';
  bool _isWindowsInitError = false;
  bool _isSelectionMode = false;

  final String _selectionScript = '''
    window.NotifyMeSelectionEnabled = true;
    window.NotifyMeActiveElement = null;

    window.NotifyMeHighlight = function(el) {
      if (!el) return;
      if (window.NotifyMeActiveElement) {
        window.NotifyMeActiveElement.style.outline = window.NotifyMePrevStyle || '';
        window.NotifyMeActiveElement.style.backgroundColor = '';
      }
      window.NotifyMePrevStyle = el.style.outline;
      window.NotifyMeActiveElement = el;
      el.style.outline = '3px solid #00F4B1';
      el.style.backgroundColor = 'rgba(0, 244, 177, 0.2)';
      var selector = getCssSelector(el);
      SelectorChannel.postMessage(selector);
    };

    window.NotifyMeExpand = function() {
      if (window.NotifyMeActiveElement && window.NotifyMeActiveElement.parentElement && window.NotifyMeActiveElement.parentElement !== document.body) {
        window.NotifyMeHighlight(window.NotifyMeActiveElement.parentElement);
      }
    };

    window.NotifyMeShrink = function() {
      if (window.NotifyMeActiveElement && window.NotifyMeActiveElement.firstElementChild) {
        window.NotifyMeHighlight(window.NotifyMeActiveElement.firstElementChild);
      }
    };

    function getCssSelector(el) {
      if (!(el instanceof Element)) return '';
      var path = [];
      while (el.nodeType === Node.ELEMENT_NODE && el.tagName.toLowerCase() !== 'html') {
        var selector = el.nodeName.toLowerCase();
        if (el.id && /^[a-zA-Z0-9\\-_]+\$/.test(el.id)) {
          selector += '#' + el.id;
          path.unshift(selector);
          break;
        } else {
          var sib = el.previousElementSibling, nth = 1;
          while (sib) {
            nth++;
            sib = sib.previousElementSibling;
          }
          
          if (el.className && typeof el.className === 'string' && selector !== 'body' && selector !== 'html') {
             var classes = el.className.trim().split(/\\s+/);
             var validClass = classes.find(c => /^[a-zA-Z0-9\\-_]+\$/.test(c) && !c.includes('__') && !c.startsWith('inter_') && c.length < 30);
             if (validClass) {
               selector += '.' + validClass;
             }
          }
          
          if (nth != 1) selector += ":nth-child("+nth+")";
        }
        path.unshift(selector);
        el = el.parentNode;
      }
      return path.join(" > ");
    }

    document.body.addEventListener('mousemove', function(e) {
      if (!window.NotifyMeSelectionEnabled) return;
      if (window.NotifyMeHoverElement) {
        window.NotifyMeHoverElement.style.outline = window.NotifyMeHoverPrevStyle || '';
        window.NotifyMeHoverElement.style.backgroundColor = '';
      }
      var el = e.target;
      window.NotifyMeHoverPrevStyle = el.style.outline;
      window.NotifyMeHoverElement = el;
      el.style.outline = '2px dashed #00F4B1';
      el.style.backgroundColor = 'rgba(0, 244, 177, 0.1)';
    });

    document.body.addEventListener('click', function(e) {
      if (!window.NotifyMeSelectionEnabled) return;
      e.preventDefault();
      e.stopPropagation();
      if (window.NotifyMeHoverElement) {
        window.NotifyMeHoverElement.style.outline = window.NotifyMeHoverPrevStyle || '';
        window.NotifyMeHoverElement.style.backgroundColor = '';
        window.NotifyMeHoverElement = null;
      }
      window.NotifyMeHighlight(e.target);
    }, true);
  ''';

  bool _isWebViewSupported = kIsWeb ||
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
      _controller = WebViewController();
      if (!kIsWeb) {
        _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
        _controller.addJavaScriptChannel(
          'SelectorChannel',
          onMessageReceived: (message) {
            setState(() {
              _currentSelector = message.message;
            });
          },
        );
        _controller.setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _currentUrl = url;
                });
                if (!kIsWeb) {
                  _controller.runJavaScript(_selectionScript);
                  _updateSelectionMode(_isSelectionMode);
                }
              }
            },
          ),
        );
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _currentUrl = targetUrl;
            });
          }
        });
      }
      _controller.loadRequest(Uri.parse(targetUrl));
    } else {
      _isLoading = false;
    }
  }

  Future<void> _initWindowsWebview(String targetUrl) async {
    try {
      _windowsController = win_web.WebviewController();
      await _windowsController.initialize();
      _windowsController.url.listen((url) {
        if (mounted) setState(() => _currentUrl = url);
      });

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
    Navigator.pop(context, {
      'selector': _currentSelector,
      'url': _currentUrl.isNotEmpty ? _currentUrl : widget.url,
    });
  }

  void _updateSelectionMode(bool enable) {
    String stateStr = enable ? 'true' : 'false';
    String script = "window.NotifyMeSelectionEnabled = $stateStr;";
    if (_isWindows) {
      if (_windowsController.value.isInitialized) {
        _windowsController.executeScript(script);
      }
    } else {
      if (!kIsWeb) _controller.runJavaScript(script);
    }
  }

  void _toggleMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _updateSelectionMode(_isSelectionMode);
    });
  }

  void _expandSelection() {
    if (_isWindows) {
      _windowsController.executeScript('window.NotifyMeExpand()');
    } else {
      if (!kIsWeb) _controller.runJavaScript('window.NotifyMeExpand()');
    }
  }

  void _shrinkSelection() {
    if (_isWindows) {
      _windowsController.executeScript('window.NotifyMeShrink()');
    } else {
      if (!kIsWeb) _controller.runJavaScript('window.NotifyMeShrink()');
    }
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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: _expandSelection,
                        tooltip: 'Pilih Induk (Perluas)',
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: _shrinkSelection,
                        tooltip: 'Pilih Anak (Persempit)',
                      ),
                    ],
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
                          : (!kIsWeb
                              ? WebViewWidget(controller: _controller)
                              : const SizedBox()),
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
                              'Tap elemen di halaman web untuk memantau bagian tersebut.\nGunakan mode seleksi hanya saat halaman/tabel telah termuat sepenuhnya.\n(Catatan: Pengecekan latar belakang tidak mendukung fungsi Login di WebView ini.)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
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
