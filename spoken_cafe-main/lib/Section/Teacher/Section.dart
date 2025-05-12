import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spokencafe/Map/Map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:spokencafe/profile/All_Users_Profile/All_Users_Profile.dart';

final itemsProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);
final selectedIndexProvider = StateProvider<int?>((ref) => null);
final currentUserProvider = FutureProvider<User?>((ref) async {
  return FirebaseAuth.instance.currentUser;
});

class Section extends ConsumerStatefulWidget {
  const Section({super.key});

  @override
  ConsumerState<Section> createState() => _SectionState();
}

class _SectionState extends ConsumerState<Section> {
  int selectindex = 0;
  bool _isLoading = true;
  
  List<String> countminutes = [
    '20',
    '40',
    '50',
    '60',
    '70',
    '80',
    '90',
    '100',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedItems();
  }

  Future<void> _saveItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = ref.read(itemsProvider);
      final jsonString = jsonEncode(items.map((item) {
        return {
          'speakLevel': item['speakLevel'],
          'dateTime': item['dateTime'].toIso8601String(),
          'description': item['description'],
        };
      }).toList());
      await prefs.setString('savedItems', jsonString);
    } catch (e) {
      debugPrint('Error saving items: $e');
    }
  }

  Future<void> _loadSavedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('savedItems');
      if (jsonString != null) {
        final List<dynamic> decodedData = jsonDecode(jsonString);
        final List<Map<String, dynamic>> savedItems = decodedData.map((item) {
          return {
            'speakLevel': item['speakLevel'],
            'dateTime': DateTime.parse(item['dateTime']),
            'description': item['description'],
          };
        }).toList();
        ref.read(itemsProvider.notifier).update((state) => savedItems);
      }
    } catch (e) {
      debugPrint('Error loading items: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> addItem(String speakLevel, DateTime dateTime, String description) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('lessons').doc();
    await docRef.set({
      'speakLevel': speakLevel,
      'dateTime': Timestamp.fromDate(dateTime),
      'description': description,
      'teacherId': user.uid,
      'lessonId': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    ref.read(itemsProvider.notifier).update((state) => [
      {
        'speakLevel': speakLevel,
        'dateTime': dateTime,
        'description': description,
        'teacherId': user.uid,
        'lessonId': docRef.id,
      },
      ...state,
    ]);
    _saveItems();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(
         color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,
      ),),),
      error: (error, stack) => Scaffold(body: Center(child: Text('Error: $error'))),
      data: (currentUser) {
        if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(
           color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,
        ),),);
        if (currentUser == null) return const Scaffold(body: Center(child: Text('Please sign in')));

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
                .collection('lessons')
                .where('teacherId', isEqualTo: currentUser.uid)
                .orderBy('dateTime', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(
                   color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,
                ),);
              }
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No Lessons',
                      style: TextStyle(fontSize: 20, color: Color(0xff1B1212), fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }

//               final items = snapshot.data!.docs.map((doc) {
//                 final data = doc.data() as Map<String, dynamic>;
//                 dynamic dateTimeField = data['dateTime'];

//                 DateTime dateTime;
//                 if (dateTimeField is Timestamp) {
//                   dateTime = dateTimeField.toDate();
//                 } else if (dateTimeField is String) {
//                   dateTime = DateTime.tryParse(dateTimeField) ?? DateTime.now();
//                 } else {
//                   dateTime = DateTime.now();
//                 }

//                           // Replace this code:
//               GeoPoint geoPoint = data['location'].cast<GeoPoint>();
//               gmaps.LatLng? location;
//               if (geoPoint != null) {
//                 location = gmaps.LatLng(
//                   geoPoint.latitude,
//                   geoPoint.longitude,
//                 );
//               }

// // With this more robust version:
//             dynamic locationData = data['location'];

