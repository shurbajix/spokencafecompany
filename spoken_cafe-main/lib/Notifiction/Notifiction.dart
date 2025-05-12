// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// class Notifiction extends ConsumerStatefulWidget {
//   const Notifiction({
//     super.key,
//   });

//   @override
//   ConsumerState<Notifiction> createState() => _NotifictionState();
// }

// class _NotifictionState extends ConsumerState<Notifiction> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         leading: IconButton(
//           onPressed: () {
//             Navigator.pop(context);
//           },
//           icon: Icon(
//             Icons.arrow_back_ios_new,
//           ),
//         ),
//         title: const Text(
//           'Notifiction',
//         ),
//         centerTitle: true,
//       ),
//       body: ListView.builder(
//         shrinkWrap: true,
//         itemCount: 100,
//         itemBuilder: (context, index) {
//           return Container(
//             margin: EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: Colors.grey[700],
//               borderRadius: BorderRadius.circular(5),
//             ),
//             child: ListTile(
//               trailing: Text(
//                 'Taken',
//                 style: TextStyle(
//                   color: Colors.green,
//                   fontSize: 15,
//                 ),
//               ),
//               leading: Icon(
//                 Icons.check,
//                 color: Colors.green[600],
//               ),
//               title: Text(
//                 'Lesscons is Take',
//                 style: TextStyle(
//                   color: Colors.white,
//                 ),
//               ),
//               subtitle: Text(
//                 'the lesccons is take for Time:10:30 and Date:12/20',
//                 style: TextStyle(
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
// // Icons.cancel,color: Colors.red,
// // Icons.check,color: Colors.green[600],
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Notifiction extends ConsumerStatefulWidget {
  const Notifiction({super.key});

  @override
  ConsumerState<Notifiction> createState() => _NotifictionState();
}

class _NotifictionState extends ConsumerState<Notifiction> {
  List<LocalNotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notifications = await NotificationStorage.getNotifications();
    setState(() {
      _notifications = notifications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new,color:Color(0xff1B1212),),
        ),
        title: const Text('Notification',style: TextStyle(
          color: Color(0xff1B1212),
          fontWeight: FontWeight.bold,
        ),),
        centerTitle: true,
      ),
      body: _notifications.isEmpty
          ? const Center(child: Text("No notifications yet."))
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final item = _notifications[index];
                return Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xff1B1212),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: ListTile(
                    trailing: Text(
                      timeAgo(item.timestamp),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    leading: Icon(Icons.notifications_active,
                        color: Colors.green[600]),
                    title: Text(item.title,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(item.body,
                        style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
    );
  }

  String timeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hrs ago';
    return '${diff.inDays} days ago';
  }
}
// here will add those

class NotificationStorage {
  static const _key = 'local_notifications';

  static Future<void> addNotification(
      LocalNotificationModel notification) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getNotifications();

    list.insert(0, notification); // Add new to top
    final jsonList = list.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  static Future<List<LocalNotificationModel>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList
        .map((item) => LocalNotificationModel.fromJson(jsonDecode(item)))
        .toList();
  }
}

class LocalNotificationModel {
  final String title;
  final String body;
  final DateTime timestamp;

  LocalNotificationModel({
    required this.title,
    required this.body,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LocalNotificationModel.fromJson(Map<String, dynamic> json) {
    return LocalNotificationModel(
      title: json['title'],
      body: json['body'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
