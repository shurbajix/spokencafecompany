import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FridayWebview extends ConsumerStatefulWidget {
  final int index;
  final int indexlevel;

  const FridayWebview({
    super.key,
    required this.index,
    required this.indexlevel,
  });

  @override
  ConsumerState<FridayWebview> createState() => _FridayWebviewState();
}

class _FridayWebviewState extends ConsumerState<FridayWebview> {
  double _progress = 0;
  bool _isLoading = true;
  InAppWebViewController? inAppWebViewController;
  HeadlessInAppWebView? headlessWebView;

  final String removeHeaderFooterScript = '''
    document.querySelector('header')?.remove();
    document.querySelector('footer')?.remove();
  ''';

  @override
  void initState() {
    super.initState();

    // Preload WebView in the background
    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(linkformonday[widget.index]),
      ),
      initialSettings: InAppWebViewSettings(
        cacheEnabled: true,
        useShouldInterceptRequest: true, // To filter unwanted requests
        javaScriptEnabled: true,
        allowsInlineMediaPlayback: true,
      ),
      onLoadStop: (controller, url) async {
        await controller.evaluateJavascript(source: removeHeaderFooterScript);
      },
    );

    headlessWebView?.run();

    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () async {
            if (await inAppWebViewController?.canGoBack() == true) {
              await inAppWebViewController?.goBack();
            } else {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back_ios_new,color:Color(0xff1B1212),),
        ),
        title: Text(
          englishlevel[widget.indexlevel],
          style: const TextStyle(
            color: Color(0xff1B1212),
            fontWeight: FontWeight.bold,
            fontSize: 30,
          ),
        ),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(
              color:  Color(0xff1B1212),
                 backgroundColor: Colors.white,
            )
            : InAppWebView(
                initialSettings: InAppWebViewSettings(
                  cacheEnabled: true,
                  useShouldInterceptRequest: true, // Block unwanted resources
                  javaScriptEnabled: true,
                  allowsInlineMediaPlayback: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                ),
                onWebViewCreated: (controller) {
                  inAppWebViewController = controller;
                  headlessWebView?.dispose();
                },
                onLoadStop: (controller, url) async {
                  await controller.evaluateJavascript(
                      source: removeHeaderFooterScript);
                },
                initialUrlRequest: URLRequest(
                  url: WebUri(linkformonday[widget.index]),
                ),
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100;
                  });
                },
                shouldInterceptRequest: (controller, request) async {
                  // Block ads & tracking scripts for faster loading
                  if (request.url.toString().contains("ads") ||
                      request.url.toString().contains("tracker")) {
                    return WebResourceResponse(
                      contentType: "text/plain",
                      //data: Uint8List.fromList([]),
                      statusCode: 204, // No Content
                    );
                  }
                  return null;
                },
              ),
      ),
    );
  }
}

List<String> englishlevel = [
  "I Can't Speak",
  "I Can Speak",
  "I Can Speak Fluent",
];

List<String> linkformonday = [
  'https://www.englishspokencafe.com/i-cant-speak-friday/',
  'https://www.englishspokencafe.com/i-can-speak-friday/',
  'https://www.englishspokencafe.com/i-can-speak-f-friday/',
];
