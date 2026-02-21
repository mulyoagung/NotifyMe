import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
                  _controller.runJavaScript('''
                    setTimeout(() => {
                      var el = document.querySelector("${widget.link.cssSelector}");
                      if (el) {
                        el.style.outline = '4px solid #FF5F56';
                        el.style.backgroundColor = 'rgba(255, 95, 86, 0.3)';
                        el.scrollIntoView({behavior: 'smooth', block: 'center'});
                      }
                    }, 500);
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
            onPressed: () {},
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
              Text(
                widget.link.lastSnapshot.isEmpty
                    ? 'Belum ada konten snapshot. Aplikasi sedang memantau secara berkala.'
                    : widget.link.lastSnapshot,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
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
