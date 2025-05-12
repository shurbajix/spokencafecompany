import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spokencafe/Credit_Card/Cresit_Api.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_stripe/flutter_stripe.dart';

// Define Lesson class
class Lesson {
  final String title;
  final String content;

  Lesson({required this.title, required this.content});
}

class AllUsersProfile extends ConsumerStatefulWidget {
  final String userId;

  const AllUsersProfile({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  ConsumerState<AllUsersProfile> createState() => _AllUsersProfileState();
}

class _AllUsersProfileState extends ConsumerState<AllUsersProfile> {
  bool isFollowing = false;
  bool isLoading = false;
  int followersCount = 0;
  int followingCount = 0;
  final currentUser = FirebaseAuth.instance.currentUser;
  List<String> imageUrls = [];
  List<String> videoUrls = [];
  String? introVideoUrl;
  VideoPlayerController? _introVideoController;
  Map<String, dynamic> userData = {};
  bool isDescriptionLoading = true;
  String? userDescription;
  double? _teacherRating = 0.0;
  List<DocumentSnapshot> _filteredLessons = [];
  List<Lesson> savedLessons = [];
  bool _isLocationLoading = false;
  bool _locationPermissionDenied = false;
  Position? _currentPosition;
  String? currentUserRole; // To store the current user's role

  StreamSubscription? _followStatusSubscription;
  StreamSubscription? _followersCountSubscription;
  StreamSubscription? _followingCountSubscription;
  StreamSubscription? _userDataSubscription;

  Future<void> _fetchUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (mounted) {
      setState(() {
        userData = doc.data() ?? {};
      });
    }
  }

  Future<void> _fetchCurrentUserRole() async {
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (mounted) {
        setState(() {
          currentUserRole = doc.data()?['role'] ?? 'student';
        });
      }
    }
  }

