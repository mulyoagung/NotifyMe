import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import '../models/monitored_link.dart';
import '../theme.dart';
import '../services/database_helper.dart';

class DetailScreen extends StatefulWidget {
  final MonitoredLink link;

  const DetailScreen({Key? key, required this.link}) : super(key: key);

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _selectedTab = 'Teks Update';
  bool _isWebViewSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_isWebViewSupported) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                if (widget.link.cssSelector.isNotEmpty) {
                  bool hasPrevious = widget.link.previousSnapshot.isNotEmpty &&
                      widget.link.hasUpdate;
                  String oldItemsStr =
                      hasPrevious ? widget.link.previousSnapshot : '[]';

                  _controller.runJavaScript('''
                    setTimeout(() => {
                      var selector = "${widget.link.cssSelector.replaceAll('"', '\\"')}";
                      if (!selector) return;
                      var nodes = document.querySelectorAll(selector);
                      if (nodes.length === 0) return;
                      
                      var oldItems = $oldItemsStr;
                      var newLines = [];
                      
                      // 1. Compute which text lines are brand new
                      for (var i = 0; i < nodes.length; i++) {
                        if (nodes[i].innerText) {
                          var lines = nodes[i].innerText.split('\\n');
                          for (var j = 0; j < lines.length; j++) {
                            var text = lines[j].trim();
                            if (text.length > 0) {
                              if (oldItems && oldItems.length > 0) {
                                if (oldItems.indexOf(text) === -1 && newLines.indexOf(text) === -1) {
                                  newLines.push(text);
                                }
                              } else {
                                if (newLines.indexOf(text) === -1) newLines.push(text);
                              }
                            }
                          }
                        }
                      }
                      
                      var firstNew = null;
                      
                      // 2. Find and highlight the deepest DOM element that renders each new line
                      for (var i = 0; i < nodes.length; i++) {
                        var root = nodes[i];
                        // Reverse array to check deepest children first
                        var allEls = Array.from(root.querySelectorAll('*')).reverse();
                        
                        for (var k = 0; k < newLines.length; k++) {
                           var line = newLines[k];
                           for (var j = 0; j < allEls.length; j++) {
                              var el = allEls[j];
                              
                              if (el.tagName === 'SCRIPT' || el.tagName === 'STYLE') continue;
                              
                              if (el.innerText && el.innerText.indexOf(line) !== -1) {
                                  el.style.outline = '4px solid #00F4B1';
                                  el.style.backgroundColor = 'rgba(0, 244, 177, 0.3)';
                                  el.style.transition = 'all 0.3s ease';
                                  
                                  if (!firstNew) {
                                    firstNew = el;
                                    el.scrollIntoView({behavior: 'smooth', block: 'center'});
                                  }
                                  break; // Deepest element found for this line, go to next line
                              }
                           }
                        }
                      }
                    }, 1000);
                  ''');
                }
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.link.url.startsWith('http')
            ? widget.link.url
            : 'https://${widget.link.url}'));
    } else {
      _isLoading = false;
    }
  }

  void _markAsRead() async {
    widget.link.hasUpdate = false;
    await DatabaseHelper.instance.update(widget.link);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tandai telah dibaca')),
      );
      Navigator.pop(context);
    }
  }

  void _markAsUnread() async {
    widget.link.hasUpdate = true;
    await DatabaseHelper.instance.update(widget.link);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tandai belum dibaca')),
      );
      Navigator.pop(context);
    }
  }

  String _formatJsonList(String jsonString) {
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      if (list.isEmpty) return 'Array kosong (Tidak ada text).';
      return list.map((item) => '• $item').join('\n\n');
    } catch (_) {
      return jsonString;
    }
  }

  void _openSiteFullscreen() {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.link.name)),
        body: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..loadRequest(Uri.parse(widget.link.url.startsWith('http')
                  ? widget.link.url
                  : 'https://${widget.link.url}'))),
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              widget.link.url,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'NOTIFYME PRO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, size: 22),
            tooltip: 'Salin URL',
            onPressed: () {
              final urlText = widget.link.url;
              Clipboard.setData(ClipboardData(text: urlText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('URL disalin ke clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.cardDark.withOpacity(0.5)
                  : Colors.grey.shade50,
              border: Border(
                  bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.5),
                                    blurRadius: 4)
                              ]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.link.hasUpdate
                              ? 'Pembaruan Terdeteksi'
                              : 'Tidak ada update',
                          style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ID: #${widget.link.id}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.link.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.link.hasUpdate
                      ? 'Konten berubah semenjak pengecekan terkahir'
                      : 'Konten sinkron',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),

          // View Toggle Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildTabButton('Teks Update', isDark),
                _buildTabButton('Visual Web', isDark),
              ],
            ),
          ),

          Expanded(
            child: _selectedTab == 'Teks Update'
                ? _buildTextUpdateView(isDark)
                : _buildVisualWebView(isDark),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
          border: Border(
              top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey.shade300,
                      width: 2),
                ),
                onPressed: _openSiteFullscreen,
                icon: const Icon(Icons.open_in_new, size: 20),
                label: const Text('Open Site',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            if (widget.link.hasUpdate)
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _markAsRead,
                  icon: const Icon(Icons.done_all, size: 20),
                  label: const Text('Mark as Read',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            else
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                  ),
                  onPressed: _markAsUnread,
                  icon: const Icon(Icons.mark_email_unread,
                      size: 20, color: Colors.grey),
                  label: const Text('Tandai Belum Dibaca',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextUpdateView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C1A12) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.text_snippet,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text('KONTEN UPDATE TERAKHIR',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 16),
              widget.link.lastSnapshot.isEmpty ||
                      widget.link.lastSnapshot == '[]'
                  ? const Text(
                      'Belum ada konten snapshot (atau format text kosong).',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                    )
                  : _buildDiffView(widget.link.previousSnapshot,
                      widget.link.lastSnapshot, isDark),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildDiffView(String oldText, String newText, bool isDark) {
    String oldFormatted = _formatJsonList(oldText);
    String newFormatted = _formatJsonList(newText);

    if (oldFormatted == newFormatted ||
        oldFormatted == 'Array kosong (Tidak ada text).') {
      return Text(
        newFormatted,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
          color: isDark ? Colors.grey.shade300 : Colors.black87,
        ),
      );
    }

    List<Diff> diffs = diff(oldFormatted, newFormatted);
    cleanupSemantic(diffs);

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
          color: isDark ? Colors.grey.shade300 : Colors.black87,
        ),
        children: diffs.map((d) {
          Color backgroundColor = Colors.transparent;
          Color textColor = isDark ? Colors.grey.shade300 : Colors.black87;
          TextDecoration decoration = TextDecoration.none;

          if (d.operation == DIFF_INSERT) {
            backgroundColor = const Color(0xFF00F4B1).withOpacity(0.2);
            textColor =
                isDark ? const Color(0xFF00F4B1) : Colors.green.shade800;
          } else if (d.operation == DIFF_DELETE) {
            backgroundColor = Colors.red.withOpacity(0.2);
            textColor = isDark ? Colors.redAccent : Colors.red.shade800;
            decoration = TextDecoration.lineThrough;
          }

          return TextSpan(
            text: d.text,
            style: TextStyle(
              backgroundColor: backgroundColor,
              decoration: decoration,
              color: textColor,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVisualWebView(bool isDark) {
    if (!_isWebViewSupported) {
      return Center(
        child: Text('WebView tidak disupport di device ini.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return Stack(
      children: [
        Container(
          height: double.infinity,
          margin: const EdgeInsets.all(16).copyWith(top: 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2)
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: WebViewWidget(controller: _controller),
          ),
        ),
        if (_isLoading)
          const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      ],
    );
  }

  Widget _buildTabButton(String title, bool isDark) {
    bool isSelected = _selectedTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = title),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.grey.shade700 : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 4)
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.grey.shade500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
