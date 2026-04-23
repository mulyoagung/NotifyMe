import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'visual_selector_screen.dart';
import '../models/monitored_link.dart';
import '../theme.dart';
import 'dart:ui' show ImageFilter; // For BackdropFilter
import '../services/database_helper.dart';

class AddEditLinkScreen extends StatefulWidget {
  final MonitoredLink? link;

  const AddEditLinkScreen({Key? key, this.link}) : super(key: key);

  @override
  State<AddEditLinkScreen> createState() => _AddEditLinkScreenState();
}

class _AddEditLinkScreenState extends State<AddEditLinkScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _cssSelectorController;
  late TextEditingController _preNavScriptController;
  int _intervalMinutes = 5;
  bool _isActive = true;
  bool _isDesktop = false;

  late final WebViewController _controller;
  bool _isLoading = true;
  // WebView runs only on native Android/iOS. Never on kIsWeb (Tauri/browser).
  bool get _isWebViewSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.link?.name ?? '');
    _urlController = TextEditingController(text: widget.link?.url ?? '');
    _cssSelectorController = TextEditingController(
      text: widget.link?.cssSelector ?? '',
    );
    _preNavScriptController = TextEditingController(
      text: widget.link?.preNavigationScript ?? '',
    );
    if (widget.link != null) {
      _intervalMinutes = widget.link!.intervalMinutes;
      _isActive = widget.link!.isActive;
    }

    // _isWebViewSupported is false when kIsWeb → safe to initialize controller only on real mobile
    if (_isWebViewSupported) {
      _controller = WebViewController();
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );
    } else {
      _isLoading = false;
    }

    _urlController.addListener(() {
      if (mounted) setState(() {});
    });

    if (_urlController.text.isNotEmpty) {
      _loadUrl(_urlController.text);
    }
  }

  void _loadUrl(String rawUrl) {
    if (rawUrl.isEmpty) return;
    setState(() => _isLoading = true);
    String url = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
    if (_isWebViewSupported) {
      try {
        _controller.loadRequest(Uri.parse(url));
      } catch (_) {}
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _cssSelectorController.dispose();
    _preNavScriptController.dispose();
    super.dispose();
  }

  void _saveLink() async {
    if (_formKey.currentState!.validate()) {
      if (widget.link == null) {
        // Create new
        final newLink = MonitoredLink(
          name: _nameController.text,
          url: _urlController.text,
          cssSelector: _cssSelectorController.text,
          preNavigationScript: _preNavScriptController.text,
          intervalMinutes: _intervalMinutes,
          isActive: _isActive,
          lastCheckedAt: DateTime.now(),
        );
        await DatabaseHelper.instance.create(newLink);
      } else {
        // Update existing
        final updatedLink = widget.link!
          ..name = _nameController.text
          ..url = _urlController.text
          ..cssSelector = _cssSelectorController.text
          ..preNavigationScript = _preNavScriptController.text
          ..intervalMinutes = _intervalMinutes
          ..isActive = _isActive;
        await DatabaseHelper.instance.update(updatedLink);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monitor saved successfully')),
      );
      Navigator.pop(context);
    }
  }

  void _deleteLink() async {
    if (widget.link != null && widget.link!.id != null) {
      await DatabaseHelper.instance.delete(widget.link!.id!);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Monitor deleted')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    _isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A120E) : AppTheme.backgroundLight,
      body: Column(
        children: [
          // Desktop specific header
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.panelDark.withOpacity(0.8)
                      : Colors.white.withOpacity(0.8),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          widget.link == null
                              ? 'Add Monitor'
                              : 'Manage Monitor',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                margin: const EdgeInsets.only(right: 6),
                              ),
                              const Text(
                                'Live View',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.more_vert,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Responsive Content
          Expanded(
            child: _isDesktop
                ? _buildDesktopLayout(isDark)
                : _buildMobileLayout(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Configuration Sidebar (Left)
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.panelDark : Colors.white,
            border: Border(
              right: BorderSide(
                color: isDark
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.grey.shade200,
              ),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Configuration Section
                      const Text(
                        'CONFIGURATION',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Monitor Label',
                        hint: 'Enter a name for this monitor',
                        isDark: isDark,
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _urlController,
                        label: 'Website URL',
                        hint: 'https://example.com',
                        icon: Icons.link,
                        isDark: isDark,
                        onSubmitted: (url) => _loadUrl(url),
                        validator: (v) =>
                            v!.isEmpty ? 'Please enter a URL' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Check Frequency',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          DropdownButton<int>(
                            value: _intervalMinutes,
                            underline: const SizedBox(),
                            dropdownColor:
                                isDark ? AppTheme.panelDark : Colors.white,
                            items: [
                              DropdownMenuItem(
                                value: 1,
                                child: Text('Every 1 minute (Test)'),
                              ),
                              DropdownMenuItem(
                                value: 5,
                                child: Text('Every 5 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 15,
                                child: Text('Every 15 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('Every 1 hour'),
                              ),
                              DropdownMenuItem(
                                value: 1440,
                                child: Text('Daily'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null)
                                setState(() => _intervalMinutes = value);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Client Polling Section
                      const Text(
                        'CLIENT POLLING',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0A120E).withOpacity(0.5)
                              : Colors.grey.shade50,
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Headless Render',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Wait for JS execution',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: true,
                              onChanged: (v) {},
                              activeColor: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Save Button
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.panelDark : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saveLink,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.backgroundDark,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                        child: const Text(
                          'Save Monitor',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    if (widget.link != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _deleteLink,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: Colors.red.withOpacity(0.5),
                              width: 1.5,
                            ),
                            foregroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Delete Monitor',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Live Preview Workspace (Right)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.ads_click,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Select the element you want to track',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildToolButton(Icons.zoom_in, isDark),
                        const SizedBox(width: 8),
                        _buildToolButton(Icons.zoom_out, isDark),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Browser Mockup
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white
                          : Colors.white, // Webview area is mostly white
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Browser Top Bar
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF5F56),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFBD2E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF27C93F),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.lock,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _urlController.text.isEmpty
                                            ? 'Waiting for URL...'
                                            : _urlController.text,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.refresh,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                        // WebView Content
                        Expanded(
                          child: Stack(
                            children: [
                              _isWebViewSupported
                                  ? WebViewWidget(controller: _controller)
                                  : _buildMockWebView(isDark),
                              if (_isLoading && _urlController.text.isNotEmpty)
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Selector Display
                Row(
                  children: [
                    const Text(
                      'SELECTOR:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _cssSelectorController,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Input selector manual / Pilih elemen',
                          hintStyle: TextStyle(
                            color: Colors.grey.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade900
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (_urlController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Masukkan URL website terlebih dahulu',
                              ),
                            ),
                          );
                          return;
                        }
                        final selected = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                VisualSelectorScreen(url: _urlController.text),
                          ),
                        );
                        if (selected != null && selected is Map) {
                          setState(() {
                            _cssSelectorController.text =
                                selected['selector'] ?? '';
                            if (selected['url'] != null &&
                                selected['url']!.toString().isNotEmpty) {
                              _urlController.text = selected['url']!;
                            }
                            // Auto-fill pre-navigation script if recorder was used
                            if (selected['preNavigationScript'] != null &&
                                selected['preNavigationScript']
                                    .toString()
                                    .isNotEmpty) {
                              _preNavScriptController.text =
                                  selected['preNavigationScript']!;
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.ads_click, size: 16),
                      label: const Text(
                        'Pilih Elemen',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        side: BorderSide(color: AppTheme.primaryColor),
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    // Scrollable layout for smaller screens retaining all config
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Monitor Label',
            hint: 'Enter a name for this monitor',
            isDark: isDark,
            validator: (v) => v!.isEmpty ? 'Please enter a name' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _urlController,
            label: 'Website URL',
            hint: 'https://example.com',
            icon: Icons.link,
            isDark: isDark,
            onSubmitted: (url) => _loadUrl(url),
            validator: (v) => v!.isEmpty ? 'Please enter a URL' : null,
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Check Frequency',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              DropdownButton<int>(
                value: _intervalMinutes,
                underline: const SizedBox(),
                dropdownColor: isDark ? AppTheme.panelDark : Colors.white,
                items: [
                  DropdownMenuItem(
                      value: 1, child: Text('Every 1 minute (Test)')),
                  DropdownMenuItem(value: 5, child: Text('Every 5 minutes')),
                  DropdownMenuItem(value: 15, child: Text('Every 15 minutes')),
                  DropdownMenuItem(value: 60, child: Text('Every 1 hour')),
                  DropdownMenuItem(value: 1440, child: Text('Daily')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _intervalMinutes = value);
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Text(
            'VISUAL SELECTOR',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _buildTextField(
            controller: _cssSelectorController,
            label: 'CSS Selector',
            hint: 'Contoh: .product-price atau #main-content',
            icon: Icons.code,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                if (_urlController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Masukkan URL website terlebih dahulu'),
                    ),
                  );
                  return;
                }
                final selected = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VisualSelectorScreen(url: _urlController.text),
                  ),
                );
                if (selected != null && selected is Map) {
                  setState(() {
                    _cssSelectorController.text = selected['selector'] ?? '';
                    if (selected['url'] != null &&
                        selected['url']!.toString().isNotEmpty) {
                      _urlController.text = selected['url']!;
                    }
                  });
                }
              },
              icon: const Icon(Icons.ads_click, size: 20),
              label: Text(
                _cssSelectorController.text.isEmpty
                    ? 'Pilih Elemen Web'
                    : 'Ubah Elemen Web',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(
                  color: AppTheme.primaryColor.withOpacity(0.5),
                  width: 1.5,
                ),
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Advanced: Pre-Navigation Script
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.code, color: AppTheme.primaryColor, size: 20),
            title: const Text(
              'Pre-Navigation Script (Opsional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'JS yang dijalankan sebelum scraping. Berguna untuk klik menu, login otomatis, dll.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: _preNavScriptController,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      "// Contoh: klik menu laporan\ndocument.querySelector('.nav-laporan').click();",
                  hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saveLink,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.backgroundDark,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Save Monitor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),

          if (widget.link != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _deleteLink,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide(
                    color: Colors.red.withOpacity(0.5),
                    width: 1.5,
                  ),
                  foregroundColor: Colors.red,
                ),
                child: const Text(
                  'Delete Monitor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],

          const SizedBox(height: 50), // padding
        ],
      ),
    );
  }

  Widget _buildMockWebView(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0D1510) : Colors.grey.shade50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Browser-style icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.monitor, size: 40, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              'Preview tidak tersedia di Desktop',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Masukkan URL dan gunakan tombol "Pilih Elemen"\nuntuk menentukan bagian halaman yang ingin dipantau.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.ads_click,
                      size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Klik "Pilih Elemen" di kolom CSS Selector',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        size: 16,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    required bool isDark,
    Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.grey.shade500, size: 20)
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF0A120E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor),
            ),
          ),
          onFieldSubmitted: onSubmitted,
          validator: validator,
        ),
      ],
    );
  }
}
