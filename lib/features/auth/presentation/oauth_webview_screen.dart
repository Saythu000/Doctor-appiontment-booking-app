import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/features/auth/data/auth_repository.dart';
import 'package:phia_flutter/features/auth/domain/auth_models.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Runs the IAM sign-in page inside the app and returns the OAuth callback
/// URL together with the IAM session cookie.
///
/// Why a WebView and not Chrome Custom Tabs: the FHIR backend only accepts
/// the Better Auth JWT, and IAM only issues that JWT for a session cookie
/// (`GET /api/auth/token`). Custom Tabs keep their cookies inside Chrome,
/// out of the app's reach. This is a stopgap until the backend lets the app
/// get the JWT another way (docs/backend_request_option_b.md).
///
/// The app never reads the page or the password: no JavaScript channels are
/// added, and only the session cookie is read after the redirect.
class OAuthWebViewScreen extends StatefulWidget {
  final Uri authorizeUrl;
  final String callbackScheme;

  const OAuthWebViewScreen({
    super.key,
    required this.authorizeUrl,
    required this.callbackScheme,
  });

  /// Opens the sign-in page. Returns null when the user closes it.
  static Future<WebLoginResult?> open(BuildContext context, Uri authorizeUrl) {
    return Navigator.of(context).push<WebLoginResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OAuthWebViewScreen(
          authorizeUrl: authorizeUrl,
          callbackScheme: AuthRepository.oauthCallbackScheme,
        ),
      ),
    );
  }

  @override
  State<OAuthWebViewScreen> createState() => _OAuthWebViewScreenState();
}

class _OAuthWebViewScreenState extends State<OAuthWebViewScreen> {
  static const MethodChannel _sessionChannel = MethodChannel('com.drgodly.app/iam_session');

  final WebViewController _controller = WebViewController();
  int _progress = 0;
  bool _done = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // the IAM login form needs it
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onNavigationRequest: (request) {
            if (_isCallback(request.url)) {
              _finish(request.url);
              return NavigationDecision.prevent;
            }
            // Only web pages may load here: no intent://, market:// or other
            // app links out of the sign-in page.
            final scheme = Uri.tryParse(request.url)?.scheme;
            return scheme == 'https' ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            if (_isCallback(url)) _finish(url);
          },
          onWebResourceError: (error) {
            final url = error.url;
            if (url != null && _isCallback(url)) {
              _finish(url);
            } else if (error.isForMainFrame ?? false) {
              if (mounted) setState(() => _loadFailed = true);
            }
          },
        ),
      );
    _start();
  }

  /// Every sign-in starts with an empty cookie store, so a previous user's
  /// IAM session can never be reused and the cookie read afterwards is the
  /// one this sign-in created.
  Future<void> _start() async {
    try {
      await WebViewCookieManager().clearCookies();
      await _controller.clearCache();
      await _controller.clearLocalStorage();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loadFailed = false);
    await _controller.loadRequest(widget.authorizeUrl);
  }

  bool _isCallback(String url) => url.startsWith('${widget.callbackScheme}:');

  Future<void> _finish(String callbackUrl) async {
    if (_done) return;
    _done = true;
    String? sessionCookie;
    try {
      sessionCookie = await _sessionChannel.invokeMethod<String>('getSessionCookie');
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(WebLoginResult(callbackUrl: callbackUrl, sessionCookie: sessionCookie));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel sign-in',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 18, color: colors.success.foreground),
            const SizedBox(width: AppSpacing.sm),
            const Flexible(child: Text('iam.drgodly.com', overflow: TextOverflow.ellipsis)),
          ],
        ),
        bottom: _progress < 100 && !_loadFailed
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100, minHeight: 3),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: _loadFailed ? _LoadError(onRetry: _start) : WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: colors.danger.foreground),
            const SizedBox(height: AppSpacing.md),
            Text("Couldn't open the sign-in page", style: context.text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text('Check your connection and try again.', style: context.text.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
