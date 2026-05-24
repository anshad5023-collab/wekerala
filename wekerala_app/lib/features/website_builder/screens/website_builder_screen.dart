import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import 'website_chat_screen.dart';

class WebsiteBuilderScreen extends StatefulWidget {
  final String url;
  const WebsiteBuilderScreen({super.key, required this.url});

  @override
  State<WebsiteBuilderScreen> createState() => _WebsiteBuilderScreenState();
}

class _WebsiteBuilderScreenState extends State<WebsiteBuilderScreen>
    with SingleTickerProviderStateMixin {
  late final WebViewController _webViewController;
  late final TabController _tabController;

  bool _loading = true;
  bool _hasError = false;
  bool _hasPendingDraft = false;

  // WebView only works on Android/iOS — not Windows/Linux/macOS
  bool get _isWebViewSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// shopId and uid are embedded in the URL query string by the caller:
  /// e.g. .../control/website?shopId=abc123&uid=xyz456
  String get _shopId =>
      Uri.tryParse(widget.url)?.queryParameters['shopId'] ?? '';

  String get _uid =>
      Uri.tryParse(widget.url)?.queryParameters['uid'] ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (_isWebViewSupported) _initController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'WekeralaAI',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            if (data['type'] == 'requires_confirmation') {
              _showAiConfirmationDialog(
                data['confirmPrompt'] as String? ?? '',
                data['confirmationId'] as String? ?? '',
                data['risk'] as String? ?? 'medium',
              );
            }
            if (data['type'] == 'patch_applied') {
              if (mounted) setState(() => _hasPendingDraft = true);
            }
          } catch (e) {
            debugPrint('[WekeralaAI] Channel error: $e');
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) async {
          final url = request.url;
          if (!url.startsWith('http://') && !url.startsWith('https://')) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (_) {
          if (mounted) setState(() { _loading = true; _hasError = false; });
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) {
            if (mounted) setState(() { _loading = false; _hasError = true; });
          }
        },
        onHttpError: (_) {},
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  void _retry() {
    setState(() { _loading = true; _hasError = false; });
    _webViewController.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAiConfirmationDialog(
      String prompt, String confirmationId, String risk) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Just checking…'),
        content: Text(prompt),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_isWebViewSupported) {
                _webViewController.runJavaScript(
                  'window.__aiConfirmationResult && '
                  'window.__aiConfirmationResult("$confirmationId", false)',
                );
              }
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  risk == 'high' ? Colors.red : AppColors.primary,
            ),
            onPressed: () {
              Navigator.pop(context);
              if (_isWebViewSupported) {
                _webViewController.runJavaScript(
                  'window.__aiConfirmationResult && '
                  'window.__aiConfirmationResult("$confirmationId", true)',
                );
              }
            },
            child: const Text('Yes, do it'),
          ),
        ],
      ),
    );
  }

  Future<void> _publishDraft() async {
    final shopId = _shopId;
    final uid = _uid;
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.storefrontBaseUrl}/api/website/publish'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'shopId': shopId, 'uid': uid}),
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() => _hasPendingDraft = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Website published!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Publish failed (${response.statusCode}). Try again.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publish failed. Check your connection.')),
      );
    }
  }

  void _discardDraft() {
    if (_isWebViewSupported) {
      _webViewController.runJavaScript(
        'window.__undoAiChanges && window.__undoAiChanges()',
      );
    }
    setState(() => _hasPendingDraft = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Storefront'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: 'Open in browser',
              onPressed: _openInBrowser,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.storefront), text: 'Preview'),
              Tab(icon: Icon(Icons.auto_awesome), text: 'AI Assistant'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // ── Tab 0: WebView preview ──────────────────────────────────
            _isWebViewSupported ? _buildWebViewTab() : _buildDesktopView(),

            // ── Tab 1: AI Assistant ─────────────────────────────────────
            WebsiteChatScreen(
              webViewController: _isWebViewSupported ? _webViewController : null,
              shopId: _shopId,
              uid: _uid,
              onPreviewRequested: () => _tabController.animateTo(0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebViewTab() {
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        if (_hasError)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off,
                    size: 56, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load.\nCheck your connection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _retry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        // ── Draft pending overlay ───────────────────────────────────────
        if (_hasPendingDraft)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Draft preview — not published yet',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _discardDraft,
                    child: const Text(
                      'Discard',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _publishDraft,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Publish'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront, size: 72, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Your Storefront',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.url,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openInBrowser,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            icon: const Icon(Icons.open_in_browser),
            label:
                const Text('Open in Browser', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
          const Text(
            'WebView is not supported on desktop.\nYour storefront opens in the browser.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
