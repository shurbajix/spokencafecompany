import 'package:flutter/material.dart';

class RefreshProvider extends InheritedWidget {
  final Function() refreshCallback;

  const RefreshProvider({
    Key? key,
    required this.refreshCallback,
    required Widget child,
  }) : super(key: key, child: child);

  static RefreshProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RefreshProvider>();
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return true; // Always notify when the refresh callback changes
  }
}
