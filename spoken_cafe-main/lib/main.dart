import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:spokencafe/Credit_Card/Credit_key.dart';
import 'package:spokencafe/Credit_Card/Cresit_Api.dart';
import 'package:spokencafe/Notifiction/notification_class.dart';
import 'package:spokencafe/firebase_options.dart';
import 'router/go_router_provider.dart';

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // You can show a notification or process data
  print("🔥 Handling background message: ${message.messageId}",);

}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StripeService.instance.initialize();
    try {
    await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
     await Stripe.instance.applySettings();
  } catch (e) {
    print('Firebase init error: $e');
  }
// here will add something for storage FirebaseStorage.instance.setLoggingEnabled(true);
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notification service
  await NotificationService().initNotification();
  // those add this things

  // Ask notification permissions (important for iOS)
  await FirebaseMessaging.instance.requestPermission();
  await _setup();
  await Geolocator.checkPermission();
  final bool isLoggedIn = await _checkLoginStatus();
  runApp(
    ProviderScope(
      overrides: [
        isLoggedInProvider.overrideWithValue(isLoggedIn),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _setup() async {
  Stripe.publishableKey = stripPublishKey;
}

/// Checks if the user is already logged in
Future<bool> _checkLoginStatus() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isLoggedIn') ?? false;
}

final isLoggedInProvider = Provider<bool>((ref) => false);

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateThemeMode();

    // Optional: Listen to notification tap (when app in background or terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handle navigation based on the message data
      print("📬 Notification tapped: ${message.data}");
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _updateThemeMode();
  }

  void _updateThemeMode() {
    setState(() {
      _themeMode = ThemeMode.system;
    });
  }

  ThemeData _customLightTheme() {
    return ThemeData.light().copyWith(
      colorScheme: const ColorScheme.light(
        primary: Colors.green,
        secondary: Colors.orangeAccent,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        color: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
      ),
    );
  }

  ThemeData _customDarkTheme() {
    return ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xff1F1F39),
        secondary: Color(0xff1F1F39),
        surface: Color(0xff1F1F39),
        onPrimary: Color(0xff1F1F39),
        onSecondary: Color(0xff1F1F39),
        onSurface: Color(0xff1F1F39),
      ),
      appBarTheme: const AppBarTheme(
        color: Color(0xff1F1F39),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xff1F1F39)),
        bodyMedium: TextStyle(color: Color(0xff1F1F39)),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = ref.watch(isLoggedInProvider);
    final GoRouter goRouter = ref.watch(getRouterProvider);
    return MaterialApp.router(
      routeInformationParser: goRouter.routeInformationParser,
      routeInformationProvider: goRouter.routeInformationProvider,
      routerDelegate: goRouter.routerDelegate,
      debugShowCheckedModeBanner: false,
      title: 'Spoken Cafe',
      // theme: _customLightTheme(),
      // darkTheme: _customDarkTheme(),
      // themeMode: _themeMode,
    );
  }
}
