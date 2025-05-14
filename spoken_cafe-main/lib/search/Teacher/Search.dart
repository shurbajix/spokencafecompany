

// import 'dart:async';
// import 'dart:convert';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
// import 'package:intl/intl.dart';
// import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
// import 'package:spokencafe/Map/Map.dart';
// import 'package:spokencafe/Notifiction/Notifiction.dart';
// import 'package:spokencafe/Notifiction/notification_class.dart';
// import 'package:spokencafe/profile/All_Users_Profile/All_Users_Profile.dart';
// import 'package:spokencafe/search/BottomSheet.dart';

// final authStateProvider = StreamProvider<User?>((ref) {
//   return FirebaseAuth.instance.authStateChanges();
// });

// final lessonsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
//   final firestore = FirebaseFirestore.instance;
//   final user = ref.watch(authStateProvider).value;

//   return firestore
//       .collection('lessons')
//       .where('teacherId', isEqualTo: user?.uid)
//       .orderBy('createdAt', descending: true)
//       .snapshots()
//       .map((snapshot) {
//     return snapshot.docs.map((doc) {
//       final data = doc.data();
//       gmaps.LatLng lessonLocation;

//       // Handle different possible formats of the 'location' field
//       if (data['location'] is GeoPoint) {
//         final geoPoint = data['location'] as GeoPoint;
//         lessonLocation = gmaps.LatLng(geoPoint.latitude, geoPoint.longitude);
//       } else if (data['location'] is Map) {
//         // Handle case where location is stored as a map {latitude: ..., longitude: ...}
//         final locationMap = data['location'] as Map;
//         final latitude = (locationMap['latitude'] as num?)?.toDouble() ?? 0.0;
//         final longitude = (locationMap['longitude'] as num?)?.toDouble() ?? 0.0;
//         lessonLocation = gmaps.LatLng(latitude, longitude);
//       } else if (data['location'] is List) {
//         // Handle case where location is stored as a list [latitude, longitude]
//         final locationList = data['location'] as List;
//         final latitude = (locationList.isNotEmpty ? locationList[0] as num? : 0.0)?.toDouble() ?? 0.0;
//         final longitude = (locationList.length > 1 ? locationList[1] as num? : 0.0)?.toDouble() ?? 0.0;
//         lessonLocation = gmaps.LatLng(latitude, longitude);
//       } else {
//         // Fallback to default coordinates if location format is unrecognized
//         lessonLocation = gmaps.LatLng(0.0, 0.0);
//       }

//       DateTime dateTime = DateTime.now();
//       if (data['dateTime'] is Timestamp) {
//         dateTime = (data['dateTime'] as Timestamp).toDate();
//       } else if (data['dateTime'] is String) {
//         dateTime = DateTime.parse(data['dateTime']);
//       }

//       return {
//         'id': doc.id,
//         'lessonId': doc.id,
//         'speakLevel': data['speakLevel'] ?? '',
//         'dateTime': dateTime,
//         'description': data['description'] ?? '',
//         'teacherId': data['teacherId'] ?? '',
//         'students': data['students'] ?? [],
//         'location': lessonLocation,
//       };
//     }).toList();
//   });
// });

// class Search extends ConsumerStatefulWidget {
//   const Search({super.key});

//   @override
//   ConsumerState<Search> createState() => _SearchState();
// }

// class _SearchState extends ConsumerState<Search> {
//   String? selectedFilter;
//   Timer? countdownTimer;
//   String countdownText = '';
//   double _averageRating = 0.0;
//   final currentUser = FirebaseAuth.instance.currentUser!;

//   @override
//   void dispose() {
//     countdownTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> addLesson(
//       String speakLevel, DateTime dateTime, String description) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     final docRef = FirebaseFirestore.instance.collection('lessons').doc();
//     await docRef.set({
//       'lessonId': docRef.id,
//       'speakLevel': speakLevel,
//       'dateTime': Timestamp.fromDate(dateTime),
//       'description': description,
//       'createdAt': FieldValue.serverTimestamp(),
//       'teacherId': user.uid,
//       'students': [],
//       // Ensure location is stored as a GeoPoint
//       'location': GeoPoint(0.0, 0.0), // Replace with actual coordinates if needed
//     });
//   }

//   void startCountdown(DateTime lessonDateTime) {
//     countdownTimer?.cancel();
//     countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       final now = DateTime.now();
//       final difference = lessonDateTime.difference(now);

