import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/providers.dart';
import '../../core/analytics.dart';
import '../../core/widgets/common.dart';

/// Whether the preview WebView may navigate to [target]. Only the site's own pages: the preview
/// carries a short-lived credential in its URL, so it must never be steered to another host.
bool isAllowedPreviewNavigation(Uri target, Uri site) {
  if (target.scheme == 'about') return true;
  return target.scheme == site.scheme && target.host == site.host && target.port == site.port;
}

/// Shows the draft in the real web renderer (the same code recipients see), so what you preview is
/// exactly what you publish.
class PreviewPage extends ConsumerStatefulWidget {
  const PreviewPage({super.key, required this.surpriseId});
  final String surpriseId;

  @override
  ConsumerState<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends ConsumerState<PreviewPage> {
  WebViewController? _controller;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final token = await ref.read(surpriseRepositoryProvider).previewToken(widget.surpriseId);
      if (!mounted) return;
      final config = ref.read(configProvider);
      final site = Uri.parse(config.siteUrl);
      ref.read(analyticsProvider).track(AppEvent.previewOpened);
      final controller = _controller ??
          (WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(NavigationDelegate(
              onNavigationRequest: (r) =>
                  isAllowedPreviewNavigation(Uri.parse(r.url), site) ? NavigationDecision.navigate : NavigationDecision.prevent,
              onPageFinished: (_) {
                if (mounted) setState(() => _loading = false);
              },
              onWebResourceError: (e) {
                if (mounted && (e.isForMainFrame ?? false)) setState(() => _error = const ApiExceptionPlaceholder());
              },
            )));
      await controller.loadRequest(config.previewUri(token));
      if (mounted) setState(() => _controller = controller);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        actions: [IconButton(tooltip: 'Reload', icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: _error != null
          ? ErrorState(error: _error!, onRetry: _load)
          : Stack(children: [
              if (_controller != null) WebViewWidget(controller: _controller!),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ]),
    );
  }
}

/// A page-load failure inside the WebView has no API error to show; this renders as the generic one.
class ApiExceptionPlaceholder implements Exception {
  const ApiExceptionPlaceholder();
}
