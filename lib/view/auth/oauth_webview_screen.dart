import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/colors.dart';

class OAuthWebViewResult {
  final String callbackUrl;
  final String? cookies;

  OAuthWebViewResult({
    required this.callbackUrl,
    this.cookies,
  });
}

class OAuthWebViewScreen extends StatefulWidget {
  final String authorizeUrl;
  final String callbackScheme;

  const OAuthWebViewScreen({
    super.key,
    required this.authorizeUrl,
    required this.callbackScheme,
  });

  @override
  State<OAuthWebViewScreen> createState() => _OAuthWebViewScreenState();
}

class _OAuthWebViewScreenState extends State<OAuthWebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasRedirected = false;

  static const MethodChannel _cookieChannel = MethodChannel('com.example.phia_flutter/cookies');

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..clearCache()
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress);
            }
          },
          onPageStarted: (String url) {
            _checkRedirect(url);
          },
          onPageFinished: (String url) {
            _checkRedirect(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_checkRedirect(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            if (error.url != null && error.url!.startsWith(widget.callbackScheme)) {
              _checkRedirect(error.url!);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizeUrl));
  }

  bool _checkRedirect(String url) {
    if (_hasRedirected) return true;

    final scheme = widget.callbackScheme;
    final isCallback = url.startsWith('$scheme://') || url.startsWith('$scheme:');
    if (isCallback) {
      _hasRedirected = true;
      _handleCallback(url);
      return true;
    }
    return false;
  }

  Future<void> _handleCallback(String callbackUrl) async {
    String? cookies;
    try {
      cookies = await _cookieChannel.invokeMethod<String>('getCookies', {
        'url': 'https://iam.drgodly.com',
      });
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop(OAuthWebViewResult(
      callbackUrl: callbackUrl,
      cookies: cookies,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.navyAnchor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: PhiaColors.primaryLight, size: 18),
            const SizedBox(width: 8),
            Text(
              'DrGodly IAM Authentication',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        bottom: _loadingProgress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3.0),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100.0,
                  backgroundColor: PhiaColors.borderSubtle,
                  valueColor: const AlwaysStoppedAnimation<Color>(PhiaColors.primary),
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
