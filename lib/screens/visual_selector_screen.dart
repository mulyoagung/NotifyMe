import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';
import '../services/tauri_service.dart';

// Only import webview_windows on non-web builds
import 'package:webview_windows/webview_windows.dart' as win_web;

class VisualSelectorScreen extends StatefulWidget {
  final String url;
  const VisualSelectorScreen({Key? key, required this.url}) : super(key: key);

  @override
  State<VisualSelectorScreen> createState() => _VisualSelectorScreenState();
}

class _VisualSelectorScreenState extends State<VisualSelectorScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  late final win_web.WebviewController _windowsController;
  bool _isLoading = true;
  String _currentSelector = '';
  String _currentUrl = '';
  bool _isWindowsInitError = false;
  bool _isSelectionMode = false;
  bool _isRecordingMode = false;
  final List<Map<String, String>> _recordedSteps = [];
  late final TabController _tabController;

  // ── Platform Detection ──
  // WebView is only supported on native Android/iOS (via webview_flutter)
  // or native Windows (via webview_windows).
  // On kIsWeb (Tauri) — NO native WebView is available; show graceful fallback.
  bool get _isMobileWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool get _isWebViewSupported => _isMobileWebView || _isWindows;

  // ── CSS Selector builder JS ──
  final String _getCssSelectorFn = '''
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
          while (sib) { nth++; sib = sib.previousElementSibling; }
          if (el.className && typeof el.className === 'string' && selector !== 'body' && selector !== 'html') {
            var classes = el.className.trim().split(/\\s+/);
            var validClass = classes.find(c => /^[a-zA-Z0-9\\-_]+\$/.test(c) && !c.includes('__') && !c.startsWith('inter_') && c.length < 30);
            if (validClass) selector += '.' + validClass;
          }
          if (nth != 1) selector += ":nth-child("+nth+")";
        }
        path.unshift(selector);
        el = el.parentNode;
      }
      return path.join(" > ");
    }
  ''';

  String get _selectionScript => '''
    $_getCssSelectorFn
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

  String get _recordingScript => '''
    $_getCssSelectorFn
    window.NotifyMeRecording = true;
    window.NotifyMeRecordChannel = window.NotifyMeRecordChannel || null;

    document.body.addEventListener('click', function(e) {
      if (!window.NotifyMeRecording) return;
      var sel = getCssSelector(e.target);
      var label = (e.target.innerText || e.target.value || e.target.title || '').trim().substring(0, 50);
      if (sel) {
        RecorderChannel.postMessage(JSON.stringify({selector: sel, label: label}));
      }
    }, true);
  ''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final String targetUrl =
        widget.url.startsWith('http') ? widget.url : 'https://${widget.url}';

    if (_isWindows) {
      _initWindowsWebview(targetUrl);
    } else if (_isMobileWebView) {
      // Native Android/iOS WebView
      _controller = WebViewController();
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);

      _controller.addJavaScriptChannel(
        'SelectorChannel',
        onMessageReceived: (message) {
          if (mounted) setState(() => _currentSelector = message.message);
        },
      );

      _controller.addJavaScriptChannel(
        'RecorderChannel',
        onMessageReceived: (message) {
          try {
            final data = Map<String, dynamic>.from(_parseJson(message.message));
            final selector = data['selector']?.toString() ?? '';
            final label = data['label']?.toString() ?? '';
            if (selector.isNotEmpty && mounted) {
              setState(() {
                _recordedSteps.add({
                  'selector': selector,
                  'label': label.isNotEmpty
                      ? label
                      : selector.split('>').last.trim(),
                });
              });
            }
          } catch (_) {}
        },
      );

      _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
              if (_isRecordingMode) {
                _controller.runJavaScript(_recordingScript);
              } else {
                _controller.runJavaScript(_selectionScript);
                _updateSelectionMode(_isSelectionMode);
              }
            }
          },
        ),
      );
      _controller.loadRequest(Uri.parse(targetUrl));
    } else {
      // On kIsWeb (Tauri/browser): WebView not supported — show fallback
      _isLoading = false;
    }
  }

  Map<String, dynamic> _parseJson(String input) {
    final result = <String, dynamic>{};
    final cleaned = input.replaceAll('{', '').replaceAll('}', '');
    for (final pair in cleaned.split(',')) {
      final kv = pair.split(':');
      if (kv.length >= 2) {
        final key = kv[0].replaceAll('"', '').trim();
        final val = kv.sublist(1).join(':').replaceAll('"', '').trim();
        result[key] = val;
      }
    }
    return result;
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
        if (mounted) setState(() => _currentSelector = event['message'] ?? '');
      });
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _isWindowsInitError = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_isWindows) {
      try {
        _windowsController.dispose();
      } catch (_) {}
    }
    super.dispose();
  }

  void _confirmSelection() {
    String preNavScript = '';
    if (_recordedSteps.isNotEmpty) {
      final lines = _recordedSteps.asMap().entries.map((e) {
        final idx = e.key;
        final step = e.value;
        return "// Klik: ${step['label']}\n"
            "var el_$idx = document.querySelector('${(step['selector'] ?? '').replaceAll("'", "\\'")}');\n"
            "if (el_$idx) el_$idx.click();";
      }).join('\n\n');
      preNavScript = lines;
    }

    Navigator.pop(context, {
      'selector': _currentSelector,
      'url': _currentUrl.isNotEmpty ? _currentUrl : widget.url,
      'preNavigationScript': preNavScript,
    });
  }

  void _updateSelectionMode(bool enable) {
    final script =
        "window.NotifyMeSelectionEnabled = ${enable ? 'true' : 'false'};";
    if (_isWindows) {
      if (_windowsController.value.isInitialized) {
        _windowsController.executeScript(script);
      }
    } else if (_isMobileWebView) {
      _controller.runJavaScript(script);
    }
    // On kIsWeb: no-op, no WebView available
  }

  void _toggleMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _updateSelectionMode(_isSelectionMode);
    });
  }

  void _toggleRecordingMode() {
    setState(() {
      _isRecordingMode = !_isRecordingMode;
      if (_isRecordingMode) {
        _isSelectionMode = false;
        _recordedSteps.clear();
        if (_isWindows) {
          _windowsController.executeScript(_recordingScript);
        } else if (_isMobileWebView) {
          _controller.runJavaScript(_recordingScript);
        }
        _tabController.animateTo(1);
      } else {
        if (_isWindows) {
          _windowsController.executeScript(_selectionScript);
          _updateSelectionMode(false);
        } else if (_isMobileWebView) {
          _controller.runJavaScript(_selectionScript);
          _updateSelectionMode(false);
        }
        _tabController.animateTo(0);
      }
    });
  }

  void _expandSelection() {
    if (_isWindows) {
      _windowsController.executeScript('window.NotifyMeExpand()');
    } else if (_isMobileWebView) {
      _controller.runJavaScript('window.NotifyMeExpand()');
    }
  }

  void _shrinkSelection() {
    if (_isWindows) {
      _windowsController.executeScript('window.NotifyMeShrink()');
    } else if (_isMobileWebView) {
      _controller.runJavaScript('window.NotifyMeShrink()');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A120E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Visual Selector',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            if (_isRecordingMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('● MEREKAM',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        actions: [
          if (_isWebViewSupported)
            TextButton.icon(
              onPressed: _toggleRecordingMode,
              icon: Icon(
                _isRecordingMode
                    ? Icons.stop_circle
                    : Icons.fiber_manual_record,
                color: _isRecordingMode ? Colors.redAccent : Colors.orange,
                size: 18,
              ),
              label: Text(
                _isRecordingMode ? 'Stop Rekam' : 'Rekam Navigasi',
                style: TextStyle(
                  color: _isRecordingMode ? Colors.redAccent : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          if (_currentSelector.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check, color: AppTheme.primaryColor),
              label: const Text('Simpan',
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.ads_click, size: 16), text: 'Pilih Elemen'),
            Tab(icon: Icon(Icons.route, size: 16), text: 'Rekaman Navigasi'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Selected element indicator bar
          if (_currentSelector.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              child: Row(
                children: [
                  const Text('Terpilih: ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey)),
                  Expanded(
                    child: Text(_currentSelector,
                        style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontFamily: 'monospace',
                            fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (_isWebViewSupported) ...[
                    IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: _expandSelection,
                        tooltip: 'Pilih Induk'),
                    IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: _shrinkSelection,
                        tooltip: 'Pilih Anak'),
                  ],
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Tab 1: WebView or Fallback
                _buildWebViewArea(isDark),
                // Tab 2: Recorded Navigation Steps
                _buildRecordedStepsPanel(isDark),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isWebViewSupported && !_isRecordingMode
          ? FloatingActionButton.extended(
              onPressed: _toggleMode,
              backgroundColor:
                  _isSelectionMode ? Colors.redAccent : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: Icon(_isSelectionMode ? Icons.close : Icons.ads_click),
              label: Text(
                _isSelectionMode ? 'Batalkan Seleksi' : 'Pilih Elemen',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : _isRecordingMode
              ? FloatingActionButton.extended(
                  onPressed: () => _tabController.animateTo(0),
                  backgroundColor: Colors.grey.shade700,
                  icon: const Icon(Icons.web_asset),
                  label: const Text('Lihat Website',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : null,
    );
  }

  // ── State for Tauri desktop paste flow ──
  String _pastedSelector = '';

  Widget _buildWebViewArea(bool isDark) {
    // ── Fallback: Tauri/kIsWeb — use native Tauri window instead ──
    if (!_isWebViewSupported) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.ads_click,
                      color: AppTheme.primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Visual Selector — Desktop',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                        'Klik tombol di bawah untuk membuka halaman target.\nPilih elemen, lalu salin hasilnya ke sini.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Step 1: Open selector window
            _buildStepCard(
              isDark,
              step: '1',
              color: AppTheme.primaryColor,
              title: 'Buka Window Selector',
              subtitle: 'Klik tombol ini — browser window baru akan terbuka.\n'
                  'Hover lalu klik elemen di halaman web yang ingin dipantau.\n'
                  'Klik ✅ Simpan Selector di toolbar atas.',
              action: FilledButton.icon(
                onPressed: () {
                  final url = widget.url.startsWith('http')
                      ? widget.url
                      : 'https://${widget.url}';
                  TauriService.openSelectorWindow(url);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          '🎯 Window selector dibuka! Pilih elemen, lalu klik ✅ Simpan Selector.'),
                      duration: Duration(seconds: 4),
                      backgroundColor: Color(0xFF0D2B1E),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  'Buka ${widget.url.length > 30 ? widget.url.substring(0, 30) + "…" : widget.url}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Step 2: Paste from clipboard
            _buildStepCard(
              isDark,
              step: '2',
              color: Colors.orange,
              title: 'Tempel Selector dari Clipboard',
              subtitle: 'Setelah klik ✅ Simpan di window selector,\n'
                  'selector otomatis tersalin ke clipboard.\n'
                  'Klik tombol tempel di bawah:',
              action: OutlinedButton.icon(
                onPressed: () async {
                  final text = await TauriService.readClipboard();
                  if (text != null && text.isNotEmpty) {
                    setState(() => _pastedSelector = text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Selector: $text'),
                        backgroundColor: const Color(0xFF0D2B1E),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Clipboard kosong. Pastikan sudah klik ✅ Simpan di window selector.')),
                    );
                  }
                },
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('Tempel dari Clipboard',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: BorderSide(color: Colors.orange.withOpacity(0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Step 3: Confirm or show pasted selector
            if (_pastedSelector.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppTheme.primaryColor, size: 18),
                        const SizedBox(width: 8),
                        const Text('Selector Siap:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pastedSelector,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentSelector = _pastedSelector;
                            _currentUrl = widget.url;
                          });
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Gunakan Selector Ini',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Confirm & return button
            if (_currentSelector.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _confirmSelection,
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan & Kembali',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      );
    }

    // ── Windows WebView failed to initialize ──
    if (_isWindowsInitError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Colors.redAccent.shade200),
            const SizedBox(height: 16),
            const Text('Terjadi kesalahan memuat WebView Desktop.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      );
    }

    // ── Native WebView (Android / iOS / Windows) ──
    return Stack(
      children: [
        _isWindows
            ? (_windowsController.value.isInitialized
                ? win_web.Webview(_windowsController)
                : const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor)))
            : WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        if (_isRecordingMode && !_isLoading)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fiber_manual_record,
                      color: Colors.white, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode Rekam Aktif — Klik elemen/menu di website untuk merekam navigasi!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!_isLoading && _currentSelector.isEmpty && _isSelectionMode)
          Positioned(
            bottom: 80,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'Tap elemen di halaman web untuk memantau bagian tersebut.',
                style: TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStepCard(bool isDark,
      {required String step,
      required Color color,
      required String title,
      required String subtitle,
      required Widget action}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111A14) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Center(
                  child: Text(step,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: color)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 12),
          action,
        ],
      ),
    );
  }

  Widget _buildRecordedStepsPanel(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0A120E) : Colors.grey.shade50,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF111A14) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.route,
                        color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Rekaman Navigasi (${_recordedSteps.length} langkah)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    if (_recordedSteps.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setState(() => _recordedSteps.clear()),
                        icon: const Icon(Icons.delete_sweep,
                            size: 16, color: Colors.redAccent),
                        label: const Text('Hapus Semua',
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isRecordingMode
                      ? '🔴 Sedang merekam. Navigasi ke konten yang ingin dipantau.'
                      : _recordedSteps.isEmpty
                          ? 'Tekan "Rekam Navigasi" lalu navigasi di website.'
                          : '✅ ${_recordedSteps.length} langkah terekam. Script dibuat otomatis.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // Steps list
          Expanded(
            child: _recordedSteps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada langkah terekam.\n'
                          '1. Tekan "Rekam Navigasi" di atas\n'
                          '2. Klik menu / sub-menu di website\n'
                          '3. Script JS dibuat otomatis!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                              height: 1.8),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _recordedSteps.length,
                    itemBuilder: (context, index) {
                      final step = _recordedSteps[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF141E17) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${index + 1}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step['label'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    step['selector'] ?? '',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        color: Colors.grey.shade500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: Colors.grey),
                              onPressed: () => setState(
                                  () => _recordedSteps.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Generated script preview
          if (_recordedSteps.isNotEmpty)
            Container(
              width: double.infinity,
              color: isDark ? const Color(0xFF0C150F) : Colors.grey.shade100,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.code, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      const Text('Script yang akan dibuat:',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const Spacer(),
                      Text('${_recordedSteps.length} klik',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _recordedSteps
                        .asMap()
                        .entries
                        .map((e) => '// ${e.value['label']}\n'
                            "document.querySelector('${(e.value['selector'] ?? '').replaceAll("'", "\\'")}')?.click();")
                        .join('\n'),
                    style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppTheme.primaryColor),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
