import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';

class VercelDashboardScreen extends StatefulWidget {
  const VercelDashboardScreen({Key? key}) : super(key: key);

  @override
  State<VercelDashboardScreen> createState() => _VercelDashboardScreenState();
}

class _VercelDashboardScreenState extends State<VercelDashboardScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
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
              }
            },
          ),
        )
        ..loadRequest(Uri.parse('https://mailin-univet.vercel.app/dashboard'));
    } else {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mailin Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
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
                  color: isDark ? AppTheme.primaryColor : Colors.grey.shade700,
                  size: 22),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _controller.reload();
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _isLoading
              ? const LinearProgressIndicator(
                  color: AppTheme.primaryColor,
                  backgroundColor: Colors.transparent,
                  minHeight: 2)
              : const SizedBox(height: 2),
        ),
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
              ]),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            child: _isWebViewSupported
                ? WebViewWidget(controller: _controller)
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.web_asset_off,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                            'Mailin Dashboard is securely protected.\nCannot be previewed outside Mobile devices.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
