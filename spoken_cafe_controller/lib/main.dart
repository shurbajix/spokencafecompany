

import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:spoken_cafe_controller/firebase_options.dart';
import 'package:spoken_cafe_controller/model/Screen/Log/Login.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS) {
    // Desktop platforms (Windows, macOS)
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = WindowOptions(
      size: Size(1900, 1300),
      center: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
      minimumSize: Size(1900, 1300),
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } else {
    // Mobile platforms (Android, iOS)
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spoken Cafe Control',
      home: Login(),
    );
  }
}