//       if (difference.isNegative) {
//         setState(() {
//           countdownText = 'Lesson started!';
//         });
//         timer.cancel();
//       } else {
//         final hours = difference.inHours;
//         final minutes = difference.inMinutes % 60;
//         final seconds = difference.inSeconds % 60;

//         setState(() {
//           countdownText =
//               'Lesson starts in: ${hours.toString().padLeft(2, '0')}:'
//               '${minutes.toString().padLeft(2, '0')}:'
//               '${seconds.toString().padLeft(2, '0')}';
//         });
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final lessonsStream = ref.watch(lessonsStreamProvider);

//     return Scaffold(
//       appBar: AppBar(
//         shadowColor: Colors.transparent,
//         backgroundColor: Colors.transparent,
//         title: Text('Search',style: TextStyle(
//           fontSize: 30,
          
//           fontWeight: FontWeight.bold,
//           color:  Color(0xff1B1212),
//         ),),
//       ),
//       backgroundColor: Colors.white,
//       floatingActionButton: FloatingActionButton.extended(
//         label: const Text(
//           'Create Lesson',
//           style: TextStyle(color: Colors.white),
//         ),
//         backgroundColor: const Color(0xff1B1212),
//         heroTag: 'btn2',
//         onPressed: () {
//           showModalBottomSheet(
//             backgroundColor: Colors.white,
//             isScrollControlled: true,
//             context: context,
//             builder: (BuildContext context) {
//               return MyBottomSheet(
//                 onSave: (String speakLevel, DateTime dateTime,
//                     String description, String minute) {
//                   addLesson(speakLevel, dateTime, description);
//                   startCountdown(dateTime);
//                 },
//               );
//             },
//           );
//         },
//         icon: const Icon(Icons.add, color: Colors.white),
//       ),
//       body: lessonsStream.when(
//         data: (lessons) {
//           final filteredLessons = selectedFilter == null
//               ? lessons
//               : lessons
//                   .where((item) => item['speakLevel'] == selectedFilter)
//                   .toList();

//           if (filteredLessons.isEmpty) {
//             return const SafeArea(
//               child: Center(
//                 child: Text(
//                   'No Lessons',
//                   style: TextStyle(
//                     fontSize: 20,
//                     color: Color(0xff1B1212),
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             );
//           }

//           return SafeArea(
//             child: ListView.builder(
//               shrinkWrap: true,
//               itemCount: filteredLessons.length,
//               itemBuilder: (context, index) {
//                 if (index >= filteredLessons.length) {
//                   return const SizedBox.shrink();
//                 }

//                 final item = filteredLessons[index];
//                 final lessonLocation = item['location'] as gmaps.LatLng;
//                 final teacherId = item['teacherId'];

