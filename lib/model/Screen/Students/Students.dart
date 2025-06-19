

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to download images.')),
        );
        return;
      }

      Directory directory;
      if (Platform.isAndroid) {
        directory = (await getExternalStorageDirectory())!;
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String fileName = imageUrl.split('/').last.split('?').first;
      String savePath = '${directory.path}/$fileName';

      Dio dio = Dio();
      await dio.download(imageUrl, savePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded to $savePath')),
      );
    } catch (e, stacktrace) {
      print('Download error: $e');
      print('Stack trace: $stacktrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading image: $e')),
      );
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
                                            width: 279,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () {
                                                      // Implement accept logic or disable if you want
                                                    },
                                                    child: const Text(
                                                      'Accept',
                                                      style: TextStyle(color: Colors.green, fontSize: 20),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) {
                                                          final ctrl = TextEditingController();
                                                          return AlertDialog(
                                                            backgroundColor: Colors.white,
                                                            title: const Text('Write the Reason for rejection'),
                                                            content: TextFormField(
                                                              controller: ctrl,
                                                              decoration: InputDecoration(
                                                                border: OutlineInputBorder(
                                                                  borderRadius: BorderRadius.circular(10),
                                                                ),
                                                                hintText: 'Enter reason',
                                                              ),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () => Navigator.pop(context),
                                                                child: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 20)),
                                                              ),
                                                              TextButton(
                                                                onPressed: () {
                                                                  // Implement rejection logic here with ctrl.text
                                                                  Navigator.pop(context);
                                                                },
                                                                child: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 20)),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                    },
                                                    child: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 20)),
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
                                                    child: const Text('View', style: TextStyle(color: Colors.black, fontSize: 20)),
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
                                                backgroundImage: s.profileImageUrl != null && s.profileImageUrl!.isNotEmpty
                                                    ? NetworkImage(s.profileImageUrl!)
                                                    : null,
                                                child: (s.profileImageUrl == null || s.profileImageUrl!.isEmpty)
                                                    ? const Icon(Icons.person, size: 20, color: Colors.white)
                                                    : null,
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
                    backgroundImage: student.profileImageUrl != null && student.profileImageUrl!.isNotEmpty
                        ? NetworkImage(student.profileImageUrl!)
                        : null,
                    child: (student.profileImageUrl == null || student.profileImageUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
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
              const Text('Description', style: TextStyle(fontSize: 18)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(student.verificationDescription ?? 'No description'),
              ),
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: _selectedStudentDocId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading gallery: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No posts found'));
        }

        final posts = snapshot.data!.docs;

        List<String> images = [];
        List<String> videos = [];

        for (var postDoc in posts) {
          final postData = postDoc.data() as Map<String, dynamic>;
          final List<dynamic>? mediaFiles = postData['mediaFiles'];
          if (mediaFiles != null) {
            for (var mediaUrl in mediaFiles) {
              if (mediaUrl is String && mediaUrl.isNotEmpty) {
                if (_isVideoUrl(mediaUrl)) {
                  videos.add(mediaUrl);
                } else {
                  images.add(mediaUrl);
                }
              }
            }
          }
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
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
              title: const Text('Gallery'),
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
                          ),
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            final imageUrl = images[index];
                            return GestureDetector(
                              onTap: () => _showFullScreenImage(context, imageUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                videos.isEmpty
                    ? const Center(child: Text('No videos found'))
                    : ListView.builder(
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          final videoUrl = videos[index];
                          return ListTile(
                            leading: const Icon(Icons.play_circle_fill,
                                size: 40, color: Colors.redAccent),
                            title: Text('Video ${index + 1}'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VideoPlayerScreen(videoUrl: videoUrl),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        );
      },
    );
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
          if (postData['text'] != null && postData['text'].isNotEmpty)
            Text(
              postData['text'],
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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
          if (postData['mediaFiles'] != null && postData['mediaFiles'].isNotEmpty)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  postData['mediaFiles'][0],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          IconButton(
            onPressed: () {
              final imageUrl = postData['mediaFiles'][0];
              if (imageUrl != null && imageUrl.isNotEmpty) {
                _downloadImage(imageUrl);
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
