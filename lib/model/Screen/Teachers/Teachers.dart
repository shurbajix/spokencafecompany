import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart';  // Temporarily disabled
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Teacher {
  final GeoPoint ? location;
  final String? locationId;
  final String? locationName;
  final String name;
  final String email;
  final String phoneNumber;
  final String docId;
  final String? profileImageUrl;
  final String? verificationVideo;
  final String? verificationDocument;
  final String? verificationDescription;
  final bool isApproved;
  final String? rejectionReason;

  Teacher({
    this.locationId,
    this.location,
    this.locationName,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.docId,
    this.profileImageUrl,
    this.verificationVideo,
    this.verificationDocument,
    this.verificationDescription,
    required this.isApproved,
    this.rejectionReason,
  });

  factory Teacher.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    String? rejectionReason;
    final rejectionReasonData = data['rejectionReason'];
    if (rejectionReasonData != null) {
      if (rejectionReasonData is String) {
        rejectionReason = rejectionReasonData;
      } else if (rejectionReasonData is Map) {
        rejectionReason = rejectionReasonData.toString();
      } else {
        rejectionReason = rejectionReasonData.toString();
      }
    }
    
    String? safeStringConversion(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }
    
    return Teacher(
      locationId: data['locationId'] as String?,
       location: data['location'] as GeoPoint?,
       locationName: data['locationName']?.toString(),
      name: data['name']?.toString() ?? 'No name',
      email: data['email']?.toString() ?? 'No email',
      phoneNumber: data['phoneNumber']?.toString() ?? 'No phone number',
      docId: doc.id,
      profileImageUrl: safeStringConversion(data['profileImageUrl']),
      verificationVideo: safeStringConversion(data['verifiedScreenVideoUrl'] ?? data['verificationVideo'] ?? data['introVideoUrl']),
      verificationDocument: safeStringConversion(data['verificationDocument'] ?? data['verifiedScreenDocument'] ?? data['documentUrl']),
      verificationDescription: safeStringConversion(data['verifiedScreenDescription'] ?? data['verificationDescription'] ?? data['description']),
      isApproved: data['isApproved'] == true,
      rejectionReason: rejectionReason,
    );
  }
}

class Teachers extends StatefulWidget {
  const Teachers({super.key});

  @override
  _TeachersState createState() => _TeachersState();
}