//                 return InkWell(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       PageRouteBuilder(
//                         pageBuilder: (context, animation, secondaryAnimation) =>
//                             AllUsersProfile(userId: teacherId),
//                         transitionsBuilder: (
//                           context,
//                           animation,
//                           secondaryAnimation,
//                           child,
//                         ) {
//                           const begin = Offset(1.0, 0.0);
//                           const end = Offset.zero;
//                           const curve = Curves.easeInOut;
//                           var tween = Tween(begin: begin, end: end)
//                               .chain(CurveTween(curve: curve));
//                           return SlideTransition(
//                             position: animation.drive(tween),
//                             child: child,
//                           );
//                         },
//                       ),
//                     );
//                   },
//                   child: Container(
//                     margin: const EdgeInsets.symmetric(
//                       horizontal: 10,
//                       vertical: 10,
//                     ),
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(10),
//                       color: Colors.white,
//                       boxShadow: const [
//                         BoxShadow(
//                           color: Colors.grey,
//                           offset: Offset(0.0, 1.0),
//                           blurRadius: 6.0,
//                         ),
//                       ],
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.stretch,
//                         children: [
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Row(
//                                 children: [
//                                   InkWell(
//                                     onTap: () {},
//                                     child: StreamBuilder<DocumentSnapshot>(
//                                       stream: FirebaseFirestore.instance
//                                           .collection('users')
//                                           .doc(currentUser.uid)
//                                           .snapshots(),
//                                       builder: (context, snapshot) {
//                                         if (snapshot.hasData &&
//                                             snapshot.data!.exists) {
//                                           final userData = snapshot.data!.data()
//                                               as Map<String, dynamic>;
//                                           final imageUrl =
//                                               userData['profileImageUrl'] ?? '';

//                                           if (imageUrl.isNotEmpty) {
//                                             return CircleAvatar(
//                                               radius: 25,
//                                               backgroundImage:
//                                                   NetworkImage(imageUrl),
//                                               backgroundColor: Colors.grey,
//                                             );
//                                           }
//                                         }

//                                         return CircleAvatar(
//                                           radius: 25,
//                                           backgroundColor: Colors.grey[100],
//                                           child: Icon(Icons.person,
//                                               color: Colors.white),
//                                         );
//                                       },
//                                     ),
//                                   ),
//                                   const SizedBox(width: 9),
//                                   Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         currentUser.displayName!,
//                                         style: const TextStyle(
//                                           fontWeight: FontWeight.bold,
//                                           color: Color(0xff1B1212),
//                                         ),
//                                       ),
//                                       const SizedBox(height: 5),
//                                       Row(
//                                         children: [
//                                           const Icon(Icons.star,
//                                               color: Colors.yellow),
//                                           const SizedBox(width: 8),
//                                           Text(
//                                             _averageRating.toStringAsFixed(1),
//                                             style: const TextStyle(
//                                               fontSize: 16,
//                                               color: Color(0xff1B1212),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 '${item['speakLevel']}',
//                                 style: const TextStyle(
//                                   fontSize: 20,
//                                   color: Color(0xff1B1212),
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               IconButton(
//                                 onPressed: () {
//                                   Navigator.push(
//                                     context,
//                                     PageRouteBuilder(
//                                       pageBuilder: (context, animation,
//                                               secondaryAnimation) =>
//                                           MapScreen(
//                                               lessonTitle:
//                                                   item['speakLevel'] ??
//                                                       'Lesson Location',
//                                               teacherName:
//                                                   item['teacherName'] ??
//                                                       'Teacher',
//                                               savedLocation: lessonLocation),
//                                       transitionsBuilder: (context, animation,
//                                           secondaryAnimation, child) {
//                                         const begin = Offset(1.0, 0.0);
//                                         const end = Offset.zero;
//                                         const curve = Curves.easeInOut;
//                                         var tween = Tween(begin: begin, end: end)
//                                             .chain(CurveTween(curve: curve));
//                                         return SlideTransition(
//                                           position: animation.drive(tween),
//                                           child: child,
//                                         );
//                                       },
//                                     ),
//                                   );
//                                 },
//                                 icon: Image.asset(
//                                   'assets/images/maps.png',
//                                   scale: 13.8,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 20),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 DateFormat('yyyy/MM/dd hh:mm a')
//                                     .format(item['dateTime']),
//                                 style: const TextStyle(
//                                   color: Color(0xff1B1212),
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               if (countdownText.isNotEmpty)
//                                 Padding(
//                                   padding: const EdgeInsets.only(top: 16.0),
//                                   child: Text(
//                                     countdownText,
//                                     style: const TextStyle(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.bold,
//                                       color: Color(0xff1B1212),
//                                     ),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                           const SizedBox(height: 20),
//                           Text(
//                             '${item['description']}',
//                             style: const TextStyle(
//                               color: Color(0xff1B1212),
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           );
//         },
//         loading: () => const SafeArea(
//           child: Center(child: CircularProgressIndicator(
//              color:  Color(0xff1B1212),
//              backgroundColor: Colors.white,
//           ),),
//         ),
//         error: (error, stackTrace) => SafeArea(
//           child: Center(child: Text('Error: $error')),
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:spokencafe/Map/Map.dart';
import 'package:spokencafe/Notifiction/Notifiction.dart';
import 'package:spokencafe/Notifiction/notification_class.dart';
import 'package:spokencafe/profile/All_Users_Profile/All_Users_Profile.dart';
import 'package:spokencafe/search/BottomSheet.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final lessonsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final firestore = FirebaseFirestore.instance;
  final user = ref.watch(authStateProvider).value;

  if (user == null) {
    return Stream.value([]);
  }

  return firestore
      .collection('lessons')
      .where('teacherId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      gmaps.LatLng lessonLocation;

      // Handle different possible formats of the 'location' field
      if (data['location'] is GeoPoint) {
        final geoPoint = data['location'] as GeoPoint;
        lessonLocation = gmaps.LatLng(geoPoint.latitude, geoPoint.longitude);
      } else if (data['location'] is Map) {
        final locationMap = data['location'] as Map;
        final latitude = (locationMap['latitude'] as num?)?.toDouble() ?? 0.0;
        final longitude = (locationMap['longitude'] as num?)?.toDouble() ?? 0.0;
        lessonLocation = gmaps.LatLng(latitude, longitude);
      } else if (data['location'] is List) {
        final locationList = data['location'] as List;
        final latitude = (locationList.isNotEmpty ? locationList[0] as num? : 0.0)?.toDouble() ?? 0.0;
        final longitude = (locationList.length > 1 ? locationList[1] as num? : 0.0)?.toDouble() ?? 0.0;
        lessonLocation = gmaps.LatLng(latitude, longitude);
      } else {
        lessonLocation = gmaps.LatLng(0.0, 0.0);
      }

      DateTime dateTime = DateTime.now();
      if (data['dateTime'] is Timestamp) {
        dateTime = (data['dateTime'] as Timestamp).toDate();
      } else if (data['dateTime'] is String) {
        dateTime = DateTime.parse(data['dateTime']);
      }

      return {
        'id': doc.id,
        'lessonId': doc.id,
        'speakLevel': data['speakLevel'] ?? '',
        'dateTime': dateTime,
        'description': data['description'] ?? '',
        'teacherId': data['teacherId'] ?? '',
        'students': data['students'] ?? [],
        'location': lessonLocation,
      };
    }).toList();
  }).handleError((error, stackTrace) {
    print('Firestore query error in lessonsStreamProvider: $error');
    print('Stack trace: $stackTrace');
    return [];
  });
});

