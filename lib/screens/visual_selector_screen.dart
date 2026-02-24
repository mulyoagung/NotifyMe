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

class _VisualSelectorScreenState extends State<VisualSelectorScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  late final win_web.WebviewController _windowsController;
  bool _isLoading = true;
  String _currentSelector = '';
  String _currentUrl = '';
  bool _isWindowsInitError = false;
  bool _isSelectionMode = false;

  // ══════════════════ Navigation Recorder ══════════════════
  bool _isRecordingMode = false;
  final List<Map<String, String>> _recordedSteps = [];
  late final TabController _tabController;

  // CSS selector builder helper (shared between selection & recording)
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

  // Recording script: lets clicks through but intercepts BEFORE navigation
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
      // Allow normal click to proceed (no preventDefault)
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
    _tabController = TabController(length: 2, vsync: this);
    String targetUrl =
        widget.url.startsWith('http') ? widget.url : 'https://${widget.url}';

    if (_isWindows) {
      _initWindowsWebview(targetUrl);
    } else if (_isWebViewSupported) {
      _controller = WebViewController();
      if (!kIsWeb) {
        _controller.setJavaScriptMode(JavaScriptMode.unrestricted);

        // Channel for element selection
        _controller.addJavaScriptChannel(
          'SelectorChannel',
          onMessageReceived: (message) {
            setState(() => _currentSelector = message.message);
          },
        );

        // Channel for navigation recording
        _controller.addJavaScriptChannel(
          'RecorderChannel',
          onMessageReceived: (message) {
            try {
              final data =
                  Map<String, dynamic>.from(_parseJson(message.message));
              final selector = data['selector']?.toString() ?? '';
              final label = data['label']?.toString() ?? '';
              if (selector.isNotEmpty) {
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
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted)
            setState(() {
              _isLoading = false;
              _currentUrl = targetUrl;
            });
        });
      }
      _controller.loadRequest(Uri.parse(targetUrl));
    } else {
      _isLoading = false;
    }
  }

  // Minimal JSON parser for our simple payload
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
        setState(() => _currentSelector = event['message'] ?? '');
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
    if (_isWindows) _windowsController.dispose();
    super.dispose();
  }

  void _confirmSelection() {
    // Build preNavigationScript from recorded steps
    String preNavScript = '';
    if (_recordedSteps.isNotEmpty) {
      final lines = _recordedSteps.map((step) {
        return "// Klik: ${step['label']}\n"
            "var el_${_recordedSteps.indexOf(step)} = document.querySelector('${(step['selector'] ?? '').replaceAll("'", "\\'")}');\n"
            "if (el_${_recordedSteps.indexOf(step)}) el_${_recordedSteps.indexOf(step)}.click();";
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
    String script =
        "window.NotifyMeSelectionEnabled = ${enable ? 'true' : 'false'};";
    if (_isWindows) {
      if (_windowsController.value.isInitialized)
        _windowsController.executeScript(script);
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

  void _toggleRecordingMode() {
    setState(() {
      _isRecordingMode = !_isRecordingMode;
      if (_isRecordingMode) {
        _isSelectionMode = false;
        _recordedSteps.clear();
        if (!kIsWeb) _controller.runJavaScript(_recordingScript);
        // Switch to recorder tab
        _tabController.animateTo(1);
      } else {
        if (!kIsWeb) {
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
          // Recording toggle button
          TextButton.icon(
            onPressed: _toggleRecordingMode,
            icon: Icon(
              _isRecordingMode ? Icons.stop_circle : Icons.fiber_manual_record,
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
          // Selected element bar
          if (_currentSelector.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
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
                            fontSize: 12)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: _expandSelection,
                      tooltip: 'Pilih Induk'),
                  IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      onPressed: _shrinkSelection,
                      tooltip: 'Pilih Anak'),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // ── Tab 1: WebView ──
                _buildWebViewArea(isDark),

                // ── Tab 2: Recorded Steps ──
                _buildRecordedStepsPanel(isDark),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: !_isRecordingMode
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
          : FloatingActionButton.extended(
              onPressed: () {
                _tabController.animateTo(0);
              },
              backgroundColor: Colors.grey.shade700,
              icon: const Icon(Icons.web_asset),
              label: const Text('Lihat Website',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildWebViewArea(bool isDark) {
    if (!_isWebViewSupported || _isWindowsInitError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web_asset_off, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              !_isWebViewSupported
                  ? 'Visual Selector tidak didukung di Platform ini.\nSilakan masukkan CSS Selector secara manual.'
                  : 'Terjadi kesalahan memuat WebView Desktop.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
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

    return Stack(
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
                      'Mode Rekam Aktif — Navigasi ke sub-menu yang kamu tuju. Setiap klik akan direkam!',
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
            bottom: 24,
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
                      'Langkah Navigasi Terekam (${_recordedSteps.length})',
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
                      ? '🔴 Sedang merekam. Buka aplikasi lalu navigasi ke konten yang ingin dipantau.'
                      : _recordedSteps.isEmpty
                          ? 'Tekan "Rekam Navigasi" lalu buka sub-menu/login di website.'
                          : '✅ ${_recordedSteps.length} langkah terekam. Script akan dibuat otomatis.',
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
                          'Belum ada langkah terekam.\n1. Tekan "Rekam Navigasi" di atas\n2. Klik menu / sub-menu di website\n3. Script JS dibuat otomatis!',
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
                      const Text('Script yang Akan Dibuat:',
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
                        .map((e) =>
                            '// ${e.value['label']}\ndocument.querySelector(\'${(e.value['selector'] ?? '').replaceAll("'", "\\'")}\')?.click();')
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