//             if (locationData != null) {
//               if (locationData is GeoPoint) {
//                 location = gmaps.LatLng(
//                   locationData.latitude,
//                   locationData.longitude,
//                 );
//               } else if (locationData is List) {
//                 // Handle case where location is stored as [latitude, longitude]
//                 if (locationData.length >= 2) {
//                   try {
//                     final lat = locationData[0] as double;
//                     final lng = locationData[1] as double;
//                     location = gmaps.LatLng(lat, lng);
//                   } catch (e) {
//                     debugPrint('Error parsing location list: $e');
//                   }
//                 }
//               }
//             }
//                 return {
//                   'speakLevel': data['speakLevel'] ?? 'No Level',
//                   'dateTime': dateTime,
//                   'description': data['description'] ?? 'No Description',
//                   'lessonId': doc.id,
//                   'teacherId': data['teacherId'],
//                   'location': location,
//                 };
//               }).toList();
                      final items = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        dynamic dateTimeField = data['dateTime'];

                        DateTime dateTime;
                        if (dateTimeField is Timestamp) {
                          dateTime = dateTimeField.toDate();
                        } else if (dateTimeField is String) {
                          dateTime = DateTime.tryParse(dateTimeField) ?? DateTime.now();
                        } else {
                          dateTime = DateTime.now();
                        }

                        // Fixed location handling
                        gmaps.LatLng? location;
                        if (data['location'] != null) {
                          if (data['location'] is GeoPoint) {
                            final geoPoint = data['location'] as GeoPoint;
                            location = gmaps.LatLng(geoPoint.latitude, geoPoint.longitude);
                          } else if (data['location'] is List) {
                            final locList = data['location'] as List;
                            if (locList.length >= 2) {
                              location = gmaps.LatLng(
                                (locList[0] as num).toDouble(),
                                (locList[1] as num).toDouble(),
                              );
                            }
                          }
                        }

                        return {
                          'speakLevel': data['speakLevel'] ?? 'No Level',
                          'dateTime': dateTime,
                          'description': data['description'] ?? 'No Description',
                          'lessonId': doc.id,
                          'teacherId': data['teacherId'],
                          'location': location,
                        };
                      }).toList();
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
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
                                          child: Icon(Icons.person, color: Colors.white),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      FutureBuilder(
                                        future: _getUserName(currentUser.uid),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const Text('Loading...', style: TextStyle(fontSize: 16));
                                          }
                                          return Text(
                                            snapshot.data ?? 'Guest User',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xff1B1212),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 5),
                                      InkWell(
                                        onTap: () {},
                                        child: Row(
                                          children: [
                                            Icon(Icons.star, color: Colors.yellow[700]),
                                            const Text('4.5', style: TextStyle(fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('takenLessons')
                                        .where('lessonId', isEqualTo: item['lessonId'])
                                        .snapshots(),
                                    builder: (context, studentSnapshot) {
                                      final studentCount = studentSnapshot.data?.docs.length ?? 0;
                                      if (studentCount == 0) {
                                        return const SizedBox.shrink(); // Hide minutes when no students
                                      }
                                      final minutesIndex = (studentCount - 1).clamp(0, countminutes.length - 1);
                                      final minutes = countminutes[minutesIndex];
                                      return Text('$minutes Minutes');
                                    },
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      showCupertinoModalBottomSheet(
                                        backgroundColor: Colors.white,
                                        context: context,
                                        builder: (context) => Material(
                                          color: Colors.white,
                                          child: Container(
                                            padding: const EdgeInsets.all(20),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    'Students',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      color: Color(0xff1B1212),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  StreamBuilder<QuerySnapshot>(
                                                    stream: FirebaseFirestore.instance
                                                        .collection('takenLessons')
                                                        .where('lessonId', isEqualTo: item['lessonId'])
                                                        .snapshots(),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                                        return const Center(child: CircularProgressIndicator(
                                                           color:  Color(0xff1B1212),
                                                            backgroundColor: Colors.white,
                                                        ),);
                                                      }
                                                      if (snapshot.hasError) {
                                                        return const Center(child: Text('Error loading students'));
                                                      }
                                                      final students = snapshot.data?.docs ?? [];
                                                      return Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: students.map((doc) {
                                                          final studentId = doc['studentId'];
                                                          return FutureBuilder<DocumentSnapshot>(
                                                            future: FirebaseFirestore.instance
                                                                .collection('users')
                                                                .doc(studentId)
                                                                .get(),
                                                            builder: (context, userSnapshot) {
                                                              if (userSnapshot.connectionState == ConnectionState.waiting) {
                                                                return const ListTile(
                                                                  leading: CircleAvatar(
                                                                    radius: 20,
                                                                    backgroundColor: Colors.blue,
                                                                  ),
                                                                  title: Text('Loading...'),
                                                                );
                                                              }
                                                              final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                                                              return ListTile(
                                                                onTap: () {
                                                                  Navigator.pop(context);
                                                                  Navigator.push(
                                                                    context,
                                                                    PageRouteBuilder(
                                                                      pageBuilder: (
                                                                        context,
                                                                        animation,
                                                                        secondaryAnimation,
                                                                      ) =>
                                                                          AllUsersProfile(userId: studentId),
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
                                                                title: Text(
                                                                  userData?['name'] ?? 'Unknown Student',
                                                                  style: const TextStyle(
                                                                    color: Color(0xff1B1212),
                                                                  ),
                                                                ),
                                                                leading: StreamBuilder<DocumentSnapshot>(
                                                                    stream: FirebaseFirestore.instance
                                                                        .collection('users')
                                                                        .doc(studentId)
                                                                        .snapshots(),
                                                                    builder: (context, snapshot) {
                                                                      if (snapshot.hasData && snapshot.data!.exists) {
                                                                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                                                                        final imageUrl = userData['profileImageUrl'] ?? '';
                                                                        
                                                                        if (imageUrl.isNotEmpty) {
                                                                          return CircleAvatar(
                                                                            radius: 25,
                                                                            backgroundImage: NetworkImage(imageUrl),
                                                                            backgroundColor: Colors.grey, // fallback color
                                                                          );
                                                                        }
                                                                      }
                                                                      
                                                                      // Default avatar if no image is available
                                                                      return  CircleAvatar(
                                                                        radius: 25,
                                                                        backgroundColor: Colors.grey[100],
                                                                        child: Icon(Icons.person, color: Colors.white),
                                                                      );
                                                                    },
                                                                  ),
                                                              
                                                              );
                                                            },
                                                          );
                                                        }).toList(),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    label: Icon(Icons.arrow_forward_ios, color: Color(0xff1B1212)),
                                    icon: StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('takenLessons')
                                          .where('lessonId', isEqualTo: item['lessonId'])
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        final count = snapshot.data?.docs.length ?? 0;
                                        return Text(
                                          'Students $count',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xff1B1212),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item['speakLevel'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Color(0xff1B1212),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  final location = item['location'] as gmaps.LatLng?;
                                  
                                  if (location != null) {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (_, __, ___) => MapScreen(
                                          savedLocation: location,  lessonTitle: item['speakLevel'] ?? 'Lesson Location',
                                        teacherName: item['teacherName'] ?? 'Teacher',
                                        ),
                                        transitionsBuilder: (_, animation, __, child) {
                                          const begin = Offset(1.0, 0.0);
                                          const end = Offset.zero;
                                          const curve = Curves.easeInOut;
                                          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                          return SlideTransition(
                                            position: animation.drive(tween),
                                            child: child,
                                          );
                                        },
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text('Location not available'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                icon: Image.asset('assets/images/maps.png', scale: 13.8),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            DateFormat('yyyy/MM/dd hh:mm a').format(item['dateTime']),
                            style: const TextStyle(
                              color: Color(0xff1B1212),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            item['description'],
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
          ),
        );
      },
    );
  }

  Future<String?> _getUserName(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      return doc.data()?['name'] ?? FirebaseAuth.instance.currentUser?.displayName;
    } catch (e) {
      debugPrint('Error getting user name: $e');
      return FirebaseAuth.instance.currentUser?.displayName;
    }
  }
}