class Search extends ConsumerStatefulWidget {
  const Search({super.key});

  @override
  ConsumerState<Search> createState() => _SearchState();
}

class _SearchState extends ConsumerState<Search> {
  String? selectedFilter;
  double _averageRating = 0.0;
  final currentUser = FirebaseAuth.instance.currentUser!;
  final Map<String, Timer> _countdownTimers = {}; // Track timers per lesson
  final Map<String, String> _countdownTexts = {}; // Track countdown text per lesson

  @override
  void dispose() {
    // Cancel all timers
    _countdownTimers.forEach((_, timer) => timer.cancel());
    _countdownTimers.clear();
    super.dispose();
  }

  Future<void> addLesson(
      String speakLevel, DateTime dateTime, String description) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('lessons').doc();
      await docRef.set({
        'lessonId': docRef.id,
        'speakLevel': speakLevel,
        'dateTime': Timestamp.fromDate(dateTime),
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'teacherId': user.uid,
        'students': [],
        'location': GeoPoint(0.0, 0.0), // Replace with actual coordinates if needed
      });
      // Start countdown with the correct lessonId
      startCountdown(dateTime, docRef.id);
    } catch (e, stackTrace) {
      print('Error adding lesson: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add lesson: $e')),
        );
      }
    }
  }

  Future<void> deleteLesson(String lessonId) async {
    try {
      await FirebaseFirestore.instance.collection('lessons').doc(lessonId).delete();
      // Clean up timer and countdown text
      _countdownTimers.remove(lessonId)?.cancel();
      _countdownTexts.remove(lessonId);
    } catch (e, stackTrace) {
      print('Error deleting lesson $lessonId: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete lesson: $e')),
        );
      }
    }
  }

  void startCountdown(DateTime lessonDateTime, String lessonId) {
    // Cancel any existing timer for this lesson
    _countdownTimers[lessonId]?.cancel();

    const lessonDuration = Duration(hours: 2); // 2-hour lessons
    final endTime = lessonDateTime.add(lessonDuration);

    final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final difference = endTime.difference(now);

      if (difference.isNegative) {
        if (mounted) {
          setState(() {
            _countdownTexts[lessonId] = 'Lesson completed!';
          });
        }
        // Delete the lesson when it ends
        deleteLesson(lessonId);
        timer.cancel();
      } else {
        final hours = difference.inHours;
        final minutes = difference.inMinutes % 60;
        final seconds = difference.inSeconds % 60;

        if (mounted) {
          setState(() {
            _countdownTexts[lessonId] = '${hours.toString().padLeft(2, '0')}:'
                '${minutes.toString().padLeft(2, '0')}:'
                '${seconds.toString().padLeft(2, '0')}';
          });
        }
      }
    });

    _countdownTimers[lessonId] = timer;
  }

  @override
  Widget build(BuildContext context) {
    final lessonsStream = ref.watch(lessonsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        shadowColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Search',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Color(0xff1B1212),
          ),
        ),
      ),
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        label: const Text(
          'Create Lesson',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xff1B1212),
        heroTag: 'btn2',
        onPressed: () {
          showModalBottomSheet(
            backgroundColor: Colors.white,
            isScrollControlled: true,
            context: context,
            builder: (BuildContext context) {
              return MyBottomSheet(
                onSave: (String speakLevel, DateTime dateTime, String description, String minute) {
                  addLesson(speakLevel, dateTime, description);
                },
              );
            },
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      body: lessonsStream.when(
        data: (lessons) {
          final filteredLessons = selectedFilter == null
              ? lessons
              : lessons.where((item) => item['speakLevel'] == selectedFilter).toList();

          if (filteredLessons.isEmpty) {
            return const SafeArea(
              child: Center(
                child: Text(
                  'No Lessons',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xff1B1212),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }

          return SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filteredLessons.length,
              itemBuilder: (context, index) {
                if (index >= filteredLessons.length) {
                  return const SizedBox.shrink();
                }

                final item = filteredLessons[index];
                final lessonId = item['id'] as String;
                final lessonLocation = item['location'] as gmaps.LatLng;
                final teacherId = item['teacherId'];
                final lessonDateTime = item['dateTime'] as DateTime;

                // Start countdown only if not already started
                if (!_countdownTimers.containsKey(lessonId)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    startCountdown(lessonDateTime, lessonId);
                  });
                }

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            AllUsersProfile(userId: teacherId),
                        transitionsBuilder: (
                          context,
                          animation,
                          secondaryAnimation,
                          child,
                        ) {
                          const begin = Offset(1.0, 0.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;
                          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.grey,
                          offset: Offset(0.0, 1.0),
                          blurRadius: 6.0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {},
                                    child: StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(currentUser.uid)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData && snapshot.data!.exists) {
                                          final userData = snapshot.data!.data() as Map<String, dynamic>;
                                          final imageUrl = userData['profileImageUrl'] ?? '';

                                          if (imageUrl.isNotEmpty) {
                                            return CircleAvatar(
                                              radius: 25,
                                              backgroundImage: NetworkImage(imageUrl),
                                              backgroundColor: Colors.grey,
                                            );
                                          }
                                        }

                                        return CircleAvatar(
                                          radius: 25,
                                          backgroundColor: Colors.grey[100],
                                          child: const Icon(Icons.person, color: Colors.white),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentUser.displayName ?? 'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xff1B1212),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.yellow),
                                          const SizedBox(width: 8),
                                          Text(
                                            _averageRating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xff1B1212),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['speakLevel'] ?? 'Not specified',
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Color(0xff1B1212),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          MapScreen(
                                        lessonTitle: item['speakLevel'] ?? 'Lesson Location',
                                        teacherName: item['teacherName'] ?? 'Teacher',
                                        savedLocation: lessonLocation,
                                      ),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOut;
                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        return SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                icon: Image.asset(
                                  'assets/images/maps.png',
                                  scale: 13.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('yyyy/MM/dd hh:mm a').format(lessonDateTime),
                                style: const TextStyle(
                                  color: Color(0xff1B1212),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_countdownTexts[lessonId]?.isNotEmpty ?? false)
                                Padding(
                                  padding: const EdgeInsets.only(left: 20,right: 10),
                                  child: Text(
                                    _countdownTexts[lessonId] ?? '',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff1B1212),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            item['description'] ?? 'No description',
                            style: const TextStyle(
                              color: Color(0xff1B1212),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              color: Color(0xff1B1212),
              backgroundColor: Colors.white,
            ),
          ),
        ),
        error: (error, stackTrace) {
          print('Error in lessonsStreamProvider: $error');
          print('Stack trace: $stackTrace');
          String errorMessage = 'Failed to load lessons: $error';
          if (error.toString().contains('requires an index')) {
            errorMessage =
                'A database index is required to load lessons.\nPlease contact the app administrator to create the index using the URL in the debug console.';
            print('INDEX ERROR: The query requires a composite index. Check the debug console for the URL.');
          }
          return SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xff1B1212),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(lessonsStreamProvider); // Retry the query
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}