  void _setupRealTimeListeners() {
    if (currentUser != null && currentUser!.uid != widget.userId) {
      _followStatusSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followers')
          .doc(currentUser!.uid)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() => isFollowing = snapshot.exists);
        }
      });
    }

    _followersCountSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('followers')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => followersCount = snapshot.size);
      }
    });

    _followingCountSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('following')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => followingCount = snapshot.size);
      }
    });

    _userDataSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          userData = snapshot.data() ?? {};
        });
      }
    });
  }

  Future<void> _toggleFollow() async {
    if (currentUser == null || currentUser!.uid == widget.userId) return;

    setState(() => isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      final targetUserFollowersRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followers')
          .doc(currentUser!.uid);

      final currentUserFollowingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('following')
          .doc(widget.userId);

      if (isFollowing) {
        batch.delete(targetUserFollowersRef);
        batch.delete(currentUserFollowingRef);
      } else {
        batch.set(targetUserFollowersRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'followerId': currentUser!.uid,
        });
        batch.set(currentUserFollowingRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'followingId': widget.userId,
        });
      }

      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${isFollowing ? 'unfollow' : 'follow'}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadFilesFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('media')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .get();

      final images = <String>[];
      final videos = <String>[];
      String? teacherIntroVideo;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final url = data['url'];
        final type = data['type'];
        final isIntroVideo = data['isIntroVideo'] ?? false;

        if (type == 'image') {
          images.add(url);
        } else if (type == 'video' && url is String) {
          if (isIntroVideo && userData['role'] == 'teacher') {
            teacherIntroVideo = url;
          } else {
            videos.add(url);
          }
        }
      }

      if (mounted) {
        setState(() {
          imageUrls = images;
          videoUrls = videos;
          introVideoUrl = teacherIntroVideo;
        });

        if (teacherIntroVideo != null) {
          _introVideoController = VideoPlayerController.network(teacherIntroVideo)
            ..initialize().then((_) {
              if (mounted) {
                setState(() {});
              }
            });
        }
      }
    } catch (e) {
      print('Error loading media: $e');
    }
  }

  Widget _buildVideoThumbnail(String url) {
    return FutureBuilder(
      future: _initializeVideo(url),
      builder: (context, AsyncSnapshot<VideoPlayerController> snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          final controller = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              controller.dispose();
            }
          });
          return Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              const Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 50,
              ),
            ],
          );
        } else {
          return Container(
            color: Colors.black12,
            child: const Center(child: CircularProgressIndicator(
               color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,
            ),),
          );
        }
      },
    );
  }

  Future<VideoPlayerController> _initializeVideo(String url) async {
    final controller = VideoPlayerController.network(url);
    await controller.initialize();
    return controller;
  }

  Future<String?> _fetchDescription() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      final role = userDoc.data()?['role'] ?? 'student';
      final collectionName =
          role == 'teacher' ? 'teacher_description' : 'student_description';

      final descDoc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(widget.userId)
          .get();

      return descDoc.data()?['description'];
    } catch (e) {
      print('Error fetching description: $e');
      return null;
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
      _isLocationLoading =true;
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
    if (_currentPosition == null) return lessons;

    List<DocumentSnapshot> filtered = [];

    for (var lesson in lessons) {
      final lessonData = lesson.data() as Map<String, dynamic>;
      final teacherId = lessonData['teacherId'];

      try {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .get();
        final teacherData = teacherDoc.data() as Map<String, dynamic>?;

        if (teacherData != null &&
            teacherData['latitude'] != null &&
            teacherData['longitude'] != null) {
          final teacherLat = teacherData['latitude'] as double;
          final teacherLng = teacherData['longitude'] as double;

          double distanceInMeters = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            teacherLat,
            teacherLng,
          );

          double distanceInKm = distanceInMeters / 1000;

          if (distanceInKm <= maxDistanceKm) {
            filtered.add(lesson);
          }
        }
      } catch (e) {
        filtered.add(lesson);
      }
    }

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
        .where((doc) => doc.data().containsKey('lessonId') && doc['lessonId'] is String)
        .map((doc) => doc['lessonId'] as String)
        .toSet();

    return lessons.where((lesson) => !takenLessonIds.contains(lesson.id)).toList();
  }

  Future<void> _joinLesson(String lessonDocId, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final lessonRef = FirebaseFirestore.instance.collection('lessons').doc(lessonDocId);
    final takenLessonsRef = FirebaseFirestore.instance.collection('takenLessons');

    try {
      final paymentSuccess = await StripeService.instance.makePayment(180);

      if (!paymentSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
              content: Text('Payment failed or cancelled'),
            ),
          );
        }
        return;
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final lessonSnapshot = await transaction.get(lessonRef);
        if (!lessonSnapshot.exists) throw Exception("Lesson does not exist!");

        final lessonData = lessonSnapshot.data()!;
        final currentStudentCount = (lessonData['currentStudentCount'] ?? 0) as int;

        if (currentStudentCount >= 8) {
          throw Exception("Lesson is full. You cannot join.");
        }

        final teacherDoc = await transaction.get(
          FirebaseFirestore.instance.collection('users').doc(lessonData['teacherId']),
        );
        final teacherData = teacherDoc.data() as Map<String, dynamic>;
        final teacherName = '${teacherData['name']} ${teacherData['surname']}';

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
        });
      });

      if (mounted) {
        setState(() {
          _filteredLessons.removeWhere((doc) => doc.id == lessonDocId);
        });

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
          .where('teacherId', isEqualTo: widget.userId)
          .orderBy('dateTime', descending: true)
          .get();

      var filtered = await _filterLessonsByDistance(lessonSnapshot.docs, distance);
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
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchCurrentUserRole(); // Fetch current user's role
    _setupRealTimeListeners();
    _loadFilesFromFirestore();
    _fetchDescription().then((desc) {
      if (mounted) {
        setState(() {
          userDescription = desc;
          isDescriptionLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _followStatusSubscription?.cancel();
    _followersCountSubscription?.cancel();
    _followingCountSubscription?.cancel();
    _userDataSubscription?.cancel();
    _introVideoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = currentUser?.uid == widget.userId;
    final role = userData['role'] ?? 'student';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[100],
                backgroundImage: userData['profileImageUrl'] != null
                    ? NetworkImage(userData['profileImageUrl'])
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                userData['name'] ?? 'Unknown User',
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xff1B1212),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xff1B1212)),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!isOwnProfile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isFollowing ? Colors.red : const Color(0xff1B1212),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isLoading ? null : _toggleFollow,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,),
                          )
                        : Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: isFollowing ? Colors.red : const Color(0xff1B1212),
                              fontSize: 20,
                            ),
                          ),
                  ),
                ],
              ),
            const SizedBox(height: 30),
            if (role == 'teacher') ...[
              const Text(
                'Introduction Video',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1B1212),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xff1B1212), width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: introVideoUrl == null || _introVideoController == null
                    ? const Center(
                        child: Text(
                          'No introduction video available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xff1B1212),
                          ),
                        ),
                      )
                    : _introVideoController!.value.isInitialized
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: _introVideoController!.value.aspectRatio,
                                child: VideoPlayer(_introVideoController!),
                              ),
                              IconButton(
                                icon: Icon(
                                  _introVideoController!.value.isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  color: Colors.white,
                                  size: 50,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_introVideoController!.value.isPlaying) {
                                      _introVideoController!.pause();
                                    } else {
                                      _introVideoController!.play();
                                    }
                                  });
                                },
                              ),
                            ],
                          )
                        : const Center(child: CircularProgressIndicator(
                           color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,
                        ),),
              ),
              const SizedBox(height: 20),
              // Conditionally show Teacher Lessons ListTile
              if (role == 'teacher' &&
                  (currentUserRole == 'student' || currentUserRole == null))
                ListTile(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) {
                        String teacherName = userData['name'] != null
                            ? userData['surname'] != null
                                ? "${userData['name']} ${userData['surname']}'s Lessons"
                                : "${userData['name']}'s Lessons"
                            : "Teacher's Lessons";

                        return Container(
                          height: MediaQuery.of(context).size.height * 0.9,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  teacherName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 25,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: _isLocationLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            backgroundColor: Color(0xff1B1212),
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
                                                  .where('teacherId', isEqualTo: widget.userId)
                                                  .orderBy('dateTime', descending: true)
                                                  .snapshots(),
                                              builder: (context, lessonSnapshot) {
                                                if (!mounted) return const SizedBox.shrink();

                                                if (lessonSnapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Center(
                                                    child: CircularProgressIndicator(
                                                    
                                                       color:  Color(0xff1B1212),
                                                        backgroundColor: Colors.white,
                                                    ),
                                                  );
                                                }

                                                if (lessonSnapshot.hasError ||
                                                    !lessonSnapshot.hasData) {
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
                                                    final lessonData = lessonDoc.data()
                                                        as Map<String, dynamic>;
                                                    final teacherId = lessonData['teacherId'];
                                                    final lessonDocId = lessonDoc.id;
                                                    final currentStudentCount =
                                                        (lessonData['currentStudentCount']
                                                                as int?) ??
                                                            0;

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
                                                               color:  Color(0xff1B1212),
                                                               backgroundColor: Colors.white,
                                                              strokeWidth: 4,
                                                            ),
                                                          );
                                                        }

                                                        if (teacherSnapshot.hasError ||
                                                            !teacherSnapshot.hasData) {
                                                          return const Center(
                                                              child:
                                                                  Text('Error fetching teacher data'));
                                                        }

                                                        final teacher = teacherSnapshot.data!.data()
                                                            as Map<String, dynamic>?;
                                                        final teacherRole =
                                                            teacher?['role'] ?? 'student';
                                                        final teacherName =
                                                            teacher?['name'] ?? 'Unknown Teacher';
                                                        final teacherSurname =
                                                            teacher?['surname'] ?? '';

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
                                                                        stream: FirebaseFirestore
                                                                            .instance
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

                                                                          if (snapshot.hasError) {
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
                                                                            final imageUrl =
                                                                                userData[
                                                                                        'profileImageUrl'] ??
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
                                                                                  color: Colors.yellow[700]),
                                                                              Text(
                                                                                _teacherRating!
                                                                                    .toStringAsFixed(1),
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
                                                                                      color: Colors.blue)),
                                                                              content: const Text(
                                                                                'Derse katılacağınıza emin misiniz? Satın aldiktan sonra katılımınız iptal edilemez',
                                                                                style:
                                                                                    TextStyle(fontSize: 20),
                                                                              ),
                                                                              actions: [
                                                                                TextButton(
                                                                                  onPressed: () =>
                                                                                      Navigator.pop(context),
                                                                                  child: const Text(
                                                                                      'Onaylamiyorum',
                                                                                      style: TextStyle(
                                                                                        color: Colors.red,
                                                                                        fontSize: 17,
                                                                                      )),
                                                                                ),
                                                                                TextButton(
                                                                                  onPressed: () async {
                                                                                    Navigator.of(context)
                                                                                        .pop();

                                                                                    try {
                                                                                      final paymentSuccess =
                                                                                          await StripeService
                                                                                              .instance
                                                                                              .makePayment(180);

                                                                                      if (paymentSuccess) {
                                                                                        await _joinLesson(
                                                                                            lessonDocId,
                                                                                            context);
                                                                                        if (context.mounted) {
                                                                                          setState(() {
                                                                                            _filteredLessons
                                                                                                .removeWhere(
                                                                                                    (doc) =>
                                                                                                        doc.id ==
                                                                                                        lessonDocId);
                                                                                          });
                                                                                          await removeLesson(
                                                                                              index);
                                                                                          ScaffoldMessenger.of(
                                                                                                  context)
                                                                                              .showSnackBar(
                                                                                            const SnackBar(
                                                                                              behavior:
                                                                                                  SnackBarBehavior
                                                                                                      .floating,
                                                                                              backgroundColor:
                                                                                                  Colors.green,
                                                                                              content: Text(
                                                                                                  'Payment and lesson join successful!'),
                                                                                            ),
                                                                                          );
                                                                                        }
                                                                                      } else {
                                                                                        if (context.mounted) {
                                                                                          ScaffoldMessenger.of(
                                                                                                  context)
                                                                                              .showSnackBar(
                                                                                            const SnackBar(
                                                                                              behavior:
                                                                                                  SnackBarBehavior
                                                                                                      .floating,
                                                                                              backgroundColor:
                                                                                                  Colors.red,
                                                                                              content: Text(
                                                                                                  'Payment failed or cancelled'),
                                                                                            ),
                                                                                          );
                                                                                        }
                                                                                      }
                                                                                    } catch (e) {
                                                                                      if (context.mounted) {
                                                                                        ScaffoldMessenger.of(
                                                                                                context)
                                                                                            .showSnackBar(
                                                                                          SnackBar(
                                                                                            behavior:
                                                                                                SnackBarBehavior
                                                                                                    .floating,
                                                                                            backgroundColor:
                                                                                                Colors.red,
                                                                                            content: Text(
                                                                                                'Error: ${e.toString()}'),
                                                                                          ),
                                                                                        );
                                                                                      }
                                                                                    }
                                                                                  },
                                                                                  child: const Text(
                                                                                      'Onaylıyorum',
                                                                                      style: TextStyle(
                                                                                        color: Colors.blue,
                                                                                        fontSize: 17,
                                                                                      )),
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
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  title: const Text('Teacher Lessons'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 15),
                ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Description',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xff1B1212),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xff1B1212), width: 2),
              ),
              child: isDescriptionLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                         color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,
                      ),
                    )
                  : Text(
                      userDescription?.isNotEmpty == true
                          ? userDescription!
                          : 'No description available',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xff1B1212),
                      ),
                    ),
            ),
            Column(
              children: [
                const TabBar(
                  indicatorColor: Color(0xff1B1212),
                  labelColor: Color(0xff1B1212),
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(icon: Icon(Icons.image, size: 30)),
                    Tab(icon: Icon(Icons.video_library, size: 30)),
                  ],
                ),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    children: [
                      GridView.builder(
                        itemCount: imageUrls.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                        ),
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.all(5),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              imageUrls[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      GridView.builder(
                        itemCount: videoUrls.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                        ),
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.all(5),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildVideoThumbnail(videoUrls[index]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
