import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spokencafe/Credit_Card/Cresit_Api.dart';
import 'package:spokencafe/profile/All_Users_Profile/All_Users_Profile.dart';

class Lesson {
  final String title;
  final String content;

  Lesson({required this.title, required this.content});
}

final itemsProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final selectedIndexProvider = StateProvider<int?>((ref) => null);
final paymentCompletedProvider = StateProvider<bool>((ref) => false);

class SearchStudent extends ConsumerStatefulWidget {
  const SearchStudent({super.key});

  @override
  ConsumerState<SearchStudent> createState() => _SearchStudentState();
}

class _SearchStudentState extends ConsumerState<SearchStudent> {
  final double _teacherRating = 0.0;
  List<DocumentSnapshot> _filteredLessons = [];
  List<Lesson> savedLessons = [];
  Position? _currentPosition;
  double _selectedDistance = 1.0;
  bool _isLocationLoading = false;
  bool _locationPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    loadSavedLessons();
    _getCurrentLocation();
    //Stripe.publishableKey = stripPublishKey;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> loadSavedLessons() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final titles = prefs.getStringList('lesson_titles') ?? [];
    final contents = prefs.getStringList('lesson_contents') ?? [];

    if (mounted) {
      setState(() {
        savedLessons = List.generate(
          titles.length,
          (index) => Lesson(title: titles[index], content: contents[index]),
        );
      });
    }
  }

  Future<void> removeLesson(int index) async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> titles = prefs.getStringList('lesson_titles') ?? [];
    List<String> contents = prefs.getStringList('lesson_contents') ?? [];

    if (index < titles.length && index < contents.length) {
      titles.removeAt(index);
      contents.removeAt(index);

      await prefs.setStringList('lesson_titles', titles);
      await prefs.setStringList('lesson_contents', contents);

      if (mounted) {
        setState(() {
          savedLessons.removeAt(index);
        });
      }
    }
  }

  DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime is Timestamp) return dateTime.toDate();
    if (dateTime is String) return DateTime.parse(dateTime);
    throw Exception('Invalid date format');
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLocationLoading = true;
      _locationPermissionDenied = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocationLoading = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLocationLoading = false;
              _locationPermissionDenied = true;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocationLoading = false;
            _locationPermissionDenied = true;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLocationLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  Future<List<DocumentSnapshot>> _filterLessonsByDistance(
      List<DocumentSnapshot> lessons, double maxDistanceKm) async {
    if (_currentPosition == null) {
      print('Current position is null, returning all lessons');
      return lessons;
    }

    List<DocumentSnapshot> filtered = [];

    for (var lesson in lessons) {
      try {
        final lessonData = lesson.data() as Map<String, dynamic>;
        GeoPoint? geoPoint;

        // Handle different location field types
        final location = lessonData['location'];
        if (location is GeoPoint) {
          geoPoint = location;
        } else if (location is List<dynamic> && location.length == 2) {
          // Handle List<dynamic> case (e.g., [latitude, longitude])
          try {
            final lat = double.parse(location[0].toString());
            final lng = double.parse(location[1].toString());
            geoPoint = GeoPoint(lat, lng);
          } catch (e) {
            print('Invalid List format for lesson ${lesson.id}: $location');
            continue;
          }
        } else if (location == null) {
          print('No location data for lesson ${lesson.id}');
          continue;
        } else {
          print(
              'Unexpected location format for lesson ${lesson.id}: $location');
          continue;
        }

        double distanceInMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          geoPoint.latitude,
          geoPoint.longitude,
        );

        double distanceInKm = distanceInMeters / 1000;

        if (distanceInKm <= maxDistanceKm) {
          filtered.add(lesson);
        }
      } catch (e) {
        print('Error processing lesson ${lesson.id}: $e');
        continue;
      }
    }

    print('Filtered ${filtered.length} lessons within $maxDistanceKm km');
    return filtered;
  }

  Future<List<DocumentSnapshot>> _excludeTakenLessons(
      List<DocumentSnapshot> lessons) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return lessons;

    final takenLessonsSnapshot = await FirebaseFirestore.instance
        .collection('takenLessons')
        .where('studentId', isEqualTo: user.uid)
        .get();

    final takenLessonIds = takenLessonsSnapshot.docs
        .where((doc) =>
            doc.data().containsKey('lessonId') && doc['lessonId'] is String)
        .map((doc) => doc['lessonId'] as String)
        .toSet();

    return lessons
        .where((lesson) => !takenLessonIds.contains(lesson.id))
        .toList();
  }

  Future<void> _joinLesson(String lessonDocId, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final lessonRef =
        FirebaseFirestore.instance.collection('lessons').doc(lessonDocId);
    final takenLessonsRef =
        FirebaseFirestore.instance.collection('takenLessons');

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final lessonSnapshot = await transaction.get(lessonRef);
        if (!lessonSnapshot.exists) throw Exception("Lesson does not exist!");

        final lessonData = lessonSnapshot.data()!;
        final currentStudentCount =
            (lessonData['currentStudentCount'] ?? 0) as int;

        if (currentStudentCount >= 8) {
          throw Exception("Lesson is full. You cannot join.");
        }

        final teacherDoc = await transaction.get(
          FirebaseFirestore.instance
              .collection('users')
              .doc(lessonData['teacherId']),
        );
        final teacherData = teacherDoc.data() as Map<String, dynamic>;
        final teacherName = '${teacherData['name']} ${teacherData['surname']}';

        // Validate location data
        final geoPoint = lessonData['location'] as GeoPoint?;
        final locationName = lessonData['locationName'] as String?;
        if (geoPoint == null || locationName == null) {
          throw Exception("Lesson has no valid location data.");
        }

        transaction.update(lessonRef, {
          'currentStudentCount': currentStudentCount + 1,
        });

        transaction.set(takenLessonsRef.doc(), {
          'lessonId': lessonDocId,
          'studentId': user.uid,
          'joinedAt': FieldValue.serverTimestamp(),
          'teacherId': lessonData['teacherId'],
          'teacherName': teacherName,
          'speakLevel': lessonData['speakLevel'],
          'dateTime': lessonData['dateTime'],
          'description': lessonData['description'],
          'location': geoPoint,
          'locationName': locationName,
          'isRated': false,
        });
      });

      if (mounted) {
        setState(() {
          _filteredLessons.removeWhere((doc) => doc.id == lessonDocId);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            content: Text('Successfully joined lesson!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _refreshLessons(double distance) async {
    if (!mounted) return;

    setState(() {
      _isLocationLoading = true;
    });

    try {
      final lessonSnapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .orderBy('dateTime', descending: true)
          .get();

      var filtered =
          await _filterLessonsByDistance(lessonSnapshot.docs, distance);
      filtered = await _excludeTakenLessons(filtered);

      if (mounted) {
        setState(() {
          _filteredLessons = filtered;
          _isLocationLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Error loading lessons: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Row(
          //crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            waycoffes.length,
            (index) {
              return InkWell(
                onTap: () async {
                  ref.read(selectedIndexProvider.notifier).state = index;
                  final distance = double.parse(waycoffes[index]);
                  setState(() {
                    _selectedDistance = distance;
                  });
                  await _refreshLessons(distance);
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selectedIndex == index
                        ? const Color(0xff1B1212)
                        : Colors.transparent,
                    border:
                        Border.all(width: 1, color: const Color(0xff1B1212)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${waycoffes[index]}KM',
                        style: TextStyle(
                          fontSize: 25,
                          color: selectedIndex == index
                              ? Colors.white
                              : const Color(0xff1B1212),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: _isLocationLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xff1B1212),
                  backgroundColor: Colors.white,
                ),
              )
            : _locationPermissionDenied
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Location permission is required to filter lessons by distance',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff1B1212),
                          ),
                          onPressed: _getCurrentLocation,
                          child: const Text('Enable Location'),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('lessons')
                        .orderBy('dateTime', descending: true)
                        .snapshots(),
                    builder: (context, lessonSnapshot) {
                      if (!mounted) return const SizedBox.shrink();

                      if (lessonSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xff1B1212),
                            backgroundColor: Colors.white,
                          ),
                        );
                      }

                      if (lessonSnapshot.hasError || !lessonSnapshot.hasData) {
                        return const Center(
                            child: Text('Error fetching lessons'));
                      }

                      final lessonDocs = lessonSnapshot.data!.docs;

                      if (_filteredLessons.isEmpty) {
                        _excludeTakenLessons(lessonDocs).then((filtered) {
                          if (mounted) {
                            setState(() {
                              _filteredLessons = filtered;
                            });
                          }
                        });
                      }

                      return ListView.builder(
                        itemCount: _filteredLessons.length,
                        itemBuilder: (context, index) {
                          final lessonDoc = _filteredLessons[index];
                          final lessonData =
                              lessonDoc.data() as Map<String, dynamic>;
                          final teacherId = lessonData['teacherId'];
                          final lessonDocId = lessonDoc.id;
                          final currentStudentCount =
                              (lessonData['currentStudentCount'] as int?) ?? 0;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(teacherId)
                                .get(),
                            builder: (context, teacherSnapshot) {
                              if (!mounted) return const SizedBox.shrink();

                              if (teacherSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xff1B1212),
                                    backgroundColor: Colors.white,
                                    strokeWidth: 4,
                                    padding: EdgeInsets.all(20),
                                  ),
                                );
                              }

                              if (teacherSnapshot.hasError ||
                                  !teacherSnapshot.hasData) {
                                return const Center(
                                    child: Text('Error fetching teacher data'));
                              }

                              final teacher = teacherSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                              final teacherRole = teacher?['role'] ?? 'student';
                              final teacherName =
                                  teacher?['name'] ?? 'Unknown Teacher';
                              final teacherSurname = teacher?['surname'] ?? '';
                              final teacherPhoto =
                                  teacher?['profileImageUrl'] ??
                                      teacher?['profileImage'] ??
                                      '';

                              String displayName = teacherRole == 'teacher'
                                  ? '$teacherName $teacherSurname'
                                  : 'Unknown User';

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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder: (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                            ) =>
                                                AllUsersProfile(
                                                    userId: teacherId),
                                            transitionsBuilder: (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                              child,
                                            ) {
                                              const begin = Offset(1.0, 0.0);
                                              const end = Offset.zero;
                                              const curve = Curves.easeInOut;

                                              var tween = Tween(
                                                begin: begin,
                                                end: end,
                                              ).chain(
                                                CurveTween(
                                                  curve: curve,
                                                ),
                                              );
                                              return SlideTransition(
                                                position: animation.drive(
                                                  tween,
                                                ),
                                                child: child,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 10, top: 5),
                                        child: Row(
                                          children: [
                                            StreamBuilder<DocumentSnapshot>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(teacherId)
                                                  .snapshots(),
                                              builder: (context, snapshot) {
                                                if (!mounted) {
                                                  return CircleAvatar(
                                                    radius: 25,
                                                    backgroundColor:
                                                        Colors.grey[100],
                                                    child: Icon(Icons.person,
                                                        color: Colors.white),
                                                  );
                                                }

                                                if (snapshot.hasData &&
                                                    snapshot.data!.exists) {
                                                  final userData = snapshot
                                                          .data!
                                                          .data()
                                                      as Map<String, dynamic>;
                                                  final imageUrl = userData[
                                                          'profileImageUrl'] ??
                                                      userData[
                                                          'profileImage'] ??
                                                      '';

                                                  if (imageUrl.isNotEmpty) {
                                                    return CircleAvatar(
                                                      radius: 25,
                                                      backgroundColor:
                                                          Colors.grey,
                                                      child: ClipOval(
                                                        child: Image.network(
                                                          imageUrl,
                                                          width: 50,
                                                          height: 50,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (context, error,
                                                                  stackTrace) {
                                                            print(
                                                                'Error loading image for user $teacherId: $error');
                                                            return Icon(
                                                                Icons.person,
                                                                color: Colors
                                                                    .white);
                                                          },
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }

                                                return CircleAvatar(
                                                  radius: 25,
                                                  backgroundColor:
                                                      Colors.grey[100],
                                                  child: Icon(Icons.person,
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
                                                  displayName,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xff1B1212),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(Icons.star,
                                                        color:
                                                            Colors.yellow[700]),
                                                    Text(
                                                      _teacherRating
                                                          .toStringAsFixed(1),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        color:
                                                            Color(0xff1B1212),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 10, right: 10, top: 10),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                lessonData['speakLevel'] ??
                                                    'N/A',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  color: Color(0xff1B1212),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (currentStudentCount < 8)
                                            TextButton(
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    backgroundColor:
                                                        Colors.white,
                                                    title: const Text(
                                                        'Confirm Lesson',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.blue)),
                                                    content: const Text(
                                                      'Derse katılacağınıza emin misiniz? Satın aldiktan sonra katılımınız iptal edilemez',
                                                      style: TextStyle(
                                                          fontSize: 20),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: const Text(
                                                            'Onaylamiyorum',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                              fontSize: 17,
                                                            )),
                                                      ),
                                                      TextButton(
                                                        onPressed: () async {
                                                          showModalBottomSheet(
                                                            context: context,
                                                            shape:
                                                                const RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.vertical(
                                                                      top: Radius
                                                                          .circular(
                                                                              20)),
                                                            ),
                                                            isScrollControlled:
                                                                true,
                                                            builder: (context) {
                                                              bool saveCard =
                                                                  true;
                                                              final cardNumberController =
                                                                  TextEditingController();
                                                              final expiryDateController =
                                                                  TextEditingController();
                                                              final cvcController =
                                                                  TextEditingController();
                                                              bool isFormValid =
                                                                  false;

                                                              void
                                                                  validateForm() {
                                                                final cleanCardNumber =
                                                                    cardNumberController
                                                                        .text
                                                                        .replaceAll(
                                                                            RegExp(r'\s+'),
                                                                            '');
                                                                final cardNumberValid =
                                                                    cleanCardNumber
                                                                            .length ==
                                                                        16;
                                                                final expiryValid =
                                                                    expiryDateController
                                                                            .text
                                                                            .length ==
                                                                        5;
                                                                final cvcValid =
                                                                    cvcController
                                                                            .text
                                                                            .length ==
                                                                        3;
                                                                isFormValid =
                                                                    cardNumberValid &&
                                                                        expiryValid &&
                                                                        cvcValid;
                                                              }

                                                              return StatefulBuilder(
                                                                builder: (context,
                                                                    setState) {
                                                                  return Padding(
                                                                    padding:
                                                                        EdgeInsets
                                                                            .only(
                                                                      bottom: MediaQuery.of(
                                                                              context)
                                                                          .viewInsets
                                                                          .bottom,
                                                                      left: 20,
                                                                      right: 20,
                                                                      top: 20,
                                                                    ),
                                                                    child:
                                                                        SingleChildScrollView(
                                                                      child:
                                                                          Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Center(
                                                                            child:
                                                                                Container(
                                                                              width: 50,
                                                                              height: 5,
                                                                              decoration: BoxDecoration(
                                                                                color: Colors.grey[300],
                                                                                borderRadius: BorderRadius.circular(10),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                              height: 20),
                                                                          const Center(
                                                                            child:
                                                                                Text(
                                                                              'Add a card',
                                                                              style: TextStyle(
                                                                                fontSize: 18,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: Color(0xff1B1212),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                              height: 20),
                                                                          TextFormField(
                                                                            controller:
                                                                                cardNumberController,
                                                                            decoration:
                                                                                InputDecoration(
                                                                              labelText: 'Card number',
                                                                              hintText: 'XXXX XXXX XXXX XXXX',
                                                                              labelStyle: TextStyle(
                                                                                color: Color(0xff1B1212),
                                                                              ),
                                                                              hintStyle: TextStyle(
                                                                                color: Color(0xff1B1212),
                                                                              ),
                                                                              suffixIcon: Row(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                children: [
                                                                                  Image.asset('assets/images/visa.png', height: 24),
                                                                                  Image.asset('assets/images/mastercard.png', height: 24),
                                                                                ],
                                                                              ),
                                                                              border: OutlineInputBorder(
                                                                                borderRadius: BorderRadius.circular(10),
                                                                              ),
                                                                            ),
                                                                            keyboardType:
                                                                                TextInputType.number,
                                                                            inputFormatters: [
                                                                              FilteringTextInputFormatter.digitsOnly,
                                                                              LengthLimitingTextInputFormatter(16),
                                                                              CardNumberInputFormatter(), // Custom formatter to show space every 4 digits
                                                                            ],
                                                                            onChanged:
                                                                                (_) {
                                                                              setState(() {
                                                                                validateForm();
                                                                              });
                                                                            },
                                                                          ),
                                                                          const SizedBox(
                                                                              height: 15),
                                                                          Row(
                                                                            children: [
                                                                              Expanded(
                                                                                child: TextFormField(
                                                                                  controller: expiryDateController,
                                                                                  decoration: InputDecoration(
                                                                                    labelStyle: TextStyle(
                                                                                      color: Color(0xff1B1212),
                                                                                    ),
                                                                                    hintStyle: TextStyle(
                                                                                      color: Color(0xff1B1212),
                                                                                    ),
                                                                                    labelText: 'MM / YY',
                                                                                    hintText: 'MM / YY',
                                                                                    border: OutlineInputBorder(
                                                                                      borderRadius: BorderRadius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                  keyboardType: TextInputType.number,
                                                                                  inputFormatters: [
                                                                                    LengthLimitingTextInputFormatter(5),
                                                                                    ExpiryDateInputFormatter(),
                                                                                  ],
                                                                                  onChanged: (_) {
                                                                                    setState(() {
                                                                                      validateForm();
                                                                                    });
                                                                                  },
                                                                                ),
                                                                              ),
                                                                              const SizedBox(width: 10),
                                                                              Expanded(
                                                                                child: TextFormField(
                                                                                  controller: cvcController,
                                                                                  decoration: InputDecoration(
                                                                                    labelStyle: TextStyle(
                                                                                      color: Color(0xff1B1212),
                                                                                    ),
                                                                                    hintStyle: TextStyle(
                                                                                      color: Color(0xff1B1212),
                                                                                    ),
                                                                                    labelText: 'CVC',
                                                                                    hintText: 'CVC',
                                                                                    border: OutlineInputBorder(
                                                                                      borderRadius: BorderRadius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                  keyboardType: TextInputType.number,
                                                                                  inputFormatters: [
                                                                                    FilteringTextInputFormatter.digitsOnly,
                                                                                    LengthLimitingTextInputFormatter(3),
                                                                                  ],
                                                                                  onChanged: (_) {
                                                                                    setState(() {
                                                                                      validateForm();
                                                                                    });
                                                                                  },
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          const SizedBox(
                                                                              height: 15),
                                                                          Row(
                                                                            children: [
                                                                              Checkbox(
                                                                                activeColor: Color(0xff1B1212),
                                                                                value: saveCard,
                                                                                onChanged: (v) {
                                                                                  setState(() {
                                                                                    saveCard = v ?? false;
                                                                                  });
                                                                                },
                                                                              ),
                                                                              const Text('Save card for future payments'),
                                                                            ],
                                                                          ),
                                                                          const SizedBox(
                                                                              height: 20),
                                                                          ElevatedButton(
                                                                            style:
                                                                                ElevatedButton.styleFrom(
                                                                              minimumSize: const Size.fromHeight(50),
                                                                              backgroundColor: isFormValid ? Color(0xff1B1212) : Colors.grey,
                                                                              shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(10),
                                                                              ),
                                                                            ),
                                                                            onPressed: isFormValid
                                                                                ? () async {
                                                                                    if (!isFormValid) return;

                                                                                    final cleanCardNumber = cardNumberController.text.replaceAll(' ', '');
                                                                                    final expiryParts = expiryDateController.text.split('/');
                                                                                    final expMonth = expiryParts[0];
                                                                                    final expYear = '5${expiryParts[1]}'; // Assuming 'YY' format

                                                                                   // Trigger the payment call using your service
                                                                                    final success = await NestpayPaymentService.instance.makePayment(
                                                                                      amount: 180,
                                                                                      number: cleanCardNumber,
                                                                                      expMonth: expMonth,
                                                                                      expYear: expYear,
                                                                                      cvv: cvcController.text,
                                                                                      email: 'useremail@example.com',
                                                                                      name: 'Full Name',
                                                                                    );
                                                                               
                                                                                                                                                                         

                                                                                    if (success) {
                                                                                      print('✅ Payment Success');
                                                                                      Navigator.pop(context);
                                                                                    } else {
                                                                                      print('❌ Payment Failed');
                                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                                        const SnackBar(content: Text('Payment failed, please try again.')),
                                                                                      );
                                                                                    
                                                                                    }
                                                                                    // ✅ Trigger payment function here
                                                                                  }
                                                                                : null,
                                                                            child:
                                                                                const Text(
                                                                              'Add',
                                                                              style: TextStyle(color: Colors.white, fontSize: 16),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                              height: 20),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              );
                                                            },
                                                          );
                                                        },
                                                        child: const Text(
                                                          'Onaylıyorum',
                                                          style: TextStyle(
                                                            color: Colors.blue,
                                                            fontSize: 17,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              child: const Text(
                                                'Take Lesson',
                                                style: TextStyle(
                                                  color: Color(0xff1B1212),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: 20, left: 10),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                DateFormat('yyyy/MM/dd hh:mm a')
                                                    .format(
                                                  _parseDateTime(
                                                      lessonData['dateTime']),
                                                ),
                                                style: const TextStyle(
                                                  color: Color(0xff1B1212),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'Students: ${lessonData['currentStudentCount'] ?? 0}/8',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Text(
                                        lessonData['description'] ??
                                            'No description available.',
                                        style: const TextStyle(
                                          color: Color(0xff1B1212),
                                          fontWeight: FontWeight.bold,
                                        ),
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
      ),
    );
  }
}

List<String> waycoffes = ['1', '2', '5', '10'];

class AlertDialogRating extends StatefulWidget {
  final String teacherId;
  final Function(double) onRatingSubmitted;

  const AlertDialogRating({
    super.key,
    required this.teacherId,
    required this.onRatingSubmitted,
  });

  @override
  _AlertDialogRatingState createState() => _AlertDialogRatingState();
}

class _AlertDialogRatingState extends State<AlertDialogRating> {
  double _rating = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeacherRating();
  }

  Future<void> _fetchTeacherRating() async {
    try {
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get();

      if (ratingsSnapshot.docs.isNotEmpty) {
        double totalRating = 0.0;
        int ratingCount = 0;

        for (var doc in ratingsSnapshot.docs) {
          final rating = (doc['rating'] as num?)?.toDouble();
          if (rating != null) {
            totalRating += rating;
            ratingCount++;
          }
        }

        if (ratingCount > 0) {
          final averageRating = totalRating / ratingCount;
          if (mounted) {
            setState(() {
              _rating = averageRating.clamp(
                  1.0, 5.0); // Ensure rating is within valid range
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error fetching rating: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'Rate Teacher',
        style: TextStyle(
          color: Color(0xff1B1212),
        ),
      ),
      content: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xff1B1212),
                backgroundColor: Colors.white,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: _rating,
                  onChanged: (value) {
                    setState(() {
                      _rating = value;
                    });
                  },
                  min: 1.0,
                  max: 5.0,
                  divisions: 4,
                  label: _rating.toStringAsFixed(1),
                ),
                Text('Rating: ${_rating.toStringAsFixed(1)}'),
              ],
            ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isLoading
              ? null
              : () {
                  widget.onRatingSubmitted(_rating);

                  FirebaseFirestore.instance.collection('ratings').add({
                    'rating': _rating,
                    'teacherId': widget.teacherId,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                },
          child: const Text('Submit Rating',
              style: TextStyle(color: Color(0xff1B1212))),
        ),
      ],
    );
  }
}

// here will enter the card information first one
// class CardNumberInputFormatter extends TextInputFormatter {
//   @override
//   TextEditingValue formatEditUpdate(
//       TextEditingValue oldValue, TextEditingValue newValue) {
//     String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

//     // Limit to 16 digits (standard card number length)
//     if (text.length > 16) {
//       text = text.substring(0, 16);
//     }

//     // Add spaces after every 4 digits
//     StringBuffer formatted = StringBuffer();
//     for (int i = 0; i < text.length; i++) {
//       if (i > 0 && i % 4 == 0) {
//         formatted.write(' ');
//       }
//       formatted.write(text[i]);
//     }

//     // Calculate new cursor position
//     String formattedText = formatted.toString();
//     int cursorOffset = newValue.selection.baseOffset;

//     String inputUpToCursor =
//         newValue.text.substring(0, cursorOffset.clamp(0, newValue.text.length));
//     int digitsBeforeCursor =
//         inputUpToCursor.replaceAll(RegExp(r'[^0-9]'), '').length;

//     int newCursorPosition = 0;
//     int digitCount = 0;
//     for (int i = 0;
//         i < formattedText.length && digitCount < digitsBeforeCursor;
//         i++) {
//       if (RegExp(r'[0-9]').hasMatch(formattedText[i])) {
//         digitCount++;
//       }
//       newCursorPosition = i + 1;
//     }

//     newCursorPosition = newCursorPosition.clamp(0, formattedText.length);

//     return TextEditingValue(
//       text: formattedText,
//       selection: TextSelection.collapsed(offset: newCursorPosition),
//     );
//   }
// }
// For Card number (already done)
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    String newText = '';
    for (int i = 0; i < text.length; i++) {
      if (i != 0 && i % 4 == 0) {
        newText += ' ';
      }
      newText += text[i];
    }
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// For MM/YY format
class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    String newText = '';
    if (text.length >= 2) {
      newText = text.substring(0, 2);
      if (text.length > 2) {
        newText += '/${text.substring(2, text.length.clamp(2, 4))}';
      }
    } else {
      newText = text;
    }
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
