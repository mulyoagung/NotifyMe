import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';
import '../services/tauri_service.dart';

class VercelDashboardScreen extends StatefulWidget {
  const VercelDashboardScreen({Key? key}) : super(key: key);

  @override
  State<VercelDashboardScreen> createState() => _VercelDashboardScreenState();
}

class _VercelDashboardScreenState extends State<VercelDashboardScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // WebView is only supported on native mobile (Android/iOS). NOT on Web (kIsWeb = Tauri/browser).
  final bool _isWebViewSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final String _tweakScript = '''
    const style = document.createElement('style');
    style.innerHTML = `
      .sidebar { display: none !important; }
      body { padding-left: 0 !important; }
      .mobile-menu-btn { display: none !important; }
    `;
    document.head.appendChild(style);
  ''';

  @override
  void initState() {
    super.initState();
    if (_isWebViewSupported) {
      _controller = WebViewController();
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
              _controller.runJavaScript(_tweakScript);
            }
          },
        ),
      );
      _controller
          .loadRequest(Uri.parse('https://mailin-univet.vercel.app/dashboard'));
    } else {
      _isLoading = false;
    }
  }

  Widget _buildWebViewBody(bool isDark) {
    if (_isWebViewSupported) {
      return Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
        ],
      );
    }
    // On Tauri (kIsWeb) or unsupported platforms: show graceful fallback
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDark : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.web_asset_off,
                size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            'Mailin Dashboard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'WebView built-in hanya tersedia di Android/iOS.\nGunakan salah satu opsi di bawah:',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 28),
          // Option 1: Open in Tauri native window (in-app)
          SizedBox(
            width: 280,
            child: FilledButton.icon(
              onPressed: () {
                TauriService.openWebviewWindow(
                  'https://mailin-univet.vercel.app/dashboard',
                  'Mailin Dashboard',
                );
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Buka di Window Baru (In-App)',
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
          const SizedBox(height: 12),
          // Option 2: Open in system browser
          SizedBox(
            width: 280,
            child: OutlinedButton.icon(
              onPressed: () {
                TauriService.openUrlExternal(
                    'https://mailin-univet.vercel.app/dashboard');
              },
              icon: const Icon(Icons.launch, size: 16),
              label: const Text('Buka di Browser Sistem'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isDesktop = MediaQuery.of(context).size.width >= 1024;

    if (isDesktop) {
      return _buildDesktopLayout(isDark);
    }
    return _buildMobileLayout(isDark);
  }

  // ── Desktop layout: no AppBar, uses shared sidebar from MainNavigation ──
  Widget _buildDesktopLayout(bool isDark) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header bar matching dashboard_screen style
          ClipRect(
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0F0D).withOpacity(0.5)
                    : Colors.white.withOpacity(0.8),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mailin Dashboard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (_isWebViewSupported)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.refresh,
                            color: isDark
                                ? AppTheme.primaryColor
                                : Colors.grey.shade700,
                            size: 20),
                        tooltip: 'Refresh',
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _controller.reload();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Content
          Expanded(child: _buildWebViewBody(isDark)),
        ],
      ),
    );
  }

  // ── Mobile layout: retains AppBar for mobile UX ──
  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mailin Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isWebViewSupported)
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.refresh,
                    color:
                        isDark ? AppTheme.primaryColor : Colors.grey.shade700,
                    size: 22),
                onPressed: () {
                  setState(() => _isLoading = true);
                  _controller.reload();
                },
              ),
            ),
        ],
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                    color: AppTheme.primaryColor,
                    backgroundColor: Colors.transparent,
                    minHeight: 2),
              )
            : null,
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            child: _buildWebViewBody(isDark),
          ),
        ),
      ),
    );
  }
}
