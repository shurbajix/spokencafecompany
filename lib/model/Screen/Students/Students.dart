

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Student {
  final String name;
  final String email;
  final String phoneNumber;
  final String docId;
  final String? profileImageUrl;
  final String? verificationVideo;
  final String? verificationDocument;
  final String? verificationDescription;
  final bool isVerified;

  Student({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.docId,
    this.profileImageUrl,
    this.verificationVideo,
    this.verificationDocument,
    this.verificationDescription,
    required this.isVerified,
  });

  factory Student.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Student(
      name: data['name']?.toString() ?? 'No name',
      email: data['email']?.toString() ?? 'No email',
      phoneNumber: data['phoneNumber']?.toString() ?? 'No phone number',
      docId: doc.id,
      profileImageUrl: data['profileImageUrl'] ?? '',
      verificationVideo: data['verificationVideo'] as String?,
      verificationDocument: data['verificationDocument'] as String?,
      verificationDescription: data['verificationDescription'] as String?,
      isVerified: data['isVerified'] == true,
    );
  }
}

class Students extends StatefulWidget {
  const Students({super.key});

  @override
  State<Students> createState() => _StudentsState();
}

class _StudentsState extends State<Students> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _showPostsPage = false;
  bool _showGalleryPage = false;
  List<Student> students = [];
  bool isLoading = true;
  String? errorMessage;
  late CollectionReference _usersCollection;
  bool _hasFetched = false;
  String? _selectedStudentDocId;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeFirebase() {
    _usersCollection = FirebaseFirestore.instance.collection('users');
    _fetchStudents();
  }

  // First Delete - Send Warning Message via Chat
  void _showWarningDialog(Student student) {
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Send Warning Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Send a warning message to ${student.name}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: 'Explain what the student did wrong...',
                  labelText: 'Warning Message',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (messageController.text.trim().isNotEmpty) {
                  await _sendWarningMessage(student, messageController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Send Warning', style: TextStyle(color: Colors.orange)),
            ),
          ],
        );
      },
    );
  }

  // Second Delete - Restrict User Abilities
  void _showRestrictDialog(Student student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Restrict User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Restrict ${student.name}\'s account?'),
              const SizedBox(height: 16),
              const Text('This will:'),
              const Text('• Disable posting (floating action button)'),
              const Text('• Disable commenting'),
              const Text('• Hide taken lessons (can\'t take new lessons)'),
              const SizedBox(height: 16),
              const Text('The user will still be able to log in but with limited functionality.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await _restrictUser(student);
                Navigator.pop(context);
              },
              child: const Text('Restrict User', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Third Delete - Delete Account Completely
  void _showDeleteAccountDialog(Student student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Permanently delete ${student.name}\'s account?'),
              const SizedBox(height: 16),
              const Text('⚠️ WARNING: This action cannot be undone!'),
              const SizedBox(height: 8),
              const Text('This will:'),
              const Text('• Delete the user account completely'),
              const Text('• Remove all user data'),
              const Text('• Remove all posts and comments'),
              const Text('• Cancel all taken lessons'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await _deleteUserAccount(student);
                Navigator.pop(context);
              },
              child: const Text('DELETE ACCOUNT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Implementation methods for the three delete actions
  Future<void> _sendWarningMessage(Student student, String message) async {
    try {
      // Create a chat message in the control app's chat system
      await FirebaseFirestore.instance.collection('control_messages').add({
        'recipientId': student.docId,
        'recipientName': student.name,
        'recipientEmail': student.email,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'warning',
        'isRead': false,
        'sentBy': 'Control App',
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning message sent to ${student.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending warning: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restrictUser(Student student) async {
    try {
      // Add user to restricted users collection
      await FirebaseFirestore.instance.collection('restricted_users').doc(student.docId).set({
        'userId': student.docId,
        'userName': student.name,
        'userEmail': student.email,
        'restrictedAt': FieldValue.serverTimestamp(),
        'restrictions': {
          'canPost': false,
          'canComment': false,
          'canTakeLessons': false,
        },
        'restrictedBy': 'Control App',
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name} has been restricted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restricting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUserAccount(Student student) async {
    try {
      // Delete user from users collection
      await FirebaseFirestore.instance.collection('users').doc(student.docId).delete();

      // Delete user posts
      final postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: student.docId)
          .get();
      
      for (var doc in postsQuery.docs) {
        await doc.reference.delete();
      }

      // Delete user comments
      final commentsQuery = await FirebaseFirestore.instance
          .collection('comments')
          .where('userId', isEqualTo: student.docId)
          .get();
      
      for (var doc in commentsQuery.docs) {
        await doc.reference.delete();
      }

      // Delete taken lessons
      final takenLessonsQuery = await FirebaseFirestore.instance
          .collection('takenLessons')
          .where('studentId', isEqualTo: student.docId)
          .get();
      
      for (var doc in takenLessonsQuery.docs) {
        await doc.reference.delete();
      }

      // Remove from local list
      setState(() {
        students.removeWhere((s) => s.docId == student.docId);
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name}\'s account has been deleted'),
            backgroundColor: Colors.black,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Accept student and enable delete functionality in main app
  Future<void> _acceptStudent(Student student) async {
    try {
      // Enable delete functionality by adding student to accepted collection
      await FirebaseFirestore.instance.collection('accepted_students').doc(student.docId).set({
        'studentId': student.docId,
        'studentName': student.name,
        'studentEmail': student.email,
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': 'Control App',
        'deleteButtonsEnabled': true,
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name} accepted - Delete buttons enabled in main app'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting student: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchStudents() async {
    if (_hasFetched) return;
    _hasFetched = true;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Authentication required. Please sign in.');
      await user.getIdToken();

      QuerySnapshot snapshot = await _usersCollection
          .where('role', isEqualTo: 'student')
          .get()
          .timeout(const Duration(seconds: 15));

      students = snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
      setState(() => isLoading = false);
    } on FirebaseException catch (e) {
      setState(() {
        errorMessage = _handleFirebaseError(e);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
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

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null) {
        PlatformFile file = result.files.first;
        print("File picked: ${file.name}");
      }
    } catch (e) {
      print("Error picking file: $e");
    }
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
        final result = await GallerySaver.saveImage(tempPath);

        if (result == true) {
          success = true;
          savedPath = 'Gallery';
        }

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

  List<Student> get _filteredStudents {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return students;
    return students.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.phoneNumber.toLowerCase().contains(q);
    }).toList();
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.wmv') ||
        lower.endsWith('.flv') ||
        lower.endsWith('.mkv');
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredStudents;

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
      body: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
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
          Container(
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
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    "Student List",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(errorMessage!),
                                  ElevatedButton(
                                    onPressed: () {
                                      _hasFetched = false;
                                      _fetchStudents();
                                    },
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : displayList.isEmpty
                              ? const Center(child: Text('No students found'))
                              : RefreshIndicator(
                                  onRefresh: () async {
                                    _hasFetched = false;
                                    await _fetchStudents();
                                  },
                                  child: Scrollbar(
                                    controller: _scrollController,
                                    thickness: 8,
                                    radius: const Radius.circular(10),
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      itemCount: displayList.length,
                                      itemBuilder: (context, index) {
                                        final s = displayList[index];
                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                          trailing: SizedBox(
                                            width: 400,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () => _acceptStudent(s),
                                                    child: const Text(
                                                      'Accept',
                                                      style: TextStyle(color: Colors.green, fontSize: 16),
                                                    ),
                                                  ),
                                                ),
                                                // First Delete - Warning Message
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () => _showWarningDialog(s),
                                                    child: const Text(
                                                      'Warning',
                                                      style: TextStyle(color: Colors.orange, fontSize: 16),
                                                    ),
                                                  ),
                                                ),
                                                // Second Delete - Restrict User
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () => _showRestrictDialog(s),
                                                    child: const Text(
                                                      'Restrict',
                                                      style: TextStyle(color: Colors.red, fontSize: 16),
                                                    ),
                                                  ),
                                                ),
                                                // Third Delete - Delete Account
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () => _showDeleteAccountDialog(s),
                                                    child: const Text(
                                                      'Delete',
                                                      style: TextStyle(color: Colors.black, fontSize: 16),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedStudentDocId = s.docId;
                                                        _showPostsPage = false;
                                                        _showGalleryPage = false;
                                                      });
                                                      Scaffold.of(context).openEndDrawer();
                                                    },
                                                    child: const Text('View', style: TextStyle(color: Colors.blue, fontSize: 16)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          title: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: Colors.amber,
                                                child: s.profileImageUrl != null && s.profileImageUrl!.isNotEmpty
                                                    ? ClipOval(
                                                        child: CachedNetworkImage(
                                                          imageUrl: s.profileImageUrl!,
                                                          width: 40,
                                                          height: 40,
                                                          fit: BoxFit.cover,
                                                          placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                                          errorWidget: (context, url, error) => const Icon(Icons.person, size: 20, color: Colors.white),
                                                        ),
                                                      )
                                                    : const Icon(Icons.person, size: 20, color: Colors.white),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Name: ${s.name}', overflow: TextOverflow.ellipsis),
                                                    Text('Email: ${s.email}', overflow: TextOverflow.ellipsis),
                                                    Text('Phone: ${s.phoneNumber}', overflow: TextOverflow.ellipsis),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalDrawerContent() {
    if (_selectedStudentDocId == null) {
      return const Center(child: Text('Please select a student to view their profile'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _usersCollection.doc(_selectedStudentDocId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading student data'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No student data found for this user'),
                ElevatedButton(
                  onPressed: () => setState(() => _selectedStudentDocId = null),
                  child: const Text('Back'),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

        if (data['role'] != 'student') {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Selected user is not a student or data is invalid'),
                ElevatedButton(
                  onPressed: () => setState(() => _selectedStudentDocId = null),
                  child: const Text('Back'),
                ),
              ],
            ),
          );
        }

        final student = Student.fromFirestore(snapshot.data!);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.blue),
                child: Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    child: student.profileImageUrl != null && student.profileImageUrl!.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: student.profileImageUrl!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const CircularProgressIndicator(),
                              errorWidget: (context, url, error) => const Icon(Icons.person, size: 50, color: Colors.white),
                            ),
                          )
                        : const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${student.name}', style: const TextStyle(fontSize: 20)),
                    Text('Email: ${student.email}', style: const TextStyle(fontSize: 20)),
                    Text('Phone: ${student.phoneNumber}', style: const TextStyle(fontSize: 20)),
                    const Divider(),
                  ],
                ),
              ),

              const Divider(),
              
              // Enhanced student details section
              _buildStudentDetailsSection(student, data),
              
              const Divider(),

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
    if (_selectedStudentDocId == null) {
      return const Center(child: Text('No student selected'));
    }

    return FutureBuilder<Map<String, List<String>>>(
      future: _fetchStudentMedia(_selectedStudentDocId!),
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

  // Optimized parallel media fetching from all collections with caching (same as Teachers)
  Future<Map<String, List<String>>> _fetchStudentMedia(String studentId) async {
    final stopwatch = Stopwatch()..start();
    print('🔍 Fetching fresh media for student: $studentId');

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
            .where('userId', isEqualTo: studentId)
            .limit(50) // Limit to recent posts for faster loading
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 5)),
        
        // Images collection with cache
        FirebaseFirestore.instance
            .collection('post_media_images')
            .where('userId', isEqualTo: studentId)
            .limit(30) // Limit for faster loading
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 5)),
        
        // Videos collection with cache
        FirebaseFirestore.instance
            .collection('post_media_videos')
            .where('userId', isEqualTo: studentId)
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
      
      return result;
    } catch (e) {
      stopwatch.stop();
      print('❌ Error fetching student media in ${stopwatch.elapsedMilliseconds}ms: $e');
      return {
        'images': <String>[],
        'videos': <String>[],
      };
    }
  }

  // Build image card for gallery (same as Teachers)
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

  // Build video card for gallery (same as Teachers)
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

  // Download video method (same as Teachers)
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

      // Show download started message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video download started...'),
          backgroundColor: Colors.blue,
        ),
      );

      // Use the same download logic as images
      _downloadImage(videoUrl);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPostsPage() {
    if (_selectedStudentDocId == null) {
      return const Center(child: Text('No student selected'));
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: _selectedStudentDocId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts found.'));
          }
          final posts = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: 0.7,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postDoc = posts[index];
              final postData = postDoc.data() as Map<String, dynamic>;
              return _buildPostGridItem(postDoc.id, postData);
            },
          );
        },
      ),
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
                    'collection': 'posts',
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
                child: Image.network(
                  firstMediaUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
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

  // Delete dialogs and functionality (same as Teachers.dart)
  void _showDeleteFromUserDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete from User Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will:'),
              const SizedBox(height: 8),
              const Text('• Permanently delete the post from user\'s account'),
              const Text('• Remove all related media files'),
              const Text('• Show chat offer dialog for user support'),
              const SizedBox(height: 12),
              Text('Post: ${post['text'] ?? 'No text'}'),
              Text('User: ${post['userName']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteFromUser(post);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Delete from User'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteFromControlDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete from Control Only'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will:'),
              const SizedBox(height: 8),
              const Text('• Hide post from control app only'),
              const Text('• Keep original post on user\'s profile'),
              const Text('• Post remains visible to other users'),
              const SizedBox(height: 12),
              Text('Post: ${post['text'] ?? 'No text'}'),
              Text('User: ${post['userName']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteFromControl(post);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hide from Control'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFromUser(Map<String, dynamic> post) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting post...'),
            ],
          ),
        ),
      );

      // Delete from posts collection
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(post['id'])
          .delete();

      // Delete related media files
      if (post['mediaFiles'] != null) {
        for (var mediaUrl in post['mediaFiles']) {
          // Delete from post_media_images and post_media_videos collections
          final imageQuery = await FirebaseFirestore.instance
              .collection('post_media_images')
              .where('url', isEqualTo: mediaUrl)
              .get();
          
          for (var doc in imageQuery.docs) {
            await doc.reference.delete();
          }

          final videoQuery = await FirebaseFirestore.instance
              .collection('post_media_videos')
              .where('url', isEqualTo: mediaUrl)
              .get();
          
          for (var doc in videoQuery.docs) {
            await doc.reference.delete();
          }
        }
      }

      Navigator.of(context).pop(); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted from user account successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Show chat offer dialog
      _showChatOfferDialog(post);

    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteFromControl(Map<String, dynamic> post) async {
    try {
      // Add to hidden posts collection
      await FirebaseFirestore.instance
          .collection('control_hidden_posts')
          .doc(post['id'])
          .set({
        'postId': post['id'],
        'hiddenAt': FieldValue.serverTimestamp(),
        'hiddenBy': 'control_app',
        'originalPost': post,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post hidden from control app'),
          backgroundColor: Colors.blue,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error hiding post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showChatOfferDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Offer Support'),
          content: Text(
            'Post deleted successfully. Would you like to chat with ${post['userName']} to offer support or explanation?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No Thanks'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to chat (you can implement this based on your chat navigation)
                // For now, just show a placeholder
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening chat with ${post['userName']}...'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text('Open Chat'),
            ),
          ],
        );
      },
    );
  }

  // Enhanced student details section with comprehensive information
  Widget _buildStudentDetailsSection(Student student, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Description
        _buildInfoCard(
          'Description',
          Icons.description,
          student.verificationDescription ?? 'No description provided',
        ),
        
        const SizedBox(height: 12),
        
        // Additional student information
        if (data['bio'] != null && data['bio'].toString().isNotEmpty)
          _buildInfoCard(
            'Biography',
            Icons.person_outline,
            data['bio'].toString(),
          ),
        
        if (data['interests'] != null && data['interests'].toString().isNotEmpty)
          _buildInfoCard(
            'Interests',
            Icons.favorite,
            data['interests'].toString(),
          ),
        
        if (data['location'] != null && data['location'].toString().isNotEmpty)
          _buildInfoCard(
            'Location',
            Icons.location_on,
            data['location'].toString(),
          ),
        
        if (data['dateOfBirth'] != null)
          _buildInfoCard(
            'Date of Birth',
            Icons.cake,
            data['dateOfBirth'].toString(),
          ),
        
        if (data['education'] != null && data['education'].toString().isNotEmpty)
          _buildInfoCard(
            'Education',
            Icons.school,
            data['education'].toString(),
          ),
        
        if (data['languagesSpoken'] != null)
          _buildInfoCard(
            'Languages',
            Icons.language,
            data['languagesSpoken'] is List 
                ? (data['languagesSpoken'] as List).join(', ')
                : data['languagesSpoken'].toString(),
          ),
        
        // Account status information
        _buildStatusCard(student, data),
        
        const SizedBox(height: 12),
        
        // Statistics section
        _buildStudentStatsSection(student.docId),
      ],
    );
  }

  Widget _buildInfoCard(String title, IconData icon, String content) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Student student, Map<String, dynamic> data) {
    final isVerified = student.isVerified;
    final joinDate = data['createdAt'];
    final lastSeen = data['lastSeen'];
    
    return Card(
      color: isVerified ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isVerified ? Icons.verified : Icons.pending,
                  color: isVerified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Account Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${isVerified ? "Verified" : "Pending Verification"}',
              style: const TextStyle(fontSize: 14),
            ),
            if (joinDate != null)
              Text(
                'Joined: ${_formatDate(joinDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (lastSeen != null)
              Text(
                'Last Seen: ${_formatDate(lastSeen)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentStatsSection(String studentId) {
    return FutureBuilder<Map<String, int>>(
      future: _getStudentStats(studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        final stats = snapshot.data ?? {'posts': 0, 'images': 0, 'videos': 0};
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.purple),
                    SizedBox(width: 8),
                    Text(
                      'Activity Statistics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Posts', stats['posts']!, Icons.post_add),
                    _buildStatItem('Images', stats['images']!, Icons.image),
                    _buildStatItem('Videos', stats['videos']!, Icons.video_library),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<Map<String, int>> _getStudentStats(String studentId) async {
    try {
      final postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: studentId)
          .get();
      
      final imagesQuery = await FirebaseFirestore.instance
          .collection('post_media_images')
          .where('userId', isEqualTo: studentId)
          .get();
      
      final videosQuery = await FirebaseFirestore.instance
          .collection('post_media_videos')
          .where('userId', isEqualTo: studentId)
          .get();
      
      return {
        'posts': postsQuery.docs.length,
        'images': imagesQuery.docs.length,
        'videos': videosQuery.docs.length,
      };
    } catch (e) {
      print('Error fetching student stats: $e');
      return {'posts': 0, 'images': 0, 'videos': 0};
    }
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return date.toDate().toString().split(' ')[0];
      } else if (date is String) {
        return DateTime.parse(date).toString().split(' ')[0];
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Player'),
      ),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: !_controller.value.isPlaying
                            ? const Icon(Icons.play_arrow, size: 80, color: Colors.white)
                            : null,
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}