class _TeachersState extends State<Teachers> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _showPostsPage = false;
  bool _showGalleryPage = false;
  List<Teacher> teachers = [];
  bool isLoading = true;
  String? errorMessage;
  late CollectionReference _usersCollection;
  bool _hasFetched = false;
  String? _selectedTeacherDocId;
  String _searchQuery = '';
  String _postsSearchQuery = '';
  late TabController _tabController;
  late TabController _lessonsTabController;
  final TextEditingController _postsSearchController = TextEditingController();
  bool _isDelete =  false;

  // Cache for teacher media to avoid refetching
  static final Map<String, Map<String, List<String>>> _mediaCache = {};
  static final Map<String, DateTime> _mediaCacheTime = {};
  static const Duration _cacheExpiry = Duration(minutes: 10);

  // User name caching for lessons
  static final Map<String, String> _userNamesCache = {};
  static final Map<String, DateTime> _userNamesCacheTime = {};
  static const Duration _userNameCacheExpiry = Duration(minutes: 10);

  // Document upload tracking
  static final Map<String, bool> _documentUploadAttempted = {};

  // Description cache
  static final Map<String, String> _descriptionCache = {};
  static final Map<String, DateTime> _descriptionCacheTime = {};
  static const Duration _descriptionCacheExpiry = Duration(minutes: 15);


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _lessonsTabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _lessonsTabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    
    // Initialize posts search listener
    _postsSearchController.addListener(() {
      setState(() {
        _postsSearchQuery = _postsSearchController.text.toLowerCase();
      });
    });
    
    _initializeFirebase();
  }

  void _initializeFirebase() {
    _usersCollection = FirebaseFirestore.instance.collection('users');
    _fetchTeachers();
  }

  void _clearExpiredCache() {
    final now = DateTime.now();
    _userNamesCacheTime.removeWhere((key, time) {
      if (now.difference(time) > _userNameCacheExpiry) {
        _userNamesCache.remove(key);
        return true;
      }
      return false;
    });
  }

  Future<String> _getCachedUserName(String userId) async {
    final now = DateTime.now();
    
    if (_userNamesCache.containsKey(userId) && 
        _userNamesCacheTime.containsKey(userId) &&
        now.difference(_userNamesCacheTime[userId]!) < _userNameCacheExpiry) {
      return _userNamesCache[userId]!;
    }
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      
      if (doc.exists) {
        final data = doc.data()!;
        final name = '${data['name'] ?? ''} ${data['surname'] ?? ''}'.trim();
        final displayName = name.isEmpty ? (data['email'] ?? 'Unknown User') : name;
        
        _userNamesCache[userId] = displayName;
        _userNamesCacheTime[userId] = now;
        
        return displayName;
      }
    } catch (e) {
      print('Error fetching user name for $userId: $e');
    }
    
    return 'Unknown User';
  }

  String _formatDateTime(dynamic dateTime) {
    try {
      DateTime dt;
      if (dateTime is Timestamp) {
        dt = dateTime.toDate();
      } else if (dateTime is String) {
        dt = DateTime.parse(dateTime);
      } else {
        return 'Invalid Date';
      }
      
      final now = DateTime.now();
      final difference = dt.difference(now);
      
      if (difference.isNegative) {
        if (difference.inDays < -1) {
          return '${dt.day}/${dt.month}/${dt.year}';
        } else {
          return 'Started ${difference.inHours.abs()}h ago';
        }
      } else {
        if (difference.inDays > 0) {
          return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else if (difference.inHours > 0) {
          return 'Starts in ${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
        } else {
          return 'Starts in ${difference.inMinutes}m';
        }
      }
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _getLessonStatus(dynamic dateTime) {
    try {
      DateTime dt;
      if (dateTime is Timestamp) {
        dt = dateTime.toDate();
      } else if (dateTime is String) {
        dt = DateTime.parse(dateTime);
      } else {
        return 'Unknown';
      }
      
      final now = DateTime.now();
      final lessonEnd = dt.add(const Duration(hours: 2));
      
      if (now.isBefore(dt)) {
        return 'Upcoming';
      } else if (now.isAfter(dt) && now.isBefore(lessonEnd)) {
        return 'Active';
      } else {
        return 'Completed';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getLessonStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Upcoming':
        return Colors.blue;
      case 'Completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
Widget _buildLessonsSection() {
  return Container(
    margin: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Lessons',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(),
        // All Lessons section with nested tabs
        Expanded(
          child: Column(
            children: [
              // Nested TabBar for All Lessons and Upcoming Lessons
              TabBar(
                controller: _lessonsTabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                tabs: const [
                  Tab(text: 'All Lessons'),
                  Tab(text: 'Upcoming Lessons'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _lessonsTabController,
                  children: [
                    // All Lessons Tab
                    _buildAllLessonsTab(),
                    // Upcoming Lessons Tab
                    _buildUpcomingLessonsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildAllLessonsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lessons')
          .orderBy('dateTime', descending: true) // Show all lessons, newest first
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Loading lessons...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                Text('Error loading lessons: ${snapshot.error}'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, size: 50, color: Colors.grey),
                SizedBox(height: 10),
                Text(
                  'No lessons found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final lessons = snapshot.data!.docs;

        return ListView.builder(
          itemCount: lessons.length,
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            final data = lesson.data() as Map<String, dynamic>;

            final teacherId = data['teacherId']?.toString() ?? '';
            final speakLevel = data['speakLevel']?.toString() ?? 'Unknown';
            final description = data['description']?.toString() ?? 'No description';
            final locationName = data['locationName']?.toString() ?? 'Unknown location';
            final maxStudents = data['maxStudents'] ?? 8;
            final currentStudentCount = data['currentStudentCount'] ?? 0;
            final dateTime = data['dateTime'];
            
            final status = _getLessonStatus(dateTime);
            final formattedDateTime = _formatDateTime(dateTime);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getLessonStatusColor(status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Students: $currentStudentCount/$maxStudents',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        FutureBuilder<String>(
                          future: _getCachedUserName(teacherId),
                          builder: (context, teacherSnapshot) {
                            return Text(
                              teacherSnapshot.data ?? 'Loading teacher...',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.school, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(speakLevel),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(locationName),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(formattedDateTime),
                      ],
                    ),
                          const SizedBox(height: 4),
                          
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  locationName,
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          Row(
                            children: [
                              const Icon(Icons.group, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '$currentStudentCount/$maxStudents students',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                          
                          if (description.isNotEmpty && description != 'No description') ...[
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
        
        
    
    );
  
}

  Widget _buildUpcomingLessonsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lessons')
          .orderBy('dateTime', descending: false) // Show upcoming lessons first
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Loading lessons...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                Text('Error loading lessons: ${snapshot.error}'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, size: 50, color: Colors.grey),
                SizedBox(height: 10),
                Text(
                  'No lessons found in database',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final allLessons = snapshot.data!.docs;
        
        // Filter to show only upcoming lessons
        final lessons = allLessons.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dateTime = data['dateTime'];
          if (dateTime == null) return false;
          
          try {
            DateTime dt;
            if (dateTime is Timestamp) {
              dt = dateTime.toDate();
            } else if (dateTime is String) {
              dt = DateTime.parse(dateTime);
            } else {
              return false;
            }
            
            final now = DateTime.now();
            return now.isBefore(dt); // Only show future lessons
          } catch (e) {
            return false;
          }
        }).toList();

        if (lessons.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, size: 50, color: Colors.grey),
                SizedBox(height: 10),
                Text(
                  'No upcoming lessons found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 10),
                Text(
                  'All lessons in database are past or current',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: lessons.length,
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            final data = lesson.data() as Map<String, dynamic>;

            final teacherId = data['teacherId']?.toString() ?? '';
            final speakLevel = data['speakLevel']?.toString() ?? 'Unknown';
            final description = data['description']?.toString() ?? 'No description';
            final locationName = data['locationName']?.toString() ?? 'Unknown location';
            final maxStudents = data['maxStudents'] ?? 8;
            final currentStudentCount = data['currentStudentCount'] ?? 0;
            final dateTime = data['dateTime'];
            
            final status = _getLessonStatus(dateTime);
            final formattedDateTime = _formatDateTime(dateTime);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getLessonStatusColor(status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Students: $currentStudentCount/$maxStudents',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        FutureBuilder<String>(
                          future: _getCachedUserName(teacherId),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.data ?? 'Loading...',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.school, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(speakLevel),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(locationName),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(formattedDateTime),
                      ],
                    ),
                    if (description.isNotEmpty && description != 'No description') ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Enhance teacher with description from verified_screen_descriptions collection
  Future<Teacher> _enhanceTeacherWithDescription(Teacher teacher) async {
    // If teacher already has a description, return as is
    if (teacher.verificationDescription != null && teacher.verificationDescription!.isNotEmpty) {
      return teacher;
    }
    
    // Try to fetch description from verified_screen_descriptions collection
    final description = await _fetchDescriptionFromVerifiedCollection(teacher.docId);
    if (description != null) {
      // Create a new Teacher object with the enhanced description
      return Teacher(
        locationId: teacher.locationId,
        location: teacher.location,
        locationName: teacher.locationName,
        name: teacher.name,
        email: teacher.email,
        phoneNumber: teacher.phoneNumber,
        docId: teacher.docId,
        profileImageUrl: teacher.profileImageUrl,
        verificationVideo: teacher.verificationVideo,
        verificationDocument: teacher.verificationDocument,
        verificationDescription: description,
        isApproved: teacher.isApproved,
        rejectionReason: teacher.rejectionReason,
      );
    }
    
    return teacher;
  }

  Future<void> _fetchTeachers() async {
    if (_hasFetched) return;
    _hasFetched = true;

    if (mounted) {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    }

    try {
      // Optimized query with cache preference and smaller timeout
      final snapshot = await _usersCollection
          .where('role', isEqualTo: 'teacher')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8)); // Reduced timeout

      // Parallel processing for better performance
      final futures = snapshot.docs.map((doc) async {
        try {
          final teacher = Teacher.fromFirestore(doc);
          // Enhance teacher with description from verified_screen_descriptions collection
          return await _enhanceTeacherWithDescription(teacher);
        } catch (e) {
          print('Error parsing teacher ${doc.id}: $e');
          return null;
        }
      });
      
      final results = await Future.wait(futures);
      final parsedTeachers = results.whereType<Teacher>().toList();
      
      teachers = parsedTeachers;
      print('✅ Fetched ${teachers.length} teachers in optimized mode');

      print('✅ Teachers loaded successfully - fetching images and videos from Firebase');
      
      // Also try to clear all caches and reset Firebase connection
      _resetFirebaseConnection();

      if (mounted) {
      setState(() => isLoading = false);
        // Preload media for better UX  
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _preloadMediaForVisibleTeachers(); 
        });
      } 
    } on FirebaseException catch (e) {
      print('Firebase error: ${e.code} - ${e.message}'); 
      if (mounted) {
      setState(() {
        errorMessage = _handleFirebaseError(e);
        isLoading = false;
      });
      }
    } catch (e) {
      print('General error: $e');
      if (mounted) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
      }
    }
  }

  String _handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You don\'t have permission to access this data.';
      case 'unavailable':
        return 'Network error. Please check your connection.';
      default:
        return 'Firestore error: ${e.message}';
    }
  }

  Future<void> _approve(String docId) async {
    try {
      // Update the user's approval status
      await _usersCollection.doc(docId).update({
        'isApproved': true,
        'rejectionReason': null,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      
      // Also add to accepted_students collection to enable functionality
      await FirebaseFirestore.instance
          .collection('accepted_students')
          .doc(docId)
          .set({
        'userId': docId,
        'isApproved': true,
        'deleteButtonsEnabled': true, // Enable admin delete buttons
        'canPost': true, // Enable posting
        'canComment': true, // Enable commenting
        'canAccessNotifications': true, // Enable notifications
        'canCreateLessons': true, // Enable lesson creation
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin',
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher approved - All features enabled!'),
          backgroundColor: Colors.green,
        ),
      );
      _hasFetched = false;
      await _fetchTeachers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approve failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _reject(String docId, String reason) async {
    try {
      // Update the user's approval status
      await _usersCollection.doc(docId).update({
        'isApproved': false,
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      
      // Remove from accepted_students collection to disable functionality
      await FirebaseFirestore.instance
          .collection('accepted_students')
          .doc(docId)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher rejected - Features disabled'),
          backgroundColor: Colors.orange,
        ),
      );
      _hasFetched = false;
      await _fetchTeachers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reject failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _reactivate(String docId) async {
    try {
      // Update the user's approval status (back to pending)
      await _usersCollection.doc(docId).update({
        'isApproved': false,
        'rejectionReason': null,
        'reactivatedAt': FieldValue.serverTimestamp(),
      });
      
      // Remove from accepted_students collection to disable functionality
      await FirebaseFirestore.instance
          .collection('accepted_students')
          .doc(docId)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher reactivated - Waiting for approval'),
          backgroundColor: Colors.blue,
        ),
      );
      _hasFetched = false;
      await _fetchTeachers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reactivate failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  // Clear cache method for memory management
  void _clearCache() {
    _mediaCache.clear();
    _mediaCacheTime.clear();
    _descriptionCache.clear();
    _descriptionCacheTime.clear();
    print('🧹 Cache cleared');
  }

  // Preload media for visible teachers to improve UX
  void _preloadMediaForVisibleTeachers() {
    final visibleTeachers = _filteredTeachers.take(5); // Preload first 5 teachers
    for (final teacher in visibleTeachers) {
      if (teacher?.docId != null) {
        _fetchTeacherMedia(teacher!.docId).catchError((e) {
          print('⚠️ Preload failed for ${teacher.docId}: $e');
          return null; // Return null to satisfy the Future type requirement
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    _postsSearchController.dispose();
    // Clear cache on dispose to free memory
    _clearCache();
    super.dispose();
  }
  
  Future<void> _downloadImage(String imageUrl) async {
    try {
      // Get file extension
      String extension = '.jpg';
      if (imageUrl.toLowerCase().contains('.png')) {
        extension = '.png';
      } else if (imageUrl.toLowerCase().contains('.jpeg') || imageUrl.toLowerCase().contains('.jpg')) {
        extension = '.jpg';
      }
      
      String fileName = 'SpokenCafe_${DateTime.now().millisecondsSinceEpoch}$extension';

      // Try multiple download approaches - same as working Gallery logic
      bool success = false;
      String savedPath = '';

      // Approach 1: Try saving directly to gallery
      try {
        await _requestPermissions();
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/$fileName';

        // Download file to temp directory
        Dio dio = Dio();
        await dio.download(
          imageUrl,
          tempPath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
            }
          },
        );

        // Try to save to gallery
        // final result = await ImageGallerySaver.saveFile(tempPath);  // Temporarily disabled

        // if (result == true) {
        //   success = true;
        //   savedPath = 'Gallery';
        // }

        // Clean up temp file
        try {
          await File(tempPath).delete();
        } catch (e) {
          print('Error deleting temp file: $e');
        }
      } catch (e) {
        print('Gallery save failed: $e');
      }

      // Approach 2: If gallery save failed, save to Downloads folder
      if (!success) {
        try {
          Directory? downloadsDir;
          
      if (Platform.isAndroid) {
            downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              downloadsDir = await getApplicationDocumentsDirectory();
            }
      } else {
            downloadsDir = await getApplicationDocumentsDirectory();
      }

          if (downloadsDir != null) {
            final filePath = '${downloadsDir.path}/$fileName';

      Dio dio = Dio();
            await dio.download(
              imageUrl,
              filePath,
              onReceiveProgress: (received, total) {
                if (total != -1) {
                  print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
                }
              },
            );

            success = true;
            savedPath = Platform.isAndroid ? 'Downloads folder' : 'Documents folder';
          }
        } catch (e) {
          print('Downloads folder save failed: $e');
        }
      }

      // Approach 3: If all else fails, save to app directory
      if (!success) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final filePath = '${appDir.path}/$fileName';
          
          Dio dio = Dio();
          await dio.download(
            imageUrl,
            filePath,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
              }
            },
          );

          success = true;
          savedPath = 'App folder';
        } catch (e) {
          print('App folder save failed: $e');
        }
      }

      if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved to $savedPath successfully! 📷'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('All download methods failed');
      }

    } catch (e) {
      print('Download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString().split(':').last.trim()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Request permissions like the working Gallery
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
        await Permission.photos.request();
        await Permission.videos.request();
        await Permission.mediaLibrary.request();
      } else if (Platform.isIOS) {
        await Permission.photos.request();
      }
    } catch (e) {
      print('Permission request error: $e');
    }
  }
  
  List<Teacher> get _filteredTeachers {
    try {
      if (_searchQuery.isEmpty) {
        final teachersByTab = _getTeachersByTab();
        return teachersByTab.isNotEmpty ? teachersByTab : [];
      }
      
      final q = _searchQuery.toLowerCase();
      final teachersByTab = _getTeachersByTab();
      final filtered = teachersByTab.where((t) {
        return t.name.toLowerCase().contains(q) ||
            t.email.toLowerCase().contains(q) ||
            t.phoneNumber.toLowerCase().contains(q);
      }).toList();
      
      return filtered.isNotEmpty ? filtered : [];
    } catch (e) {
      print('Error in _filteredTeachers: $e');
      return [];
    }
  }

  List<Teacher> _getTeachersByTab() {
    try {
      if (!_tabController.hasListeners || _tabController.length != 3) {
        return teachers;
      }
      if (_tabController.index < 0 || _tabController.index >= 3) {
        return teachers;
      }
      
      switch (_tabController.index) {
        case 0:
          return teachers.where((t) => !t.isApproved && !_isRejected(t)).toList();
        case 1:
          return teachers.where((t) => t.isApproved).toList();
        case 2:
          return teachers.where((t) => _isRejected(t)).toList();
        default:
          return teachers;
      }
    } catch (e) {
      print('Error in _getTeachersByTab: $e');
      return teachers;
    }
  }

  bool _isRejected(Teacher teacher) {
    return teacher.rejectionReason != null;
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.avi') ||
        lower.contains('.wmv') ||
        lower.contains('.flv') ||
        lower.contains('.mkv') ||
        lower.contains('.webm') ||
        lower.contains('.m4v') ||
        lower.contains('video') ||
        lower.contains('.3gp');
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) {
          print('🖼️ Full screen image error: $error');
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, color: Colors.grey, size: 100),
                  SizedBox(height: 16),
                  Text('Image Preview', style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            ),
          );
        },
      ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_tabController.hasListeners) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Top-level tab controller for Teacher List and All Lessons
    final _mainTabController = TabController(length: 2, vsync: this);

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: Drawer(
        width: 700,
        child: _showPostsPage
            ? _buildPostsPage()
            : _showGalleryPage
                ? _buildGalleryPage()
                : _buildOriginalDrawerContent(),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _mainTabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'Teacher List', icon: Icon(Icons.people)),
              Tab(text: 'All Lessons', icon: Icon(Icons.menu_book)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _mainTabController,
              children: [
                // Teacher List tab - full screen
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xff1B1212)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xff1B1212)),
                          ),
                          hintText: 'Search by name, email or phone',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              children: [
                                Text('Underlines', style: TextStyle(fontSize: 20)),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Column(
                              children: [
                                Text('Underlines', style: TextStyle(fontSize: 20)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        // Remove fixed height, use Expanded for full screen
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                "Teachers List",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Divider(),
                            TabBar(
                              controller: _tabController,
                              onTap: (index) {
                                if (index >= 0 && index < 3) {
                                  setState(() {});
                                }
                              },
                              labelColor: Colors.black,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Colors.blue,
                              tabs: const [
                                Tab(
                                  icon: Icon(Icons.person_add,color: Colors.black,),
                                  text: 'New Teachers',
                                ),
                                Tab(
                                  icon: Icon(Icons.check_circle,color: Colors.green,),
                                  text: 'Active Teachers',
                                ),
                                Tab(
                                  icon: Icon(Icons.cancel,color: Colors.red,),
                                  text: 'Rejected Teachers',
                                ),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildTeachersList(),
                                  _buildTeachersList(),
                                  _buildTeachersList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Second tab: All Lessons
                _buildLessonsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachersList() {
    final filteredTeachers = _filteredTeachers;
    
    return isLoading
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xff1B1212),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading teachers...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This should take only a few seconds',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          )
        : errorMessage != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        _hasFetched = false;
                        _fetchTeachers();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff1B1212),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : filteredTeachers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No teachers found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or check back later',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      _hasFetched = false;
                      // Clear cache for fresh data
                      _mediaCache.clear();
                      _mediaCacheTime.clear();
                      await _fetchTeachers();
                    },
                    child: Scrollbar(
                      controller: _scrollController,
                      thickness: 8,
                      radius: const Radius.circular(10),
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredTeachers.length,
                        physics: const AlwaysScrollableScrollPhysics(), // Better for RefreshIndicator
                        itemBuilder: (context, index) {
                          if (index >= filteredTeachers.length || index < 0) {
                            return const SizedBox.shrink();
                          }
                          
                          final t = filteredTeachers[index];
                          if (t == null) {
                            return const SizedBox.shrink();
                          }
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: (!t.isApproved && !_isRejected(t)) ? Colors.green.withOpacity(0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: (!t.isApproved && !_isRejected(t)) ? Border.all(color: Colors.green.withOpacity(0.3), width: 1) : null,
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                            trailing: SizedBox(
                              width: 279,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_tabController.index == 0)
                                    Expanded(
                                      child: TextButton(
                                        onPressed: t.isApproved
                                            ? null
                                            : () => _approve(t.docId),
                                        child: Text(
                                          'Accept',
                                          style: TextStyle(
                                            color: t.isApproved
                                                ? Colors.grey
                                                : Colors.green,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_tabController.index == 0)
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              final ctrl = TextEditingController();
                                              return AlertDialog(
                                                backgroundColor: Colors.white,
                                                title:
                                                    const Text('Reason for rejection'),
                                                content: TextFormField(
                                                  controller: ctrl,
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(10),
                                                    ),
                                                    hintText: 'Enter reason',
                                                  ),
                                                ),
                                                
                                                actions: [
                                                  CheckboxListTile(value: _isDelete, onChanged: (newDelete){
                                                    newDelete = _isDelete;
                                                  },activeColor: Colors.red,checkColor: Colors.amber,),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text(
                                                      'Cancel',
                                                      style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 20),
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      _reject(
                                                          t.docId, ctrl.text.trim());
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text(
                                                      'Reject',
                                                      style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 20),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        child: const Text(
                                          'Delete',
                                          style:
                                              TextStyle(color: Colors.red, fontSize: 20),
                                        ),
                                      ),
                                    ),
                                  // Show Delete button for active teachers (tab 1)
                                  if (_tabController.index == 1)
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              final ctrl = TextEditingController();
                                              return AlertDialog(
                                                backgroundColor: Colors.white,
                                                title: const Text('Reason for deletion'),
                                                content: TextFormField(
                                                  controller: ctrl,
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(10),
                                                    ),
                                                    hintText: 'Enter reason',
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text(
                                                      'Cancel',
                                                      style: TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 20),
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      _reject(
                                                          t.docId, ctrl.text.trim());
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 20),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        child: const Text(
                                          'Delete',
                                          style:
                                              TextStyle(color: Colors.red, fontSize: 20),
                                        ),
                                      ),
                                    ),
                                  if (_tabController.index == 2)
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => _reactivate(t.docId),
                                        child: const Text(
                                          'Reactivate',
                                          style: TextStyle(
                                              color: Colors.blue, fontSize: 20),
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () async {
                                        setState(() {
                                          _selectedTeacherDocId = t.docId;
                                          _showPostsPage = false;
                                          _showGalleryPage = false; // Show teacher details first
                                        });
                                        
                                        // Check for pending documents when opening teacher profile
                                        await _checkAndUploadPendingDocuments(t);
                                        
                                        Scaffold.of(context).openEndDrawer();
                                      },
                                      child: const Text(
                                        'View',
                                        style: TextStyle(
                                            color: Colors.black, fontSize: 20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            title: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildSafeProfileImage(
                                  imageUrl: t.profileImageUrl,
                                  radius: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Name: ${t.name}',
                                          overflow: TextOverflow.ellipsis),
                                      Text('Email: ${t.email}',
                                          overflow: TextOverflow.ellipsis),
                                      Text('Phone: ${t.phoneNumber}',
                                          overflow: TextOverflow.ellipsis),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(t),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusText(t),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (t.rejectionReason != null && t.rejectionReason!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Reason: ${t.rejectionReason}',
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        },
                      ),
                    ),
                  );
  }

  Widget _buildOriginalDrawerContent() {
    if (_selectedTeacherDocId == null) {
      return const Center(child: Text('Please select a teacher to view their profile'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _usersCollection.doc(_selectedTeacherDocId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading teacher data'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No teacher data found for this user'),
                ElevatedButton(
                  onPressed: () => setState(() => _selectedTeacherDocId = null),
                  child: const Text('Back'),
                ),
              ],
            ),
          );
        }
        final teacher = Teacher.fromFirestore(snapshot.data!);
        final teacherData = snapshot.data!.data() as Map<String, dynamic>;
        
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Enhanced Header with Teacher Info
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff1B1212), Color(0xff2D2D2D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => setState(() => _selectedTeacherDocId = null),
                          ),
                          const Expanded(
                            child: Text(
                              'Teacher Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 48), // Balance the back button
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSafeProfileImage(
                        imageUrl: teacher.profileImageUrl,
                        radius: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        teacher.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(teacher),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusText(teacher),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Account Information Section
              _buildInfoSection(
                'Account Information',
                Icons.account_circle,
                [
                  _buildInfoRow('User ID', _selectedTeacherDocId!, Icons.fingerprint),
                  _buildInfoRow('Account Type', 'Teacher', Icons.school),
                   if (teacher.location != null)
      _buildInfoRow(
        'Location', 
        teacher.locationName ?? 
        '${teacher.location!.latitude.toStringAsFixed(6)}, ${teacher.location!.longitude.toStringAsFixed(6)}',
        Icons.location_on,
      ),
      if (teacher.locationName != null)
      _buildInfoRow(
        'Location',
        teacher.locationName!,
        Icons.location_on,
      ),
                  if (teacherData['createdAt'] != null)
                    _buildInfoRow('Joined', _formatDateTime(teacherData['createdAt']), Icons.calendar_today),
                  if (teacherData['lastLoginAt'] != null)
                    _buildInfoRow('Last Login', _formatDateTime(teacherData['lastLoginAt']), Icons.login),
                  if (teacherData['isVerified'] != null)
                    _buildInfoRow('Email Verified', teacherData['isVerified'] ? 'Yes' : 'No', Icons.verified),
                ],
              ),

              // Contact Information Section
              _buildInfoSection(
                'Contact Information',
                Icons.contact_page,
                [
                  _buildInfoRow('Email', teacher.email, Icons.email),
                  _buildInfoRow('Phone', teacher.phoneNumber, Icons.phone),
                  if (teacherData['address'] != null)
                    _buildInfoRow('Address', teacherData['address'].toString(), Icons.location_on),
                  if (teacherData['dateOfBirth'] != null)
                    _buildInfoRow('Date of Birth', teacherData['dateOfBirth'].toString(), Icons.cake),
                  if (teacherData['gender'] != null)
                    _buildInfoRow('Gender', teacherData['gender'].toString(), Icons.person_outline),
                ],
              ),

              // Professional Information Section
              _buildInfoSection(
                'Professional Information',
                Icons.work,
                [
                  if (teacherData['experience'] != null)
                    _buildInfoRow('Experience', teacherData['experience'].toString(), Icons.timeline),
                  if (teacherData['education'] != null)
                    _buildInfoRow('Education', teacherData['education'].toString(), Icons.school),
                  if (teacherData['specialization'] != null)
                    _buildInfoRow('Specialization', teacherData['specialization'].toString(), Icons.star),
                  if (teacherData['languages'] != null)
                    _buildInfoRow('Languages', teacherData['languages'].toString(), Icons.language),
                  if (teacherData['certifications'] != null)
                    _buildInfoRow('Certifications', teacherData['certifications'].toString(), Icons.verified_user),
                ],
              ),

              // Lesson Statistics Section
              _buildLessonStatisticsSection(_selectedTeacherDocId!),

              // Verification Status Section
              _buildVerificationStatusSection(teacher, teacherData),

              // Document Upload Section (for teachers who completed verification but no document)
              if (teacherData['hasCompletedVerifiedScreen'] == true && 
                  (teacher.verificationDocument == null || teacher.verificationDocument!.isEmpty))
                _buildDocumentUploadSection(teacher, teacherData),

              // Introduction Video Section
              _buildVideoSection(teacher),

              // Verification Documents Section
              _buildDocumentsSection(teacher, teacherData),

              // Description Section
              if (teacher.verificationDescription != null && teacher.verificationDescription!.isNotEmpty)
                _buildInfoSection(
                  'Description',
                  Icons.description,
                  [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        teacher.verificationDescription!,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ],
                ),

              // Additional Information Section
              _buildAdditionalInfoSection(teacherData),

              // Social Media & Links Section
              _buildSocialMediaSection(teacherData),

              // Preferences Section
              _buildPreferencesSection(teacherData),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showGalleryPage = true;
                      _showPostsPage = false;
                    });
                    Scaffold.of(context).openEndDrawer();
                  },
                  child: const Text('Go to Gallery'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showPostsPage = true;
                      _showGalleryPage = false;
                    });
                    Scaffold.of(context).openEndDrawer();
                  },
                  child: const Text('Go to Posts'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGalleryPage() {
    if (_selectedTeacherDocId == null) {
      return const Center(child: Text('No teacher selected'));
    }

    return FutureBuilder<Map<String, List<String>>>(
      future: _fetchTeacherMedia(_selectedTeacherDocId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xff1B1212),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading gallery...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fetching images and videos',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading gallery',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No media available',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final mediaData = snapshot.data!;
        final images = mediaData['images'] ?? [];
        final videos = mediaData['videos'] ?? [];

        if (images.isEmpty && videos.isEmpty) {
          return const Center(child: Text('No media found'));
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            persistentFooterButtons: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.red,
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Gallery permission is required to download media',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: _requestPermissions,
                      child: const Text(
                        'Grant Permission',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () {
                  setState(() {
                    _showGalleryPage = false;
                  });
                  Scaffold.of(context).openEndDrawer();
                },
              ),
              title: const Text('Gallery from Posts'),
              actions: [

                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _requestPermissions,
                  tooltip: 'Request Gallery Permissions',
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Images'),
                  Tab(text: 'Videos'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                images.isEmpty
                    ? const Center(child: Text('No images found'))
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.7, // Adjust height to prevent overflow
                          ),
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            final imageUrl = images[index];
                            return _buildImageCard(imageUrl, index);
                          },
                        ),
                      ),
                videos.isEmpty
                    ? const Center(child: Text('No videos found'))
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.8,
                          ),
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          final videoUrl = videos[index];
                            return _buildVideoCard(videoUrl, index);
                          },
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsPage() {
    if (_selectedTeacherDocId == null) {
      return const Center(child: Text('No teacher selected'));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text('Posts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            setState(() {
              _showPostsPage = false;
            });
            Scaffold.of(context).openEndDrawer();
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _postsSearchController,
              decoration: InputDecoration(
                hintText: 'Search posts by content...',
                prefixIcon: const Icon(Icons.search, color: Color(0xff1B1212)),
                suffixIcon: _postsSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xff1B1212)),
                        onPressed: () {
                          _postsSearchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Color(0xff1B1212)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Color(0xff1B1212), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: _selectedTeacherDocId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts found.'));
          }
          final allPosts = snapshot.data!.docs;
          
          // Filter posts based on search query
          final filteredPosts = _postsSearchQuery.isEmpty
              ? allPosts
              : allPosts.where((post) {
                  final postData = post.data() as Map<String, dynamic>;
                  final text = postData['text']?.toString().toLowerCase() ?? '';
                  final description = postData['description']?.toString().toLowerCase() ?? '';
                  return text.contains(_postsSearchQuery) || 
                         description.contains(_postsSearchQuery);
                }).toList();

          if (filteredPosts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _postsSearchQuery.isEmpty ? Icons.post_add : Icons.search_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _postsSearchQuery.isEmpty 
                        ? 'No posts found.' 
                        : 'No posts match your search.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: 0.7,
            ),
            itemCount: filteredPosts.length,
            itemBuilder: (context, index) {
              final postDoc = filteredPosts[index];
              final postData = postDoc.data() as Map<String, dynamic>;
              return _buildPostGridItem(postDoc.id, postData);
            },
          );
        },
      ),
    );
  }

  // Show dialog for deleting post from user's account
  void _showDeleteFromUserDialog(Map<String, dynamic> post) {
    final userName = post['userName']?.toString() ?? 'Unknown User';
    final userId = post['userId']?.toString() ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
         backgroundColor: Colors.white,
        title: const Text(
          'Delete from User Account',
          style: TextStyle(color: Colors.orange),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this post from $userName\'s account?'),
            const SizedBox(height: 16),
            const Text(
              'This will permanently remove the post from the user\'s profile.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deletePostFromUser(post);
              
              // Show dialog asking if want to chat with user
              _showChatOfferDialog(userName, userId);
            },
            child: const Text('Delete from User'),
          ),
        ],
      ),
    );
  }

  // Show dialog for deleting post from control app only
  void _showDeleteFromControlDialog(Map<String, dynamic> post) {
    final userName = post['userName']?.toString() ?? 'Unknown User';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
         backgroundColor: Colors.white,
        title: const Text(
          'Delete from Control App',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to remove this post from the control app?'),
            const SizedBox(height: 16),
            Text(
              'This will only hide the post from the control app. The post will remain on $userName\'s profile.',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deletePostFromControl(post);
            },
            child: const Text('Remove from Control'),
          ),
        ],
      ),
    );
  }

  // Show dialog asking if want to chat with user after deleting their post
  void _showChatOfferDialog(String userName, String userId) {
    if (userId.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
         backgroundColor: Colors.white,
        title: const Text('Offer Help'),
        content: Text(
          'Post deleted from $userName\'s account.\n\nWould you like to chat with $userName to offer help or support?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Thanks'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff1B1212),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _navigateToChat(userId, userName);
            },
            child: const Text('Chat with User'),
          ),
        ],
      ),
    );
  }

  // Navigate to chat screen with specific user
  void _navigateToChat(String userId, String userName) {
    // Since Chat doesn't take parameters, show a snackbar with user info
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to Chat and search for: $userName'),
        backgroundColor: const Color(0xff1B1212),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Delete post from user's account (actual deletion)
  Future<void> _deletePostFromUser(Map<String, dynamic> post) async {
    try {
      final postId = post['id']?.toString();
      final collection = post['collection']?.toString();
      final userId = post['userId']?.toString();
      
      if (postId == null || collection == null) {
        _showSnackBar('Error: Invalid post data', Colors.red);
        return;
      }

      // Show loading
      _showSnackBar('Deleting post from user account...', Colors.orange);

      // Delete from the original collection
      await FirebaseFirestore.instance.collection(collection).doc(postId).delete();

      // If it's a post with media, also delete from media collections
      if (collection == 'posts') {
        final mediaFiles = post['mediaFiles'] as List<dynamic>? ?? [];
        
        for (var mediaUrl in mediaFiles) {
          final url = mediaUrl.toString();
          if (_isVideoUrl(url)) {
            // Find and delete from post_media_videos
            final videoQuery = await FirebaseFirestore.instance
                .collection('post_media_videos')
                .where('url', isEqualTo: url)
                .where('userId', isEqualTo: userId)
                .get();
            
            for (var doc in videoQuery.docs) {
              await doc.reference.delete();
            }
          } else {
            // Find and delete from post_media_images
            final imageQuery = await FirebaseFirestore.instance
                .collection('post_media_images')
                .where('url', isEqualTo: url)
                .where('userId', isEqualTo: userId)
                .get();
            
            for (var doc in imageQuery.docs) {
              await doc.reference.delete();
            }
          }
        }
      }

      _showSnackBar('Post deleted from user account successfully', Colors.green);
      
    } catch (e) {
      print('Error deleting post from user: $e');
      _showSnackBar('Error deleting post: $e', Colors.red);
    }
  }

  // Delete post from control app only (add to hidden list)
  Future<void> _deletePostFromControl(Map<String, dynamic> post) async {
    try {
      final postId = post['id']?.toString();
      final collection = post['collection']?.toString();
      
      if (postId == null || collection == null) {
        _showSnackBar('Error: Invalid post data', Colors.red);
        return;
      }

      // Show loading
      _showSnackBar('Removing post from control app...', Colors.orange);

      // Add to hidden posts collection for control app
      await FirebaseFirestore.instance.collection('control_hidden_posts').doc('${collection}_$postId').set({
        'postId': postId,
        'collection': collection,
        'hiddenAt': FieldValue.serverTimestamp(),
        'hiddenBy': 'control_app', // You can add actual admin user ID here
      });

      _showSnackBar('Post removed from control app', Colors.green);
      
    } catch (e) {
      print('Error removing post from control: $e');
      _showSnackBar('Error removing post: $e', Colors.red);
    }
  }



  // Show snackbar message
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Reset Firebase connection and clear all caches
  Future<void> _resetFirebaseConnection() async {
    try {
      print('🔄 Resetting Firebase connection...');
      
      // Clear image cache
      await DefaultCacheManager().emptyCache();
      print('✅ Image cache cleared');
      
      // Clear Firebase internal caches if possible
      await FirebaseFirestore.instance.clearPersistence();
      print('✅ Firestore cache cleared');
      
      // Force Firebase to re-initialize
      print('🔄 Firebase connection reset complete');
      
    } catch (e) {
      print('⚠️ Error resetting Firebase connection: $e');
      // Continue anyway, as some errors are expected
    }
  }

  // Fetch description from verified_screen_descriptions collection
  Future<String?> _fetchDescriptionFromVerifiedCollection(String userId) async {
    final now = DateTime.now();
    
    // Check cache first
    if (_descriptionCache.containsKey(userId) && 
        _descriptionCacheTime.containsKey(userId) &&
        now.difference(_descriptionCacheTime[userId]!) < _descriptionCacheExpiry) {
      return _descriptionCache[userId];
    }
    
    try {
      final descDoc = await FirebaseFirestore.instance
          .collection('verified_screen_descriptions')
          .doc(userId)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      
      if (descDoc.exists) {
        final description = descDoc.data()?['description'] as String?;
        if (description != null && description.isNotEmpty) {
          _descriptionCache[userId] = description;
          _descriptionCacheTime[userId] = now;
          return description;
        }
      }
    } catch (e) {
      print('Error fetching description from verified_screen_descriptions for $userId: $e');
    }
    
    return null;
  }

  // Check if teacher has completed verification and upload any pending documents
  Future<void> _checkAndUploadPendingDocuments(Teacher teacher) async {
    // Only attempt once per teacher per session
    if (_documentUploadAttempted[teacher.docId] == true) {
      return;
    }
    
    _documentUploadAttempted[teacher.docId] = true;
    
    try {
      print('🔍 Checking for pending documents for teacher: ${teacher.name}');
      
      // Check if teacher has completed verification screen
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacher.docId)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final hasCompletedVerification = userData['hasCompletedVerifiedScreen'] == true;
      final hasVerifiedScreenDescription = userData['verifiedScreenDescription'] != null;
      
      // If teacher has completed verification but no document is uploaded
      if (hasCompletedVerification && hasVerifiedScreenDescription && 
          (teacher.verificationDocument == null || teacher.verificationDocument!.isEmpty)) {
        
        print('📄 Teacher has completed verification but no document uploaded. Checking for local document...');
        
        // Try to find any document in the teacher's data that might be the verification document
        final potentialDocumentFields = [
          'documentImage',
          'verificationImage', 
          'certificateImage',
          'documentUrl',
          'verificationUrl',
        ];
        
        String? documentUrl;
        for (String field in potentialDocumentFields) {
          if (userData[field] != null && userData[field].toString().isNotEmpty) {
            final url = userData[field].toString();
            if (url.contains('http') && (url.contains('.jpg') || url.contains('.jpeg') || url.contains('.png'))) {
              documentUrl = url;
              print('✅ Found potential verification document in field "$field": $url');
              break;
            }
          }
        }
        
        // If we found a document URL, save it as the verification document
        if (documentUrl != null) {
          print('💾 Saving found document as verification document...');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(teacher.docId)
              .update({
            'verificationDocument': documentUrl,
            'verificationDocumentUpdatedAt': FieldValue.serverTimestamp(),
          });
          
          print('✅ Verification document saved successfully');
          
          // Also save to verified_screen_documents collection
          await FirebaseFirestore.instance
              .collection('verified_screen_documents')
              .doc(teacher.docId)
              .set({
            'documentUrl': documentUrl,
            'userId': teacher.docId,
            'uploadedAt': FieldValue.serverTimestamp(),
            'source': 'auto_detected',
          });
          
          print('✅ Document saved to verified_screen_documents collection');
        }
      }
      
    } catch (e) {
      print('⚠️ Error checking for pending documents: $e');
      // Reset the flag so we can try again later
      _documentUploadAttempted[teacher.docId] = false;
    }
  }



  // Safe profile image with Firebase Storage fetching
  Widget _buildSafeProfileImage({
    required String? imageUrl,
    required double radius,
    IconData fallbackIcon = Icons.person,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => CircularProgressIndicator(
                  strokeWidth: radius < 30 ? 2 : 3,
                  color: Colors.white,
                ),
                errorWidget: (context, url, error) {
                  print('🖼️ Profile image error: $error');
                  return Icon(fallbackIcon, size: radius, color: Colors.white);
                },
                httpHeaders: {
                  'User-Agent': 'SpokenCafeController/1.0',
                },
              ),
            )
          : Icon(fallbackIcon, size: radius, color: Colors.white),
    );
  }

  Widget _buildPostGridItem(String postId, Map<String, dynamic> postData) {
    String? getMediaUrl(dynamic mediaFile) {
      if (mediaFile == null) return null;
      if (mediaFile is String) return mediaFile;
      if (mediaFile is Map) {
        if (mediaFile['url'] != null) return mediaFile['url'].toString();
        if (mediaFile['link'] != null) return mediaFile['link'].toString();
        if (mediaFile['src'] != null) return mediaFile['src'].toString();
        return mediaFile.toString();
      }
      return mediaFile.toString();
    }
    
    String? firstMediaUrl;
    final mediaFiles = postData['mediaFiles'];
    if (mediaFiles != null && mediaFiles.isNotEmpty) {
      firstMediaUrl = getMediaUrl(mediaFiles[0]);
    }
    
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with delete buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (postData['text'] != null && postData['text'].isNotEmpty)
            Text(
              postData['text'],
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Delete buttons menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black87),
                onSelected: (value) {
                  final post = {
                    'id': postId,
                    'collection': 'posts', // Assuming posts collection
                    'text': postData['text'],
                    'userId': postData['userId'],
                    'userName': postData['userName'] ?? 'Unknown User',
                    'mediaFiles': postData['mediaFiles'],
                    'createdAt': postData['createdAt'],
                  };
                  
                  if (value == 'delete_user') {
                    _showDeleteFromUserDialog(post);
                  } else if (value == 'delete_control') {
                    _showDeleteFromControlDialog(post);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'delete_user',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Delete from User',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete_control',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Delete from Control',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            ),
          if (postData['description'] != null && postData['description'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
              child: Text(
                postData['description'],
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 8),
          if (firstMediaUrl != null && firstMediaUrl.isNotEmpty)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: firstMediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    print('🖼️ Post image error: $error');
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.grey, size: 50),
                    );
                  },
                ),
              ),
            ),
          IconButton(
            onPressed: () {
              if (firstMediaUrl != null && firstMediaUrl.isNotEmpty) {
                _downloadImage(firstMediaUrl);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No image to download')),
                );
              }
            },
            icon: const Icon(Icons.download),
          ),
        ],
      ),
    );
  }

  String _getStatusText(Teacher teacher) {
    if (teacher.isApproved) {
      return 'Active';
    } else if (_isRejected(teacher)) {
      return 'Rejected';
    } else {
      return 'New';
    }
  }

  Color _getStatusColor(Teacher teacher) {
    if (teacher.isApproved) {
      return Colors.green;
    } else if (_isRejected(teacher)) {
      return Colors.red;
    } else {
      return Colors.amber;
    }
  }

  // Helper method to build info sections
  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xff1B1212), size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff1B1212),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  // Helper method to build info rows
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 18),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Build video section with actual video player
  Widget _buildVideoSection(Teacher teacher) {
    return _buildInfoSection(
      'Introduction Video',
      Icons.video_library,
      [
        if (teacher.verificationVideo != null && teacher.verificationVideo!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video info header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Teacher Introduction Video',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _VideoPlayerWidget(videoUrl: teacher.verificationVideo!),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadVideo(teacher.verificationVideo!),
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff1B1212),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openVideoInFullScreen(teacher.verificationVideo!),
                        icon: const Icon(Icons.fullscreen, size: 18),
                        label: const Text('Full Screen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Icon(
                  Icons.videocam_off,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'No Introduction Video',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Teacher has not uploaded an introduction video yet',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Build documents section
  Widget _buildDocumentsSection(Teacher teacher, Map<String, dynamic> teacherData) {
    return FutureBuilder<List<Widget>>(
      future: _buildDocumentsSectionAsync(teacher, teacherData),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildInfoSection(
            'Documents & Certifications',
            Icons.document_scanner,
            [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        
        final documentWidgets = snapshot.data ?? [];
        
        return _buildInfoSection(
          'Documents & Certifications',
          Icons.document_scanner,
          documentWidgets.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No documents submitted',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Teacher has not uploaded any verification documents yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Documents: ${documentWidgets.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xff1B1212),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...documentWidgets,
                      ],
                    ),
                  ),
                ],
        );
      },
    );
  }

  Future<List<Widget>> _buildDocumentsSectionAsync(Teacher teacher, Map<String, dynamic> teacherData) async {
    List<Widget> documentWidgets = [];
    
    // Debug: Print all available fields for this teacher
    print('🔍 Debugging documents for teacher: ${teacher.name}');
    print('🔍 Teacher verificationDocument: ${teacher.verificationDocument}');
    print('🔍 Available teacherData fields: ${teacherData.keys.toList()}');
    
    // Check for all possible document field variations
    final allDocumentFields = [
      // Main verification document fields
      'verificationDocument',
      'verifiedScreenDocument', 
      'documentUrl',
      'document',
      
      // Additional document fields
      'idDocument',
      'certificateDocument', 
      'diplomaDocument',
      'resumeDocument',
      'teachingLicense',
      'backgroundCheck',
      'referenceLetter',
      'otherDocuments',
      
      // Alternative field names
      'certificate',
      'diploma',
      'resume',
      'license',
      'idCard',
      'passport',
      'cv',
      'credentials',
      
      // Additional document-related fields
      'documentImage',
      'certificateImage',
      'diplomaImage',
      'resumeImage',
      'licenseImage',
    ];

    // First, check the main verification document from Teacher model
    if (teacher.verificationDocument != null && teacher.verificationDocument!.isNotEmpty) {
      print('✅ Found main verification document: ${teacher.verificationDocument}');
      documentWidgets.add(_buildDocumentCard('Verification Document', teacher.verificationDocument!));
    }

    // Check all possible document fields in teacherData
    for (String field in allDocumentFields) {
      if (teacherData[field] != null && teacherData[field].toString().isNotEmpty) {
        final value = teacherData[field].toString();
        print('✅ Found document in field "$field": $value');
        String title = _formatFieldName(field);
        documentWidgets.add(_buildDocumentCard(title, value));
      }
    }

    // Check for any other fields that might contain document URLs
    teacherData.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        final valueStr = value.toString();
        // Check if the value looks like a URL (contains http/https)
        if (valueStr.contains('http') && 
            (valueStr.contains('.jpg') || valueStr.contains('.jpeg') || 
             valueStr.contains('.png') || valueStr.contains('.pdf') ||
             valueStr.contains('firebase') || valueStr.contains('storage'))) {
          // Exclude profile images and videos
          if (!allDocumentFields.contains(key) && 
              !key.toLowerCase().contains('video') &&
              !key.toLowerCase().contains('profile') &&
              !key.toLowerCase().contains('avatar') &&
              !key.toLowerCase().contains('photo') &&
              !key.toLowerCase().contains('image') &&
              // Also exclude if it's the same as the teacher's profile image
              valueStr != teacher.profileImageUrl) {
            print('✅ Found potential document URL in field "$key": $valueStr');
            String title = _formatFieldName(key);
            documentWidgets.add(_buildDocumentCard(title, valueStr));
          }
        }
      }
    });

    // Also check for any image URLs that might be documents (excluding profile images)
    teacherData.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        final valueStr = value.toString();
        // Look for any image URLs that might be documents
        if (valueStr.contains('http') && 
            (valueStr.contains('.jpg') || valueStr.contains('.jpeg') || 
             valueStr.contains('.png')) &&
            !key.toLowerCase().contains('profile') &&
            !key.toLowerCase().contains('avatar') &&
            !key.toLowerCase().contains('photo') &&
            !key.toLowerCase().contains('image') &&
            !allDocumentFields.contains(key) &&
            // Also exclude if it's the same as the teacher's profile image
            valueStr != teacher.profileImageUrl) {
          print('✅ Found potential document image in field "$key": $valueStr');
          String title = _formatFieldName(key);
          documentWidgets.add(_buildDocumentCard(title, valueStr));
        }
      }
    });

    // If no documents found in user data, try to fetch from various collections
    if (documentWidgets.isEmpty) {
      try {
        print('🔍 No documents found in user data, checking various collections...');
        
        // Check verified_screen_documents collection
        final docSnapshot = await FirebaseFirestore.instance
            .collection('verified_screen_documents')
            .doc(teacher.docId)
            .get();
        
        if (docSnapshot.exists) {
          final docData = docSnapshot.data()!;
          final documentUrl = docData['documentUrl']?.toString();
          if (documentUrl != null && documentUrl.isNotEmpty) {
            print('✅ Found document in verified_screen_documents collection: $documentUrl');
            documentWidgets.add(_buildDocumentCard('Verification Document', documentUrl));
          }
        }
        
        // Check teacher_documents collection
        final teacherDocSnapshot = await FirebaseFirestore.instance
            .collection('teacher_documents')
            .doc(teacher.docId)
            .get();
        
        if (teacherDocSnapshot.exists) {
          final docData = teacherDocSnapshot.data()!;
          final documentUrl = docData['documentUrl']?.toString() ?? docData['url']?.toString();
          if (documentUrl != null && documentUrl.isNotEmpty) {
            print('✅ Found document in teacher_documents collection: $documentUrl');
            documentWidgets.add(_buildDocumentCard('Teacher Document', documentUrl));
          }
        }
        
        // Check if there are any documents in the user's posts
        final postsSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: teacher.docId)
            .where('type', isEqualTo: 'document')
            .limit(5)
            .get();
        
        for (var post in postsSnapshot.docs) {
          final postData = post.data();
          final mediaFiles = postData['mediaFiles'] as List<dynamic>?;
          if (mediaFiles != null && mediaFiles.isNotEmpty) {
            for (var media in mediaFiles) {
              final url = media.toString();
              if (url.contains('http') && !url.contains('video')) {
                print('✅ Found document in posts collection: $url');
                documentWidgets.add(_buildDocumentCard('Posted Document', url));
              }
            }
          }
        }
        
      } catch (e) {
        print('⚠️ Error fetching from collections: $e');
      }
    }
    
        print('📄 Total documents found for ${teacher.name}: ${documentWidgets.length}');

    return documentWidgets;
  }

  // Open video in full screen
  void _openVideoInFullScreen(String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
      ),
    );
  }

  // Get appropriate icon for document type
  IconData _getDocumentIcon(String title) {
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('id') || lowerTitle.contains('identity')) {
      return Icons.badge;
    } else if (lowerTitle.contains('certificate') || lowerTitle.contains('certification')) {
      return Icons.verified;
    } else if (lowerTitle.contains('diploma') || lowerTitle.contains('degree')) {
      return Icons.school;
    } else if (lowerTitle.contains('resume') || lowerTitle.contains('cv')) {
      return Icons.description;
    } else if (lowerTitle.contains('license')) {
      return Icons.assignment_turned_in;
    } else if (lowerTitle.contains('background') || lowerTitle.contains('check')) {
      return Icons.security;
    } else if (lowerTitle.contains('reference') || lowerTitle.contains('letter')) {
      return Icons.mail;
    } else if (lowerTitle.contains('verification')) {
      return Icons.verified_user;
    } else {
      return Icons.description;
    }
  }

  // Fetch video and document data from verified_screen_videos collection as fallback
  Future<Map<String, String?>> _fetchVerifiedScreenData(String teacherId) async {
    try {
      final videoDoc = await FirebaseFirestore.instance
          .collection('verified_screen_videos')
          .doc(teacherId)
          .get();

      if (videoDoc.exists) {
        final videoData = videoDoc.data()!;
        return {
          'videoUrl': videoData['videoUrl'] as String?,
          'documentUrl': videoData['documentUrl'] as String?,
        };
      }
    } catch (e) {
      print('Error fetching verified screen data: $e');
    }
    return {'videoUrl': null, 'documentUrl': null};
  }

  // Clear video cache (utility method)
  Future<void> _clearVideoCache() async {
    try {
      final customCacheManager = CacheManager(
        Config(
          'videoCache',
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 50,
          repo: JsonCacheInfoRepository(databaseName: 'videoCache'),
          fileService: HttpFileService(),
        ),
      );
      
      await customCacheManager.emptyCache();
      print('🎬 Video cache cleared successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video cache cleared'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('🎬 Error clearing video cache: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cache: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Build document card
  Widget _buildDocumentCard(String title, String imageUrl) {
    print('🖼️ Building document card for "$title" with URL: $imageUrl');
    
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document header with icon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(
                  _getDocumentIcon(title),
                  size: 20,
                  color: const Color(0xff1B1212),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xff1B1212),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showFullScreenImage(context, imageUrl),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  httpHeaders: {
                    'User-Agent': 'SpokenCafeController/1.0',
                  },
                  placeholder: (context, url) => Container(
                    color: Colors.grey[100],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Loading document...'),
                        ],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    print('🖼️ Document image error for "$title": $error');
                    print('🖼️ Failed URL: $url');
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description, color: Colors.grey, size: 40),
                            SizedBox(height: 8),
                            Text(
                              'Document Preview',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap to view full size',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
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
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadImage(imageUrl),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1B1212),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showFullScreenImage(context, imageUrl),
                  icon: const Icon(Icons.fullscreen, size: 16),
                  label: const Text('View Full'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build additional information section
  Widget _buildAdditionalInfoSection(Map<String, dynamic> teacherData) {
    List<Widget> additionalInfo = [];

    // Add any additional fields from teacherData
    final fieldsToShow = [
      'bio',
      'teachingStyle',
      'availability',
      'hourlyRate',
      'yearsOfExperience',
      'qualifications',
      'subjects',
    ];

    for (String field in fieldsToShow) {
      if (teacherData[field] != null && teacherData[field].toString().isNotEmpty) {
        additionalInfo.add(
          _buildInfoRow(
            _formatFieldName(field),
            teacherData[field].toString(),
            _getIconForField(field),
          ),
        );
      }
    }

    if (additionalInfo.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildInfoSection(
      'Additional Information',
      Icons.info,
      additionalInfo,
    );
  }

  // Build lesson statistics section
  Widget _buildLessonStatisticsSection(String teacherId) {
    return _buildInfoSection(
      'Lesson Statistics',
      Icons.analytics,
      [
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('lessons')
              .where('teacherId', isEqualTo: teacherId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            
            final totalLessons = snapshot.data?.docs.length ?? 0;
            int completedLessons = 0;
            int upcomingLessons = 0;
            int activeLessons = 0;
            
            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final dateTime = data['dateTime'];
                final status = _getLessonStatus(dateTime);
                
                switch (status) {
                  case 'Completed':
                    completedLessons++;
                    break;
                  case 'Upcoming':
                    upcomingLessons++;
                    break;
                  case 'Active':
                    activeLessons++;
                    break;
                }
              }
            }
            
            return Column(
              children: [
                _buildInfoRow('Total Lessons', totalLessons.toString(), Icons.school),
                _buildInfoRow('Completed', completedLessons.toString(), Icons.check_circle),
                _buildInfoRow('Upcoming', upcomingLessons.toString(), Icons.schedule),
                _buildInfoRow('Active', activeLessons.toString(), Icons.play_circle),
              ],
            );
          },
        ),
      ],
    );
  }

  // Build document upload section for teachers who completed verification but no document
  Widget _buildDocumentUploadSection(Teacher teacher, Map<String, dynamic> teacherData) {
    return _buildInfoSection(
      'Document Upload Status',
      Icons.upload_file,
      [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Teacher completed verification but no document uploaded',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This teacher has completed the verification screen but no document was uploaded to Firebase. The document may be stored locally in the verification screen.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await _checkAndUploadPendingDocuments(teacher);
                  // Refresh the teacher data
                  setState(() {});
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Check for Pending Documents'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build verification status section
  Widget _buildVerificationStatusSection(Teacher teacher, Map<String, dynamic> teacherData) {
    List<Widget> verificationInfo = [];
    
    // Approval status
    verificationInfo.add(
      _buildInfoRow(
        'Approval Status',
        teacher.isApproved ? 'Approved' : 'Pending',
        teacher.isApproved ? Icons.check_circle : Icons.pending,
      ),
    );
    
    // Approval date
    if (teacherData['approvedAt'] != null) {
      verificationInfo.add(
        _buildInfoRow(
          'Approved On',
          _formatDateTime(teacherData['approvedAt']),
          Icons.calendar_today,
        ),
      );
    }
    
    // Rejection info
    if (teacher.rejectionReason != null && teacher.rejectionReason!.isNotEmpty) {
      verificationInfo.add(
        _buildInfoRow(
          'Rejection Reason',
          teacher.rejectionReason!,
          Icons.cancel,
        ),
      );
    }
    
    if (teacherData['rejectedAt'] != null) {
      verificationInfo.add(
        _buildInfoRow(
          'Rejected On',
          _formatDateTime(teacherData['rejectedAt']),
          Icons.calendar_today,
        ),
      );
    }
    
    // Verification documents status
    bool hasVideo = teacher.verificationVideo != null && teacher.verificationVideo!.isNotEmpty;
    bool hasDocuments = teacher.verificationDocument != null && teacher.verificationDocument!.isNotEmpty;
    bool hasDescription = teacher.verificationDescription != null && teacher.verificationDescription!.isNotEmpty;
    
    verificationInfo.add(
      _buildInfoRow(
        'Introduction Video',
        hasVideo ? 'Submitted' : 'Not Submitted',
        hasVideo ? Icons.video_library : Icons.video_library_outlined,
      ),
    );
    
    verificationInfo.add(
      _buildInfoRow(
        'Documents',
        hasDocuments ? 'Submitted' : 'Not Submitted',
        hasDocuments ? Icons.description : Icons.description_outlined,
      ),
    );
    
    verificationInfo.add(
      _buildInfoRow(
        'Description',
        hasDescription ? 'Submitted' : 'Not Submitted',
        hasDescription ? Icons.text_fields : Icons.text_fields_outlined,
      ),
    );
    
    return _buildInfoSection(
      'Verification Status',
      Icons.verified_user,
      verificationInfo,
    );
  }

  // Build social media section
  Widget _buildSocialMediaSection(Map<String, dynamic> teacherData) {
    List<Widget> socialInfo = [];
    
    final socialFields = [
      'linkedin',
      'facebook',
      'instagram',
      'twitter',
      'website',
      'youtube',
    ];
    
    for (String field in socialFields) {
      if (teacherData[field] != null && teacherData[field].toString().isNotEmpty) {
        socialInfo.add(
          _buildInfoRow(
            _formatFieldName(field),
            teacherData[field].toString(),
            _getSocialIcon(field),
          ),
        );
      }
    }
    
    if (socialInfo.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _buildInfoSection(
      'Social Media & Links',
      Icons.share,
      socialInfo,
    );
  }

  // Build preferences section
  Widget _buildPreferencesSection(Map<String, dynamic> teacherData) {
    List<Widget> preferenceInfo = [];
    
    final preferenceFields = [
      'notificationPreferences',
      'privacySettings',
      'languagePreference',
      'timezone',
      'currency',
    ];
    
    for (String field in preferenceFields) {
      if (teacherData[field] != null && teacherData[field].toString().isNotEmpty) {
        preferenceInfo.add(
          _buildInfoRow(
            _formatFieldName(field),
            teacherData[field].toString(),
            _getPreferenceIcon(field),
          ),
        );
      }
    }
    
    if (preferenceInfo.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _buildInfoSection(
      'Preferences',
      Icons.settings,
      preferenceInfo,
    );
  }

  // Helper to get social media icons
  IconData _getSocialIcon(String field) {
    switch (field) {
      case 'linkedin':
        return Icons.work;
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'twitter':
        return Icons.flutter_dash;
      case 'website':
        return Icons.web;
      case 'youtube':
        return Icons.play_circle;
      default:
        return Icons.link;
    }
  }

  // Helper to get preference icons
  IconData _getPreferenceIcon(String field) {
    switch (field) {
      case 'notificationPreferences':
        return Icons.notifications;
      case 'privacySettings':
        return Icons.privacy_tip;
      case 'languagePreference':
        return Icons.language;
      case 'timezone':
        return Icons.access_time;
      case 'currency':
        return Icons.attach_money;
      default:
        return Icons.settings;
    }
  }

  // Helper to format field names
  String _formatFieldName(String field) {
    switch (field) {
      case 'bio':
        return 'Biography';
      case 'teachingStyle':
        return 'Teaching Style';
      case 'availability':
        return 'Availability';
      case 'hourlyRate':
        return 'Hourly Rate';
      case 'yearsOfExperience':
        return 'Years of Experience';
      case 'qualifications':
        return 'Qualifications';
      case 'subjects':
        return 'Subjects';
      case 'linkedin':
        return 'LinkedIn';
      case 'facebook':
        return 'Facebook';
      case 'instagram':
        return 'Instagram';
      case 'twitter':
        return 'Twitter';
      case 'website':
        return 'Website';
      case 'youtube':
        return 'YouTube';
      case 'notificationPreferences':
        return 'Notification Preferences';
      case 'privacySettings':
        return 'Privacy Settings';
      case 'languagePreference':
        return 'Language Preference';
      case 'timezone':
        return 'Timezone';
      case 'currency':
        return 'Currency';
      default:
        return field.replaceAll(RegExp(r'([A-Z])'), ' \$1').trim();
    }
  }

  // Helper to get icons for fields
  IconData _getIconForField(String field) {
    switch (field) {
      case 'bio':
        return Icons.person_outline;
      case 'teachingStyle':
        return Icons.psychology;
      case 'availability':
        return Icons.schedule;
      case 'hourlyRate':
        return Icons.attach_money;
      case 'yearsOfExperience':
        return Icons.timeline;
      case 'qualifications':
        return Icons.military_tech;
      case 'subjects':
        return Icons.subject;
      default:
        return Icons.info_outline;
    }
  }

  // Build video card for gallery
  Widget _buildVideoCard(String videoUrl, int index) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video thumbnail/preview
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: Colors.black,
              ),
              child: Stack(
                children: [
                  // Video thumbnail (you could add actual thumbnail generation here)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.grey[800]!,
                          Colors.grey[900]!,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.video_library,
                        size: 40,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  // Play button overlay
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  // Video indicator
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'VIDEO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Video info and actions
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff1B1212),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            minimumSize: const Size(0, 28),
                          ),
                          child: const Text('Play', style: TextStyle(fontSize: 10)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 32,
                        height: 28,
                        child: IconButton(
                          onPressed: () => _downloadVideo(videoUrl),
                          icon: const Icon(Icons.download, size: 14),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Optimized parallel media fetching from all collections with caching
  Future<Map<String, List<String>>> _fetchTeacherMedia(String teacherId) async {
    // Check cache first
    final cacheTime = _mediaCacheTime[teacherId];
    if (cacheTime != null && 
        DateTime.now().difference(cacheTime) < _cacheExpiry &&
        _mediaCache.containsKey(teacherId)) {
      print('📦 Using cached media for teacher: $teacherId');
      return _mediaCache[teacherId]!;
    }

    final stopwatch = Stopwatch()..start();
    print('🔍 Fetching fresh media for teacher: $teacherId');

    String? getMediaUrl(dynamic mediaFile) {
      if (mediaFile == null) return null;
      if (mediaFile is String) return mediaFile;
      if (mediaFile is Map) {
        if (mediaFile['url'] != null) return mediaFile['url'].toString();
        if (mediaFile['link'] != null) return mediaFile['link'].toString();
        if (mediaFile['src'] != null) return mediaFile['src'].toString();
        return mediaFile.toString();
      }
      return mediaFile.toString();
    }

    try {
      // Parallel fetch from all collections with optimized queries
      final futures = await Future.wait([
        // Posts collection with limit and cache
        FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: teacherId)
            .limit(50) // Limit to recent posts for faster loading
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 5)),
        
        // Images collection with cache
        FirebaseFirestore.instance
            .collection('post_media_images')
            .where('userId', isEqualTo: teacherId)
            .limit(30) // Limit for faster loading
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 5)),
        
        // Videos collection with cache
        FirebaseFirestore.instance
            .collection('post_media_videos')
            .where('userId', isEqualTo: teacherId)
            .limit(20) // Limit for faster loading
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 5)),
      ]);

      final postsSnapshot = futures[0];
      final imagesSnapshot = futures[1];
      final videosSnapshot = futures[2];

      print('📝 Found ${postsSnapshot.docs.length} posts, ${imagesSnapshot.docs.length} images, ${videosSnapshot.docs.length} videos');

      // Process data in parallel
      final List<String> images = [];
      final List<String> videos = [];

      // Process posts
      for (var postDoc in postsSnapshot.docs) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final List<dynamic>? mediaFiles = postData['mediaFiles'];
        if (mediaFiles != null) {
          for (var mediaFile in mediaFiles) {
            final mediaUrl = getMediaUrl(mediaFile);
            if (mediaUrl != null && mediaUrl.isNotEmpty) {
              if (_isVideoUrl(mediaUrl)) {
                videos.add(mediaUrl);
              } else {
                images.add(mediaUrl);
              }
            }
          }
        }
      }

      // Process images collection
      for (var doc in imagesSnapshot.docs) {
        final data = doc.data();
        final url = data['url']?.toString();
        if (url != null && url.isNotEmpty) {
          images.add(url);
        }
      }

      // Process videos collection
      for (var doc in videosSnapshot.docs) {
        final data = doc.data();
        final url = data['url']?.toString();
        if (url != null && url.isNotEmpty) {
          videos.add(url);
        }
      }

      stopwatch.stop();
      print('⚡ Media fetch completed in ${stopwatch.elapsedMilliseconds}ms - Images: ${images.length}, Videos: ${videos.length}');
      
      final result = {
        'images': images,
        'videos': videos,
      };

      // Cache the result
      _mediaCache[teacherId] = result;
      _mediaCacheTime[teacherId] = DateTime.now();
      
      return result;
    } catch (e) {
      stopwatch.stop();
      print('❌ Error fetching teacher media in ${stopwatch.elapsedMilliseconds}ms: $e');
      return {
        'images': <String>[],
        'videos': <String>[],
      };
    }
  }

  // Build image card for gallery
  Widget _buildImageCard(String imageUrl, int index) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => _showFullScreenImage(context, imageUrl),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) {
                          print('🖼️ Gallery image error: $error');
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.image, color: Colors.grey, size: 50),
                            ),
                          );
                        },
                      ),
                    ),
                    // Image indicator
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'IMAGE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Image info and actions
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Image ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showFullScreenImage(context, imageUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff1B1212),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            minimumSize: const Size(0, 28),
                          ),
                          child: const Text('View', style: TextStyle(fontSize: 10)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 32,
                        height: 28,
                        child: IconButton(
                          onPressed: () => _downloadImage(imageUrl),
                          icon: const Icon(Icons.download, size: 14),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  // Download video method
  Future<void> _downloadVideo(String videoUrl) async {
    try {
      // Get file extension
      String extension = '.mp4';
      if (videoUrl.toLowerCase().contains('.mov')) {
        extension = '.mov';
      } else if (videoUrl.toLowerCase().contains('.mp4')) {
        extension = '.mp4';
      }
      
      String fileName = 'SpokenCafe_${DateTime.now().millisecondsSinceEpoch}$extension';

      // Try multiple download approaches - same as working Gallery logic
      bool success = false;
      String savedPath = '';

      // Approach 1: Try saving directly to gallery
      try {
        await _requestPermissions();
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/$fileName';

        // Download file to temp directory
        Dio dio = Dio();
        await dio.download(
          videoUrl,
          tempPath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
            }
          },
        );

        // Try to save to gallery
        // final result = await ImageGallerySaver.saveFile(tempPath);  // Temporarily disabled

        // if (result == true) {
        //   success = true;
        //   savedPath = 'Gallery';
        // }

        // Clean up temp file
        try {
          await File(tempPath).delete();
        } catch (e) {
          print('Error deleting temp file: $e');
        }
      } catch (e) {
        print('Gallery save failed: $e');
      }

      // Approach 2: If gallery save failed, save to Downloads folder
      if (!success) {
        try {
          Directory? downloadsDir;
          
          if (Platform.isAndroid) {
            downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              downloadsDir = await getApplicationDocumentsDirectory();
            }
          } else {
            downloadsDir = await getApplicationDocumentsDirectory();
          }

          if (downloadsDir != null) {
            final filePath = '${downloadsDir.path}/$fileName';
            
            Dio dio = Dio();
            await dio.download(
              videoUrl,
              filePath,
              onReceiveProgress: (received, total) {
                if (total != -1) {
                  print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
                }
              },
            );

            success = true;
            savedPath = Platform.isAndroid ? 'Downloads folder' : 'Documents folder';
          }
        } catch (e) {
          print('Downloads folder save failed: $e');
        }
      }

      // Approach 3: If all else fails, save to app directory
      if (!success) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final filePath = '${appDir.path}/$fileName';
          
          Dio dio = Dio();
          await dio.download(
            videoUrl,
            filePath,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
              }
            },
          );

          success = true;
          savedPath = 'App folder';
        } catch (e) {
          print('App folder save failed: $e');
        }
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video saved to $savedPath successfully! 🎬'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('All download methods failed');
      }

    } catch (e) {
      print('Download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString().split(':').last.trim()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// Compact video player widget for inline display
class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerWidget({required this.videoUrl});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeVideoWithCache();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initializeVideoWithCache() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      print('🎬 Starting cached video initialization for: ${widget.videoUrl}');
      
      // Create a custom cache manager for videos
      final customCacheManager = CacheManager(
        Config(
          'videoCache',
          stalePeriod: const Duration(days: 7), // Cache for 7 days
          maxNrOfCacheObjects: 50, // Keep up to 50 videos in cache
          repo: JsonCacheInfoRepository(databaseName: 'videoCache'),
          fileService: HttpFileService(),
        ),
      );

      // Get cached file or download it
      final fileInfo = await customCacheManager.getFileFromCache(widget.videoUrl);
      File? videoFile;

      if (fileInfo != null) {
        // Video is already cached
        videoFile = fileInfo.file;
        print('🎬 Video found in cache: ${fileInfo.file.path}');
      } else {
        // Download and cache the video
        print('🎬 Video not in cache, downloading...');
        videoFile = await customCacheManager.getSingleFile(widget.videoUrl);
        print('🎬 Video downloaded and cached: ${videoFile.path}');
      }

      // Initialize video player with cached file
      _controller = VideoPlayerController.file(videoFile);
      
      // Add error listener
      _controller!.addListener(() {
        if (_controller!.value.hasError) {
          print('🎬 Video player error: ${_controller!.value.errorDescription}');
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = _controller!.value.errorDescription;
            });
          }
        }
      });

      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
      
      print('🎬 Video initialized successfully');
    } catch (e) {
      print('🎬 Video initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _retryVideo() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
    _initializeVideoWithCache();
  }

  void _togglePlayPause() {
    if (_controller != null && _isInitialized) {
      setState(() {
        if (_isPlaying) {
          _controller!.pause();
          _isPlaying = false;
        } else {
          _controller!.play();
          _isPlaying = true;
        }
      });
    }
  }

  void _openFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: widget.videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Video content or loading/error states
            if (_hasError)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Video Error',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _errorMessage ?? 'Unknown error',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _retryVideo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isLoading)
              Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Loading video...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              Container(
                color: Colors.grey[800],
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),

            // Play/Pause overlay (only show when video is ready)
            if (_isInitialized && !_isLoading && !_hasError)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Fullscreen button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _openFullScreen,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // Video progress indicator
            if (_isInitialized && _controller != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.red,
                    bufferedColor: Colors.grey,
                    backgroundColor: Colors.black26,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideoWithCache();
  }

  Future<void> _initializeVideoWithCache() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      print('🎬 Starting full-screen cached video initialization for: ${widget.videoUrl}');
      
      // Create a custom cache manager for videos
      final customCacheManager = CacheManager(
        Config(
          'videoCache',
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 50,
          repo: JsonCacheInfoRepository(databaseName: 'videoCache'),
          fileService: HttpFileService(),
        ),
      );

      // Get cached file or download it
      final fileInfo = await customCacheManager.getFileFromCache(widget.videoUrl);
      File? videoFile;

      if (fileInfo != null) {
        // Video is already cached
        videoFile = fileInfo.file;
        print('🎬 Full-screen video found in cache: ${fileInfo.file.path}');
      } else {
        // Download and cache the video
        print('🎬 Full-screen video not in cache, downloading...');
        videoFile = await customCacheManager.getSingleFile(widget.videoUrl);
        print('🎬 Full-screen video downloaded and cached: ${videoFile.path}');
      }

      // Initialize video player with cached file
      _controller = VideoPlayerController.file(videoFile);
      
      // Add error listener
      _controller!.addListener(() {
        if (_controller!.value.hasError) {
          print('🎬 Full-screen video player error: ${_controller!.value.errorDescription}');
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = _controller!.value.errorDescription;
            });
          }
        }
      });

      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _initialized = true;
          _isLoading = false;
        });
        _controller!.play();
      }
      
      print('🎬 Full-screen video initialized successfully');
    } catch (e) {
      print('🎬 Full-screen video initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _retryVideo() {
    _controller?.dispose();
    _initializeVideoWithCache();
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _retryVideo,
          ),
        ],
      ),
      body: Center(
        child: _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Video Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage ?? 'Unknown error',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retryVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              )
            : _isLoading
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Loading video...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : _initialized && _controller != null
                    ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(_controller!),
                            VideoProgressIndicator(_controller!, allowScrubbing: true),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (_controller!.value.isPlaying) {
                                    _controller!.pause();
                                  } else {
                                    _controller!.play();
                                  }
                                });
                              },
                              child: Container(
                                color: Colors.transparent,
                                alignment: Alignment.center,
                                child: !_controller!.value.isPlaying
                                    ? const Icon(Icons.play_arrow, size: 80, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
