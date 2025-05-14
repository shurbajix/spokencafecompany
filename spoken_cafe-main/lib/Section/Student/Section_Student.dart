import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spokencafe/Notifiction/Notifiction.dart';
import 'package:spokencafe/Notifiction/notification_class.dart';
import 'package:spokencafe/profile/All_Users_Profile/All_Users_Profile.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:spokencafe/Map/Map.dart';

final sectionItemsProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final selectedIndexProvider = StateProvider<int?>((ref) => null);

class SectionStudent extends ConsumerStatefulWidget {
  const SectionStudent({super.key});

  @override
  ConsumerState<SectionStudent> createState() => _SectionStudentState();
}

class _SectionStudentState extends ConsumerState<SectionStudent> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  double _averageRating = 0.0;
  bool _hasProcessedInitialLoad = false;
  final Set<String> _shownDialogs = {};
  bool _hasLoggedIndexError = false; // Track if index error was logged

  @override
  void initState() {
    super.initState();
    _loadSavedItems();
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final items = ref.read(sectionItemsProvider);
    final jsonString = jsonEncode(items);
    await prefs.setString('savedItems', jsonString);
  }

  Future<void> _loadSavedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('savedItems');
    if (jsonString != null) {
      final items = jsonDecode(jsonString) as List<dynamic>;
      ref.read(sectionItemsProvider.notifier).update((_) =>
          items.map((item) => item as Map<String, dynamic>).toList());
    }
  }

  DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime is Timestamp) return dateTime.toDate();
    if (dateTime is String) return DateTime.parse(dateTime);
    return DateTime.now();
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '00:00:00';

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Widget _buildAnimatedDigit(String digit) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.5),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Text(
        digit,
        key: ValueKey<String>(digit),
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildTimer(Duration remaining) {
    final timeString = _formatDuration(remaining);
    final parts = timeString.split(':');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAnimatedDigit(parts[0][0]),
        _buildAnimatedDigit(parts[0][1]),
        const Text(":", style: TextStyle(color: Colors.red, fontSize: 18)),
        _buildAnimatedDigit(parts[1][0]),
        _buildAnimatedDigit(parts[1][1]),
        const Text(":", style: TextStyle(color: Colors.red, fontSize: 18)),
        _buildAnimatedDigit(parts[2][0]),
        _buildAnimatedDigit(parts[2][1]),
      ],
    );
  }

  dynamic _parseLocation(dynamic locationData) {
    if (locationData == null) {
      print('Location data is null');
      return null;
    }

    if (locationData is GeoPoint) {
      return locationData;
    }

    if (locationData is gmaps.LatLng) {
      return locationData;
    }

    if (locationData is Map) {
      try {
        final lat = locationData['latitude']?.toDouble();
        final lng = locationData['longitude']?.toDouble();
        if (lat != null && lng != null) {
          return GeoPoint(lat, lng);
        }
      } catch (e) {
        print('Error parsing location map: $e');
      }
    }

    print('Invalid location data format: $locationData');
    return null;
  }

  void _showRatingDialog(Map<String, dynamic> item, String lessonId) {
    if (_shownDialogs.contains(lessonId)) return;
    _shownDialogs.add(lessonId);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialogRating(
          teacherId: item['teacherId'],
          lessonId: lessonId,
          onRatingSubmitted: (avg) async {
            setState(() => _averageRating = avg);
            // Mark the lesson as rated in Firestore
            try {
              await FirebaseFirestore.instance
                  .collection('takenLessons')
                  .doc(lessonId)
                  .update({'isRated': true});
            } catch (e, stackTrace) {
              print('Error updating isRated for lesson $lessonId: $e');
              print('Stack trace: $stackTrace');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save rating: $e')),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text(
          'Section',
          style: TextStyle(
            fontSize: 30,
            color: Color(0xff1B1212),
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('takenLessons')
            .where('studentId', isEqualTo: currentUser.uid)
            .where('isRated', isNotEqualTo: true)
            .orderBy('dateTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xff1B1212),
                backgroundColor: Colors.white,
              ),
            );
          }

          if (snapshot.hasError) {
            // Log error only once to avoid terminal spam
            if (!_hasLoggedIndexError) {
              print('Firestore query error: ${snapshot.error}');
              print('Stack trace: ${snapshot.stackTrace}');
              if (snapshot.error.toString().contains('requires an index')) {
                print(
                    'INDEX ERROR: The query requires a composite index. Follow the URL provided above to create it in the Firebase Console.');
              }
              _hasLoggedIndexError = true; // Prevent repeated logging
            }
            String errorMessage = 'Failed to load lessons: ${snapshot.error}';
            if (snapshot.error.toString().contains('requires an index')) {
              errorMessage =
                  'A database index is required to load lessons.\nPlease contact the app administrator to create the index using the URL in the debug console.';
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xff1B1212),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasLoggedIndexError = false; // Allow re-logging on retry
                        }); // Trigger rebuild to retry
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final takenLessons = snapshot.data?.docs ?? [];
          // Filter lessons to show only those that haven't ended
          final filteredLessons = takenLessons.where((doc) {
            final item = doc.data() as Map<String, dynamic>;
            final lessonDateTime = _parseDateTime(item['dateTime']);
            final endTime = lessonDateTime.add(const Duration(hours: 2));
            final now = DateTime.now();
            return endTime.isAfter(now);
          }).toList();

          if (!_hasProcessedInitialLoad) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              for (var doc in filteredLessons) {
                final lessonId = doc.id;
                final item = doc.data() as Map<String, dynamic>;
                final lessonDateTime = _parseDateTime(item['dateTime']);
                final endTime = lessonDateTime.add(const Duration(hours: 2));
                final now = DateTime.now();
                final remaining = endTime.difference(now);

                if (remaining.isNegative && (item['isRated'] != true)) {
                  _showRatingDialog(item, lessonId);
                }
              }
              _hasProcessedInitialLoad = true;
            });
          }

          if (filteredLessons.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'No Upcoming Lessons',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xff1B1212),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredLessons.length,
            itemBuilder: (context, index) {
              final doc = filteredLessons[index];
              final item = doc.data() as Map<String, dynamic>;
              final lessonId = doc.id;
              final lessonDateTime = _parseDateTime(item['dateTime']);
              final endTime = lessonDateTime.add(const Duration(hours: 2));

              return StreamBuilder<DateTime>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (_) => DateTime.now(),
                ),
                builder: (context, timeSnapshot) {
                  final now = timeSnapshot.data ?? DateTime.now();
                  final remaining = endTime.difference(now);

                  if (remaining.isNegative &&
                      (item['isRated'] != true) &&
                      !_shownDialogs.contains(lessonId)) {
                    _shownDialogs.add(lessonId);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showRatingDialog(item, lessonId);
                    });
                  }

                  return Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.grey,
                          offset: Offset(0.0, 1.0),
                          blurRadius: 6.0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10, top: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation,
                                              secondaryAnimation) =>
                                          AllUsersProfile(
                                              userId: item['teacherId']),
                                      transitionsBuilder: (context, animation,
                                          secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOut;
                                        var tween = Tween(
                                                begin: begin, end: end)
                                            .chain(CurveTween(curve: curve));
                                        return SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(item['teacherId'])
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData &&
                                            snapshot.data!.exists) {
                                          final userData = snapshot.data!.data()
                                              as Map<String, dynamic>;
                                          final imageUrl =
                                              userData['profileImageUrl'] ??
                                                  '';

                                          if (imageUrl.isNotEmpty) {
                                            return CircleAvatar(
                                              radius: 25,
                                              backgroundImage:
                                                  NetworkImage(imageUrl),
                                              backgroundColor: Colors.grey,
                                            );
                                          }
                                        }

                                        return CircleAvatar(
                                          radius: 25,
                                          backgroundColor: Colors.grey[100],
                                          child: const Icon(Icons.person,
                                              color: Colors.white),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['teacherName'] ??
                                              'Unknown Teacher',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xff1B1212),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        InkWell(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => AlertDialogRating(
                                                teacherId: item['teacherId'],
                                                onRatingSubmitted: (avg) async {
                                                  setState(() {
                                                    _averageRating = avg;
                                                  });
                                                  // Mark the lesson as rated in Firestore
                                                  try {
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection(
                                                            'takenLessons')
                                                        .doc(lessonId)
                                                        .update(
                                                            {'isRated': true});
                                                  } catch (e, stackTrace) {
                                                    print(
                                                        'Error updating isRated for lesson $lessonId: $e');
                                                    print(
                                                        'Stack trace: $stackTrace');
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              'Failed to save rating: $e')),
                                                    );
                                                  }
                                                },
                                                lessonId: lessonId,
                                              ),
                                            );
                                          },
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.yellow,
                                              ),
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
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
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
                                onPressed: () async {
                                  final locationData = item['location'];
                                  print('Raw location data: $locationData');

                                  final parsedLocation =
                                      _parseLocation(locationData);
                                  print('Parsed location: $parsedLocation');

                                  if (parsedLocation == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'This lesson has no valid location data'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }

                                  final latLng = parsedLocation is GeoPoint
                                      ? gmaps.LatLng(parsedLocation.latitude,
                                          parsedLocation.longitude)
                                      : parsedLocation as gmaps.LatLng;

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MapScreen(
                                        savedLocation: latLng,
                                        lessonTitle:
                                            item['speakLevel'] ?? 'Lesson Location',
                                        teacherName:
                                            item['teacherName'] ?? 'Teacher',
                                      ),
                                    ),
                                  );
                                },
                                icon: Image.asset('assets/images/maps.png',
                                    scale: 13.8),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            item['description'] ?? 'No description available',
                            style: const TextStyle(
                              color: Color(0xff1B1212),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Starts: ${DateFormat('yyyy/MM/dd hh:mm a').format(lessonDateTime)}',
                                style: const TextStyle(
                                  color: Color(0xff1B1212),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: remaining.isNegative
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      color: remaining.isNegative
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    remaining.isNegative
                                        ? const Text(
                                            'Completed',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          )
                                        : _buildTimer(remaining),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
// import 'dart:async';
// import 'dart:convert';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:spokencafe/Notifiction/Notifiction.dart';
// import 'package:spokencafe/Notifiction/notification_class.dart';
// import 'package:spokencafe/profile/All_Users_Profile/All_Users_Profile.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
// import 'package:spokencafe/Map/Map.dart';

// final sectionItemsProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
// final selectedIndexProvider = StateProvider<int?>((ref) => null);

// class SectionStudent extends ConsumerStatefulWidget {
//   const SectionStudent({super.key});

//   @override
//   ConsumerState<SectionStudent> createState() => _SectionStudentState();
// }

// class _SectionStudentState extends ConsumerState<SectionStudent> {
//   final currentUser = FirebaseAuth.instance.currentUser!;
//   double _averageRating = 0.0;
//   bool _hasProcessedInitialLoad = false;
//   final Set<String> _shownDialogs = {};
//   bool _hasLoggedIndexError = false; // Track if index error was logged

//   @override
//   void initState() {
//     super.initState();
//     _loadSavedItems();
//   }

//   Future<void> _saveItems() async {
//     final prefs = await SharedPreferences.getInstance();
//     final items = ref.read(sectionItemsProvider);
//     final jsonString = jsonEncode(items);
//     await prefs.setString('savedItems', jsonString);
//   }

//   Future<void> _loadSavedItems() async {
//     final prefs = await SharedPreferences.getInstance();
//     final jsonString = prefs.getString('savedItems');
//     if (jsonString != null) {
//       final items = jsonDecode(jsonString) as List<dynamic>;
//       ref.read(sectionItemsProvider.notifier).update((_) =>
//           items.map((item) => item as Map<String, dynamic>).toList());
//     }
//   }

//   DateTime _parseDateTime(dynamic dateTime) {
//     if (dateTime is Timestamp) return dateTime.toDate();
//     if (dateTime is String) return DateTime.parse(dateTime);
//     return DateTime.now();
//   }

//   String _formatDuration(Duration duration) {
//     if (duration.isNegative) return '00:00:00';

//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     final hours = twoDigits(duration.inHours);
//     final minutes = twoDigits(duration.inMinutes.remainder(60));
//     final seconds = twoDigits(duration.inSeconds.remainder(60));
//     return '$hours:$minutes:$seconds';
//   }

//   Widget _buildAnimatedDigit(String digit) {
//     return AnimatedSwitcher(
//       duration: const Duration(milliseconds: 300),
//       transitionBuilder: (Widget child, Animation<double> animation) {
//         return SlideTransition(
//           position: Tween<Offset>(
//             begin: const Offset(0.0, 0.5),
//             end: Offset.zero,
//           ).animate(animation),
//           child: FadeTransition(
//             opacity: animation,
//             child: child,
//           ),
//         );
//       },
//       child: Text(
//         digit,
//         key: ValueKey<String>(digit),
//         style: const TextStyle(
//           color: Colors.red,
//           fontWeight: FontWeight.bold,
//           fontSize: 18,
//         ),
//       ),
//     );
//   }

//   Widget _buildTimer(Duration remaining) {
//     final timeString = _formatDuration(remaining);
//     final parts = timeString.split(':');

//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         _buildAnimatedDigit(parts[0][0]),
//         _buildAnimatedDigit(parts[0][1]),
//         const Text(":", style: TextStyle(color: Colors.red, fontSize: 18)),
//         _buildAnimatedDigit(parts[1][0]),
//         _buildAnimatedDigit(parts[1][1]),
//         const Text(":", style: TextStyle(color: Colors.red, fontSize: 18)),
//         _buildAnimatedDigit(parts[2][0]),
//         _buildAnimatedDigit(parts[2][1]),
//       ],
//     );
//   }

//   dynamic _parseLocation(dynamic locationData) {
//     if (locationData == null) {
//       print('Location data is null');
//       return null;
//     }

//     if (locationData is GeoPoint) {
//       return locationData;
//     }

//     if (locationData is gmaps.LatLng) {
//       return locationData;
//     }

//     if (locationData is Map) {
//       try {
//         final lat = locationData['latitude']?.toDouble();
//         final lng = locationData['longitude']?.toDouble();
//         if (lat != null && lng != null) {
//           return GeoPoint(lat, lng);
//         }
//       } catch (e) {
//         print('Error parsing location map: $e');
//       }
//     }

//     print('Invalid location data format: $locationData');
//     return null;
//   }

//   void _showRatingDialog(Map<String, dynamic> item, String lessonId) {
//     if (_shownDialogs.contains(lessonId)) return;
//     _shownDialogs.add(lessonId);

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => WillPopScope(
//         onWillPop: () async => false,
//         child: AlertDialogRating(
//           teacherId: item['teacherId'],
//           lessonId: lessonId,
//           onRatingSubmitted: (avg) async {
//             setState(() => _averageRating = avg);
//             // Mark the lesson as rated in Firestore
//             try {
//               await FirebaseFirestore.instance
//                   .collection('takenLessons')
//                   .doc(lessonId)
//                   .update({'isRated': true});
//             } catch (e, stackTrace) {
//               print('Error updating isRated for lesson $lessonId: $e');
//               print('Stack trace: $stackTrace');
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('Failed to save rating: $e')),
//               );
//             }
//           },
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         centerTitle: true,
//         backgroundColor: Colors.white,
//         title: const Text(
//           'Section',
//           style: TextStyle(
//             fontSize: 30,
//             color: Color(0xff1B1212),
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         automaticallyImplyLeading: false,
//       ),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('takenLessons')
//             .where('studentId', isEqualTo: currentUser.uid)
//             .where('isRated', isNotEqualTo: true)
//             .orderBy('dateTime', descending: true)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(
//               child: CircularProgressIndicator(
//                 color: Color(0xff1B1212),
//                 backgroundColor: Colors.white,
//               ),
//             );
//           }

//           if (snapshot.hasError) {
//             // Log error only once to avoid terminal spam
//             if (!_hasLoggedIndexError) {
//               print('Firestore query error: ${snapshot.error}');
//               print('Stack trace: ${snapshot.stackTrace}');
//               if (snapshot.error.toString().contains('requires an index')) {
//                 print(
//                     'INDEX ERROR: The query requires a composite index. Follow the URL provided above to create it in the Firebase Console.');
//               }
//               _hasLoggedIndexError = true; // Prevent repeated logging
//             }
//             String errorMessage = 'Failed to load lessons: ${snapshot.error}';
//             if (snapshot.error.toString().contains('requires an index')) {
//               errorMessage =
//                   'A database index is required to load lessons.\nPlease contact the app administrator to create the index using the URL in the debug console.';
//             }
//             return Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text(
//                       errorMessage,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         color: Color(0xff1B1212),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     ElevatedButton(
//                       onPressed: () {
//                         setState(() {
//                           _hasLoggedIndexError = false; // Allow re-logging on retry
//                         }); // Trigger rebuild to retry
//                       },
//                       child: const Text('Retry'),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }

//           final takenLessons = snapshot.data?.docs ?? [];

//           if (!_hasProcessedInitialLoad) {
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               for (var doc in takenLessons) {
//                 final lessonId = doc.id;
//                 final item = doc.data() as Map<String, dynamic>;
//                 final lessonDateTime = _parseDateTime(item['dateTime']);
//                 final endTime = lessonDateTime.add(const Duration(hours: 2));
//                 final now = DateTime.now();
//                 final remaining = endTime.difference(now);

//                 if (remaining.isNegative && (item['isRated'] != true)) {
//                   _showRatingDialog(item, lessonId);
//                 }
//               }
//               _hasProcessedInitialLoad = true;
//             });
//           }

//           if (takenLessons.isEmpty) {
//             return const Center(
//               child: Padding(
//                 padding: EdgeInsets.all(20.0),
//                 child: Text(
//                   'No Lessons Taken',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 20,
//                     color: Color(0xff1B1212),
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             );
//           }

//           return ListView.builder(
//             itemCount: takenLessons.length,
//             itemBuilder: (context, index) {
//               final doc = takenLessons[index];
//               final item = doc.data() as Map<String, dynamic>;
//               final lessonId = doc.id;
//               final lessonDateTime = _parseDateTime(item['dateTime']);
//               final endTime = lessonDateTime.add(const Duration(hours: 2));

//               return StreamBuilder<DateTime>(
//                 stream: Stream.periodic(
//                   const Duration(seconds: 1),
//                   (_) => DateTime.now(),
//                 ),
//                 builder: (context, timeSnapshot) {
//                   final now = timeSnapshot.data ?? DateTime.now();
//                   final remaining = endTime.difference(now);

//                   if (remaining.isNegative &&
//                       (item['isRated'] != true) &&
//                       !_shownDialogs.contains(lessonId)) {
//                     _shownDialogs.add(lessonId);
//                     WidgetsBinding.instance.addPostFrameCallback((_) {
//                       _showRatingDialog(item, lessonId);
//                     });
//                   }

//                   return Container(
//                     margin: const EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(10),
//                       boxShadow: const [
//                         BoxShadow(
//                           color: Colors.grey,
//                           offset: Offset(0.0, 1.0),
//                           blurRadius: 6.0,
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.stretch,
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.only(left: 10, top: 5),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               InkWell(
//                                 onTap: () {
//                                   Navigator.push(
//                                     context,
//                                     PageRouteBuilder(
//                                       pageBuilder: (context, animation,
//                                               secondaryAnimation) =>
//                                           AllUsersProfile(
//                                               userId: item['teacherId']),
//                                       transitionsBuilder: (context, animation,
//                                           secondaryAnimation, child) {
//                                         const begin = Offset(1.0, 0.0);
//                                         const end = Offset.zero;
//                                         const curve = Curves.easeInOut;
//                                         var tween = Tween(
//                                                 begin: begin, end: end)
//                                             .chain(CurveTween(curve: curve));
//                                         return SlideTransition(
//                                           position: animation.drive(tween),
//                                           child: child,
//                                         );
//                                       },
//                                     ),
//                                   );
//                                 },
//                                 child: Row(
//                                   children: [
//                                     StreamBuilder<DocumentSnapshot>(
//                                       stream: FirebaseFirestore.instance
//                                           .collection('users')
//                                           .doc(item['teacherId'])
//                                           .snapshots(),
//                                       builder: (context, snapshot) {
//                                         if (snapshot.hasData &&
//                                             snapshot.data!.exists) {
//                                           final userData = snapshot.data!.data()
//                                               as Map<String, dynamic>;
//                                           final imageUrl =
//                                               userData['profileImageUrl'] ??
//                                                   '';

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
//                                           child: const Icon(Icons.person,
//                                               color: Colors.white),
//                                         );
//                                       },
//                                     ),
//                                     const SizedBox(width: 10),
//                                     Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           item['teacherName'] ??
//                                               'Unknown Teacher',
//                                           style: const TextStyle(
//                                             fontSize: 16,
//                                             color: Color(0xff1B1212),
//                                             fontWeight: FontWeight.bold,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 5),
//                                         InkWell(
//                                           onTap: () {
//                                             showDialog(
//                                               context: context,
//                                               builder: (_) => AlertDialogRating(
//                                                 teacherId: item['teacherId'],
//                                                 onRatingSubmitted: (avg) async {
//                                                   setState(() {
//                                                     _averageRating = avg;
//                                                   });
//                                                   // Mark the lesson as rated in Firestore
//                                                   try {
//                                                     await FirebaseFirestore
//                                                         .instance
//                                                         .collection(
//                                                             'takenLessons')
//                                                         .doc(lessonId)
//                                                         .update(
//                                                             {'isRated': true});
//                                                   } catch (e, stackTrace) {
//                                                     print(
//                                                         'Error updating isRated for lesson $lessonId: $e');
//                                                     print(
//                                                         'Stack trace: $stackTrace');
//                                                     ScaffoldMessenger.of(
//                                                             context)
//                                                         .showSnackBar(
//                                                       SnackBar(
//                                                           content: Text(
//                                                               'Failed to save rating: $e')),
//                                                     );
//                                                   }
//                                                 },
//                                                 lessonId: lessonId,
//                                               ),
//                                             );
//                                           },
//                                           child: Row(
//                                             children: [
//                                               const Icon(
//                                                 Icons.star,
//                                                 color: Colors.yellow,
//                                               ),
//                                               const SizedBox(width: 8),
//                                               Text(
//                                                 _averageRating.toStringAsFixed(1),
//                                                 style: const TextStyle(
//                                                   fontSize: 16,
//                                                   color: Color(0xff1B1212),
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         )
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 10),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 item['speakLevel'] ?? 'Not specified',
//                                 style: const TextStyle(
//                                   fontSize: 20,
//                                   color: Color(0xff1B1212),
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               IconButton(
//                                 onPressed: () async {
//                                   final locationData = item['location'];
//                                   print('Raw location data: $locationData');

//                                   final parsedLocation =
//                                       _parseLocation(locationData);
//                                   print('Parsed location: $parsedLocation');

//                                   if (parsedLocation == null) {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       const SnackBar(
//                                         content: Text(
//                                             'This lesson has no valid location data'),
//                                         duration: Duration(seconds: 2),
//                                       ),
//                                     );
//                                     return;
//                                   }

//                                   final latLng = parsedLocation is GeoPoint
//                                       ? gmaps.LatLng(parsedLocation.latitude,
//                                           parsedLocation.longitude)
//                                       : parsedLocation as gmaps.LatLng;

//                                   await Navigator.push(
//                                     context,
//                                     MaterialPageRoute(
//                                       builder: (context) => MapScreen(
//                                         savedLocation: latLng,
//                                         lessonTitle:
//                                             item['speakLevel'] ?? 'Lesson Location',
//                                         teacherName:
//                                             item['teacherName'] ?? 'Teacher',
//                                       ),
//                                     ),
//                                   );
//                                 },
//                                 icon: Image.asset('assets/images/maps.png',
//                                     scale: 13.8),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.all(10.0),
//                           child: Text(
//                             item['description'] ?? 'No description available',
//                             style: const TextStyle(
//                               color: Color(0xff1B1212),
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.all(10.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Starts: ${DateFormat('yyyy/MM/dd hh:mm a').format(lessonDateTime)}',
//                                 style: const TextStyle(
//                                   color: Color(0xff1B1212),
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               const SizedBox(height: 5),
//                               Container(
//                                 padding: const EdgeInsets.all(8),
//                                 decoration: BoxDecoration(
//                                   color: remaining.isNegative
//                                       ? Colors.green.withOpacity(0.2)
//                                       : Colors.red.withOpacity(0.2),
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 child: Row(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     Icon(
//                                       Icons.timer,
//                                       color: remaining.isNegative
//                                           ? Colors.green
//                                           : Colors.red,
//                                     ),
//                                     const SizedBox(width: 8),
//                                     remaining.isNegative
//                                         ? const Text(
//                                             'Completed',
//                                             style: TextStyle(
//                                               color: Colors.green,
//                                               fontWeight: FontWeight.bold,
//                                               fontSize: 18,
//                                             ),
//                                           )
//                                         : _buildTimer(remaining),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }



class AlertDialogRating extends StatefulWidget {
  final String teacherId;
  final String lessonId;
  final Function(double) onRatingSubmitted;

  const AlertDialogRating({
    super.key,
    required this.teacherId,
    required this.lessonId,
    required this.onRatingSubmitted,
  });

  @override
  _AlertDialogRatingState createState() => _AlertDialogRatingState();
}

class _AlertDialogRatingState extends State<AlertDialogRating> {
  final List<double?> _ratings = List.filled(6, null);
  double _averageRating = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingRating();
  }

  void _setRating(int rowIndex, double rating) {
    setState(() {
      _ratings[rowIndex] = rating;
      _averageRating = _calculateAverageRating();
    });
  }

  double _calculateAverageRating() {
    final validRatings = _ratings.where((rating) => rating != null).toList();
    if (validRatings.isEmpty) return 0.0;
    return validRatings.reduce((a, b) => a! + b!)! / validRatings.length;
  }

  Future<void> _loadExistingRating() async {
    try {
      if (widget.teacherId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString('rating_${widget.teacherId}');

      if (localData != null) {
        final data = jsonDecode(localData);
        List<double> localRatings = List<double>.from(data['ratings']);
        setState(() {
          _ratings.setAll(0, localRatings);
          _averageRating = _calculateAverageRating();
        });
      }
    } catch (e) {
      print('Error loading rating: $e');
    }
  }

  Future<void> _saveRatingToFirestore(double averageRating) async {
    try {
      setState(() => _isLoading = true);
      
      // Update parent callback first
      widget.onRatingSubmitted(averageRating);

      List<double> ratingsList = _ratings.map((r) => r ?? 0.0).toList();

      // Save to teacher ratings
      await FirebaseFirestore.instance
          .collection('teacherRatings')
          .doc(widget.teacherId)
          .set({
        'ratings': ratingsList,
        'averageRating': averageRating,
      }, SetOptions(merge: true));

      // Mark lesson as rated
      await FirebaseFirestore.instance
          .collection('takenLessons')
          .doc(widget.lessonId)
          .update({'isRated': true});

      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'rating_${widget.teacherId}',
        jsonEncode({'ratings': ratingsList, 'averageRating': averageRating}),
      );

      // Show notification
      await NotificationService().showNotification(
        title: 'Rating Teacher',
        body: 'Your rating has been submitted successfully.',
      );
      
      await NotificationStorage.addNotification(
        LocalNotificationModel(
          title: 'Rating Teacher',
          body: 'Your rating has been submitted successfully.',
          timestamp: DateTime.now(),
        ),
      );

      setState(() => _isLoading = false);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error saving rating: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'Rate the Teacher',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xff1B1212),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: WillPopScope(
        onWillPop: () async => false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...List.generate(ratingTeacher.length, (rowIndex) {
                return Column(
                  children: [
                    Center(
                      child: Text(
                        ratingTeacher[rowIndex],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1B1212),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (starIndex) {
                        double starRating = starIndex + 1.0;
                        return GestureDetector(
                          onTap: () => _setRating(rowIndex, starRating),
                          onDoubleTap: () => _setRating(rowIndex, starRating - 0.5),
                          child: Icon(
                            starRating - 0.5 <= (_ratings[rowIndex] ?? 0)
                                ? Icons.star
                                : starRating <= (_ratings[rowIndex] ?? 0)
                                    ? Icons.star_half
                                    : Icons.star_border,
                            color: Colors.amber,
                            size: 30.0,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(
                     color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,
                  ),)
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Color(0xff1B1212),
                      ),
                      onPressed: () async {
                        final avg = _calculateAverageRating();
                        await _saveRatingToFirestore(avg);
                      },
                      child: const Text(
                        'Submit',
                        style: TextStyle(fontSize: 17, color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

List<String> ratingTeacher = [
  'Classroom Management',
  'Following topics',
  'Teaching Vocabulary',
  'Correcting grammar',
  'Energy',
  'Place Choice',
];


