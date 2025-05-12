import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RouteErrorScreen extends ConsumerStatefulWidget {
  String? ErrorScreen;
  RouteErrorScreen({required this.ErrorScreen, super.key});

  @override
  _RouteErrorScreenState createState() => _RouteErrorScreenState();
}

class _RouteErrorScreenState extends ConsumerState<RouteErrorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Error Router',
        ),
      ),
      body: Center(
        child: Column(
          children: [
            Text(
              widget.ErrorScreen!,
            ),
          ],
        ),
      ),
    );
  }
}
