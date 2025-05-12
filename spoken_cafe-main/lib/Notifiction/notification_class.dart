import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize the notification service for both Android and iOS
  Future<void> initNotification() async {
    // Android initialization settings
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings(
      'flutter_icon', // Ensure this icon exists in android/app/src/main/res/drawable
    );

    // iOS initialization settings
    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combine Android and iOS initialization settings
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    // Initialize the notification plugin
    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        // Handle notification tap here (e.g., navigate or log)
      },
    );

    // Android notification channel configuration
    const AndroidNotificationChannel androidNotificationChannel =
        AndroidNotificationChannel(
      'default_channel_id',
      'Default Channel',
      description: 'This is the default notification channel',
      importance: Importance.max,
      playSound: true,
    );

    // Create the Android notification channel
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidNotificationChannel);

    // Listen for foreground messages from Firebase Messaging
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        // Display local notification when a Firebase message is received in the foreground
        notificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          _notificationDetails(icon: 'flutter_icon'),
        );
      }
    });
  }

  // Create notification details for Android and iOS
  NotificationDetails _notificationDetails({String? icon}) {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'default_channel_id',
      'Default Channel',
      importance: Importance.max,
      priority: Priority.high,
      icon: icon ?? 'flutter_icon',
    );

    // iOS notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  // Manual trigger for local notification
  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
    String? icon,
  }) async {
    await notificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails(icon: icon),
      payload: payload,
    );
  }
}
