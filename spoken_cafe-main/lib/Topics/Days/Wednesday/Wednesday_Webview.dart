import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WednesdayWebview extends ConsumerStatefulWidget {
  final int index; // Add an index parameter
  final int indexlevel;

  const WednesdayWebview({
    super.key,
    required this.index, // Require the index to be passed
    required this.indexlevel,
  });

  @override
  ConsumerState<WednesdayWebview> createState() => _WednesdayWebViewState();
}

class _WednesdayWebViewState extends ConsumerState<WednesdayWebview> {
  double _progress = 0;
  InAppWebViewController? inAppWebViewController;
  final String removeHeaderFooterScript = '''
    document.querySelector('header')?.remove();
    document.querySelector('footer')?.remove();
  ''';
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    // Delay for 2 seconds before showing the web view
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false; // Set loading to false after 2 seconds
      });
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () async {
            // Check if the webview can go back
            if (await inAppWebViewController?.canGoBack() == true) {
              // Go back within the webview
              await inAppWebViewController?.goBack();
            } else {
              // If no history is available, navigate back to the previous Flutter screen
              Navigator.pop(context);
            }
          },
          icon: Icon(Icons.arrow_back_ios_new,color: Color(0xff1B1212),),
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
            ? CircularProgressIndicator(
              color:  Color(0xff1B1212),
                                                            backgroundColor: Colors.white,
            )
            : InAppWebView(
                initialSettings: InAppWebViewSettings(
                  mediaPlaybackRequiresUserGesture: false, // Allow autoplay
                  allowsInlineMediaPlayback:
                      true, // Allow inline video playback
                  javaScriptEnabled: true,
                ),
                onLoadStop: (controller, url) async {
                  await controller.evaluateJavascript(
                      source: removeHeaderFooterScript);
                },
                initialUrlRequest: URLRequest(
                  url: WebUri(linkformonday[widget.index]), // Use widget.index
                ),
                onWebViewCreated: (InAppWebViewController controller) {
                  inAppWebViewController = controller;
                },
                onProgressChanged:
                    (InAppWebViewController controller, int progress) {
                  setState(() {
                    _progress = progress / 100;
                  });
                },
              ),
      ),
    );
  }
}

List<String> englishlevel = [
  'I Can\'t Speak',
  'I Can Speak',
  'I Can Speak Fluent',
];

List<String> linkformonday = [
  'https://www.englishspokencafe.com/i-cant-speak-wednesday/',
  'https://www.englishspokencafe.com/i-can-speak-wednesday/',
  'https://www.englishspokencafe.com/i-can-speak-f-wednesday/',
];
